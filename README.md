# Eveni ECE API

API REST para la gestión de expedientes clínicos electrónicos (ECE), diseñada y construida conforme a las normas oficiales mexicanas de salud:

- **NOM-004-SSA3-2012** — Expediente Clínico
- **NOM-024-SSA3-2012** — SIRES (Sistema de Información de Registro Electrónico en Salud)
- **LFPDPPP** — Ley Federal de Protección de Datos Personales en Posesión de los Particulares

## Stack tecnológico

| Capa | Tecnología |
|------|-----------|
| Lenguaje | Ruby 3.2.0 |
| Framework | Rails 8.1.2 (API mode) |
| Base de datos | PostgreSQL 16 |
| Autenticación | Devise + devise-jwt (JWT stateless) |
| Autorización | Pundit (RBAC) |
| Auditoría | Logidze (triggers PL/pgSQL) |
| Borrado lógico | Discard gem (Legal Hold) |
| Serialización | Blueprinter (JSON + HL7 FHIR R4) |
| CORS | rack-cors |
| Servidor | Puma + Thruster |
| Deploy | Kamal |

## Requisitos previos

- Ruby 3.2.0 (via rbenv o rvm)
- PostgreSQL 16
- Bundler 2.x

En macOS con Homebrew:

```bash
brew install postgresql@16 rbenv
rbenv install 3.2.0
rbenv global 3.2.0
```

Asegurarse de que PostgreSQL 16 esté en el PATH:

```bash
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"
```

## Instalación

```bash
git clone <repo-url> eveni_ece_api
cd eveni_ece_api
bundle install
```

## Configuración

### Variables de entorno

Crear un archivo `.env` en la raíz del proyecto (o configurar las variables en el entorno):

```bash
# Base de datos
DATABASE_URL=postgresql://localhost/eveni_ece_api_development

# Cifrado de datos sensibles (ActiveRecord::Encryption)
# Generar con: rails db:encryption:init
RAILS_MASTER_KEY=<valor del config/master.key>
```

### Credenciales cifradas

Configurar las claves de cifrado para ActiveRecord::Encryption:

```bash
rails credentials:edit
```

Agregar dentro del archivo:

```yaml
active_record_encryption:
  primary_key: <generado con rails db:encryption:init>
  deterministic_key: <generado con rails db:encryption:init>
  key_derivation_salt: <generado con rails db:encryption:init>
```

### Certificados SAT (e.firma / FIEL) — solo produccion

Colocar los certificados raíz del SAT en `config/certs/sat/`:

```
config/certs/sat/
  sat_root.pem       # Certificado raíz del SAT
  sat_inter.pem      # Certificado intermedio (si aplica)
```

## Base de datos

```bash
# Crear y migrar
rails db:create db:migrate

# Poblar catálogos (CIE-10, medicamentos, establecimientos CLUES)
# Requiere archivos CSV en tmp/catalogs/
rails catalogs:import_cie10    # Diagnósticos CIE-10
rails catalogs:import_meds     # Catálogo de medicamentos
rails catalogs:import_clues    # Establecimientos CLUES-SSA

# Datos de prueba (desarrollo)
rails db:seed
```

> **Importante:** El proyecto usa `db/structure.sql` (no `schema.rb`) para preservar los triggers PL/pgSQL y funciones de Logidze. No cambiar `config.active_record.schema_format`.

## Ejecucion del servidor

```bash
# Desarrollo
rails server

# Con recarga automática
bin/dev
```

La API queda disponible en `http://localhost:3000`.

## Suite de pruebas

```bash
# Preparar base de datos de pruebas
RAILS_ENV=test rails db:drop db:create db:schema:load

# Ejecutar todos los tests
bundle exec rspec

# Con formato detallado
bundle exec rspec --format documentation

# Por categoria
bundle exec rspec spec/models/
bundle exec rspec spec/requests/
bundle exec rspec spec/integration/
bundle exec rspec spec/services/
```

Estado actual: **52 tests, 0 fallos, 0 pendientes**.

### Cobertura de pruebas

| Categoria | Descripcion |
|-----------|-------------|
| `spec/models/` | Validaciones de modelos, CURP (algoritmo Módulo 10 RENAPO), cifrado |
| `spec/requests/` | Endpoints REST con autenticación JWT, RBAC Pundit |
| `spec/integration/` | Triggers NOM-024 (inmutabilidad), Logidze (versionado) |
| `spec/services/` | Verificación e.firma SAT (PKCS#7 con certificados reales) |

## Arquitectura

### Autenticacion (JWT Stateless)

```
POST /api/v1/users/sign_in  →  JWT en Authorization: Bearer <token>
DELETE /api/v1/users/sign_out  →  Revocación JTI en base de datos
```

El token JWT expira a las **8 horas**. La revocación usa la estrategia **JTIMatcher** (columna `jti` en la tabla `users`).

### Roles RBAC (NOM-024)

| Rol | Descripcion |
|-----|-------------|
| `admin` | Acceso total + gestión de usuarios |
| `doctor` | CRUD completo de expedientes propios |
| `nurse` | Lectura de expedientes + notas de evolución |
| `receptionist` | Gestión de pacientes únicamente |

### Endpoints principales

| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| POST | `/api/v1/users/sign_in` | Autenticación |
| DELETE | `/api/v1/users/sign_out` | Cierre de sesión |
| POST | `/api/v1/users` | Registro de usuario (admin) |
| GET/POST | `/api/v1/patients` | Pacientes |
| GET/POST | `/api/v1/patients/:id/clinical_histories` | Historias clínicas |
| GET/POST | `/api/v1/patients/:id/progress_notes` | Notas de evolución |
| POST | `/api/v1/digital_signatures` | Firma e.firma SAT |
| GET | `/api/fhir/Patient/:id` | FHIR R4 — Paciente |
| GET | `/api/fhir/Observation` | FHIR R4 — Signos vitales (LOINC) |
| GET | `/api/fhir/Condition` | FHIR R4 — Diagnósticos (ICD-10) |

Ver [`API_DOCUMENTATION.md`](API_DOCUMENTATION.md) para la documentación completa de todos los endpoints.

### Cumplimiento normativo

#### NOM-004-SSA3-2012 (Expediente Clínico)
- Retención mínima de 5 años: borrado lógico via `discard` gem (`discarded_at`)
- Legal Hold: pacientes con ARCO activo no pueden borrarse físicamente
- Campos de autoría obligatorios: `author_id` en todas las notas clínicas

#### NOM-024-SSA3-2012 (SIRES)
- Inmutabilidad: triggers PL/pgSQL bloquean `DELETE` físico en tablas clínicas
- Bitácora de cambios: Logidze registra cada versión en `log_data` JSONB
- RBAC: autorización a nivel de recurso con Pundit
- Interoperabilidad: endpoints HL7 FHIR R4 (`/api/fhir/`)
- e.firma SAT: verificación de firmas PKCS#7 Detached (`EfirmaVerifierService`)

#### LFPDPPP (Datos personales sensibles)
- Cifrado en reposo: `ActiveRecord::Encryption` en `first_name`, `last_name`, notas
- CURP: cifrado determinístico para permitir búsquedas sin exponer el dato
- Derechos ARCO: eliminación lógica + Legal Hold hasta cumplir retención NOM-004

### Validacion CURP

Doble validación per RENAPO oficial:

1. **Morfológica**: expresión regular que valida estructura, estado de nacimiento, consonantes
2. **Dígito verificador**: algoritmo Módulo 10 con mapeo Ñ-aware (`A=10..N=23`, `Ñ=24`, `O=25..Z=36`)

### Firma electronica (e.firma SAT / FIEL)

```ruby
EfirmaVerifierService.new(
  pkcs7_der: params[:signature],
  original_payload: document_content,
  public_cert: uploaded_cer_file
).call
```

Verifica firmas PKCS#7 Detached con los flags `DETACHED | BINARY | NOVERIFY` de OpenSSL. En producción agregar el certificado raíz SAT al `X509::Store` para verificación completa de cadena.

## Estructura del proyecto

```
app/
  controllers/api/
    v1/           # REST API endpoints
    fhir/         # HL7 FHIR R4 endpoints
  models/         # ActiveRecord (User, Patient, Doctor, ProgressNote, ...)
  policies/       # Pundit RBAC policies
  validators/     # CurpValidator (Módulo 10 RENAPO)
  services/
    efirma/       # EfirmaVerifierService (PKCS#7)
  blueprints/
    fhir/         # Blueprinter serializers FHIR R4
config/
  certs/sat/      # Certificados raíz SAT (producción)
  initializers/
    devise.rb     # JWT config
    cors.rb       # CORS headers
db/
  migrate/        # 19 migraciones
  structure.sql   # Schema con triggers PL/pgSQL (no schema.rb)
lib/
  tasks/
    import_catalogs.rake  # Importación CIE-10, medicamentos, CLUES
spec/
  factories/      # FactoryBot con CURPs válidas pre-calculadas
  support/
    jwt_helper.rb # Helper para tests autenticados
  models/
  requests/
  integration/    # Triggers NOM-024, Logidze versionado
  services/       # e.firma SAT
```

## Seguridad

- UUIDs como primary keys en todas las tablas (prevención de IDOR)
- JWT stateless con revocación por JTI
- Cifrado a nivel de campo (no solo en tránsito) para datos sensibles
- Triggers de base de datos como última línea de defensa para inmutabilidad (no bypasseable por la app)
- CORS configurado explícitamente por origen
- Brakeman para análisis estático de seguridad: `bundle exec brakeman`
- bundler-audit para vulnerabilidades en dependencias: `bundle exec bundle-audit check --update`

## Herramientas de calidad

```bash
# Analisis de seguridad estatica
bundle exec brakeman

# Vulnerabilidades en gemas
bundle exec bundle-audit check --update

# Linting
bundle exec rubocop
```

## Licencia

Privado — uso interno Eveni. Todos los derechos reservados.
