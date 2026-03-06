# Eveni ECE API — Documentación Técnica

**Versión:** 1.0.0
**Framework:** Ruby on Rails 8.1.2 (API mode)
**Base de datos:** PostgreSQL 16
**Cumplimiento normativo:** NOM-004-SSA3-2012, NOM-024-SSA3-2012, LFPDPPP

---

## Tabla de Contenidos

1. [Introducción](#1-introducción)
2. [Autenticación](#2-autenticación)
3. [Roles y Permisos (RBAC)](#3-roles-y-permisos-rbac)
4. [Convenciones Generales](#4-convenciones-generales)
5. [Endpoints — Autenticación](#5-endpoints--autenticación)
6. [Endpoints — Pacientes](#6-endpoints--pacientes)
7. [Endpoints — Historial Clínico](#7-endpoints--historial-clínico)
8. [Endpoints — Notas de Evolución](#8-endpoints--notas-de-evolución)
9. [Endpoints — Recetas](#9-endpoints--recetas)
10. [Endpoints — Consentimientos Informados](#10-endpoints--consentimientos-informados)
11. [Endpoints — Firmas Electrónicas](#11-endpoints--firmas-electrónicas)
12. [Endpoints — Doctores](#12-endpoints--doctores)
13. [Endpoints — Catálogos](#13-endpoints--catálogos)
14. [Endpoints — HL7 FHIR R4](#14-endpoints--hl7-fhir-r4)
15. [Validación CURP](#15-validación-curp)
16. [Firma Electrónica Avanzada (e.firma SAT)](#16-firma-electrónica-avanzada-efirma-sat)
17. [Errores y Códigos HTTP](#17-errores-y-códigos-http)
18. [Seguridad y Cumplimiento Normativo](#18-seguridad-y-cumplimiento-normativo)
19. [Importación de Catálogos Oficiales](#19-importación-de-catálogos-oficiales)

---

## 1. Introducción

La API de Eveni provee acceso al **Expediente Clínico Electrónico (ECE)** de la plataforma médica Eveni. Está diseñada para cumplir con la normativa mexicana de salud digital:

| Norma | Descripción |
|-------|-------------|
| **NOM-004-SSA3-2012** | Del Expediente Clínico — define estructura documental, retención (5 años) y autoría obligatoria |
| **NOM-024-SSA3-2012** | SIRES — inalterabilidad de registros, RBAC, firma electrónica, interoperabilidad |
| **LFPDPPP** | Protección de datos personales sensibles — cifrado, derechos ARCO, Legal Hold |

### URL Base

```
https://{host}/api/v1/
```

Para endpoints de interoperabilidad FHIR:

```
https://{host}/api/fhir/
```

### Formato de respuesta

Todas las respuestas son `application/json`.

---

## 2. Autenticación

La API utiliza **JSON Web Tokens (JWT)** sin estado mediante `devise-jwt` con estrategia de revocación **JTIMatcher**.

### Flujo de autenticación

```
1. POST /api/v1/users/sign_in  →  Recibe JWT en el header Authorization
2. Incluir header en todas las peticiones protegidas:
   Authorization: Bearer <token>
3. DELETE /api/v1/users/sign_out  →  Revoca el token (invalida el JTI)
```

### Características del token

| Parámetro | Valor |
|-----------|-------|
| Algoritmo | HS256 |
| Expiración | 8 horas |
| Revocación | Via columna `jti` en la base de datos |

> **Nota de seguridad:** Si el token es comprometido, se puede revocar individualmente (logout) sin afectar otras sesiones activas.

---

## 3. Roles y Permisos (RBAC)

Implementado con **Pundit** conforme a NOM-024-SSA3-2012 § Control de Acceso.

| Rol | Código | Descripción |
|-----|--------|-------------|
| `admin` | 0 | Acceso total al sistema |
| `doctor` | 1 | Lectura/escritura de expedientes y notas médicas |
| `nurse` | 2 | Lectura de expedientes y notas (sin escritura de diagnósticos) |
| `receptionist` | 3 | Solo datos demográficos de pacientes — **sin acceso a notas clínicas** |

### Matriz de permisos por endpoint

| Recurso | admin | doctor | nurse | receptionist |
|---------|-------|--------|-------|--------------|
| Pacientes (CRUD) | ✅ | ✅ | ✅ (lectura) | ✅ (crear/leer) |
| Notas de evolución | ✅ | ✅ | ✅ (lectura) | ❌ |
| Historial clínico | ✅ | ✅ | ✅ (lectura) | ❌ |
| Recetas | ✅ | ✅ | ✅ (lectura) | ❌ |
| Consentimientos | ✅ | ✅ | ✅ (lectura) | ❌ |
| Firmas electrónicas | ✅ | ✅ | ❌ | ❌ |
| Catálogos | ✅ | ✅ | ✅ | ✅ |

---

## 4. Convenciones Generales

### Identificadores

Todos los IDs son **UUID v4** (generados con `gen_random_uuid()` de PostgreSQL). Esto previene ataques de enumeración (IDOR).

```json
{ "id": "550e8400-e29b-41d4-a716-446655440000" }
```

### Paginación

Los endpoints de listado aceptan parámetros opcionales:
- `?page=1` — número de página (default: 1)
- `?per_page=25` — registros por página (default: 25)

### Filtrado

Los catálogos aceptan búsqueda por texto libre:
- `?q=texto` — búsqueda por nombre o código

### Borrado lógico (Legal Hold)

Ningún registro clínico es eliminado físicamente. Los registros "eliminados" tienen `discarded_at` con fecha. Los endpoints solo retornan registros activos (`discarded_at: null`) por defecto.

### Formato de fechas

ISO 8601: `YYYY-MM-DD` para fechas, `YYYY-MM-DDTHH:MM:SS.sssZ` para timestamps.

---

## 5. Endpoints — Autenticación

### POST /api/v1/users/sign_in

Inicia sesión y obtiene el JWT.

**Autenticación requerida:** No

**Body:**
```json
{
  "user": {
    "email": "doctor@eveni.mx",
    "password": "contraseña"
  }
}
```

**Respuesta exitosa `200 OK`:**
```json
{
  "message": "Sesión iniciada correctamente.",
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "doctor@eveni.mx",
    "role": "doctor"
  }
}
```

> El JWT se devuelve en el **header de respuesta** `Authorization: Bearer <token>`. El cliente debe almacenarlo y enviarlo en peticiones subsecuentes.

**Respuesta de error `401 Unauthorized`:**
```json
{ "error": "Email o contraseña incorrectos." }
```

---

### DELETE /api/v1/users/sign_out

Cierra sesión e invalida el token actual.

**Autenticación requerida:** Sí

**Header requerido:**
```
Authorization: Bearer <token>
```

**Respuesta exitosa `200 OK`:**
```json
{ "message": "Sesión cerrada correctamente." }
```

---

### POST /api/v1/users

Registra un nuevo usuario en el sistema.

**Autenticación requerida:** No (o solo admin en producción)

**Body:**
```json
{
  "user": {
    "email": "enfermera@eveni.mx",
    "password": "contraseña",
    "password_confirmation": "contraseña",
    "role": "nurse"
  }
}
```

**Valores válidos para `role`:** `admin`, `doctor`, `nurse`, `receptionist`

**Respuesta exitosa `201 Created`:**
```json
{
  "message": "Usuario registrado correctamente.",
  "user": {
    "id": "550e8400-...",
    "email": "enfermera@eveni.mx",
    "role": "nurse"
  }
}
```

---

## 6. Endpoints — Pacientes

### GET /api/v1/patients

Lista todos los pacientes activos.

**Autenticación requerida:** Sí
**Roles permitidos:** admin, doctor, nurse, receptionist

**Respuesta `200 OK`:**
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "curp": "HEGG560427MVZRRL04",
    "first_name": "Juan",
    "last_name": "García López",
    "dob": "1956-04-27",
    "sex": "male",
    "email": "paciente@email.com",
    "phone": "+52 55 1234 5678",
    "discarded_at": null,
    "created_at": "2024-01-15T10:30:00.000Z",
    "updated_at": "2024-01-15T10:30:00.000Z"
  }
]
```

---

### POST /api/v1/patients

Registra un nuevo paciente. **La CURP es validada con el algoritmo Módulo 10 de RENAPO.**

**Autenticación requerida:** Sí
**Roles permitidos:** admin, doctor, receptionist

**Body:**
```json
{
  "patient": {
    "curp": "HEGG560427MVZRRL04",
    "first_name": "Juan",
    "last_name": "García López",
    "dob": "1956-04-27",
    "sex": "male",
    "email": "paciente@email.com",
    "phone": "+52 55 1234 5678"
  }
}
```

**Valores válidos para `sex`:** `male`, `female`, `non_binary`

**Respuesta exitosa `201 Created`:**
```json
{
  "id": "550e8400-...",
  "curp": "HEGG560427MVZRRL04",
  "first_name": "Juan",
  ...
}
```

**Errores de validación `422 Unprocessable Entity`:**
```json
{
  "errors": [
    "Curp tiene un dígito verificador inválido (falla el algoritmo Módulo 10 de RENAPO)",
    "Curp no tiene el formato válido de CURP (18 caracteres según RENAPO)"
  ]
}
```

---

### GET /api/v1/patients/:id

Obtiene el detalle de un paciente.

**Autenticación requerida:** Sí
**Roles permitidos:** admin, doctor, nurse, receptionist

**Respuesta `200 OK`:** Igual al objeto del listado.

---

### PATCH /api/v1/patients/:id

Actualiza datos demográficos de un paciente. La CURP no puede modificarse una vez registrada (integridad del ECE).

**Autenticación requerida:** Sí
**Roles permitidos:** admin, doctor

**Body:** Igual que el de creación (todos los campos son opcionales).

---

## 7. Endpoints — Historial Clínico

El historial clínico es un documento único por paciente que contiene antecedentes a largo plazo (NOM-004 § Historia Clínica).

### GET /api/v1/patients/:patient_id/clinical_history

**Autenticación requerida:** Sí
**Roles permitidos:** admin, doctor, nurse

**Respuesta `200 OK`:**
```json
{
  "id": "...",
  "patient_id": "...",
  "hereditary_history": {
    "diabetes": true,
    "hypertension": false,
    "cancer": false,
    "notes": "Abuela materna con diabetes tipo 2"
  },
  "pathological_history": {
    "surgeries": ["apendicectomía 2010"],
    "allergies": ["penicilina", "ibuprofeno"],
    "chronic_diseases": ["hipertensión arterial"],
    "hospitalizations": []
  },
  "non_pathological_history": {
    "smoking": false,
    "alcohol": "ocasional",
    "physical_activity": "3 veces por semana",
    "diet": "regular"
  },
  "gynecological_history": {
    "menarche_age": 13,
    "last_menstrual_period": "2024-01-01",
    "pregnancies": 2,
    "deliveries": 2,
    "abortions": 0,
    "contraception": "ninguno"
  },
  "log_data": { ... },
  "discarded_at": null,
  "created_at": "...",
  "updated_at": "..."
}
```

> **NOM-024:** La columna `log_data` contiene la bitácora completa de cambios gestionada por triggers PostgreSQL (Logidze). Cada versión del documento queda registrada de forma inalterable.

---

### POST /api/v1/patients/:patient_id/clinical_history

Crea el historial clínico inicial del paciente.

**Autenticación requerida:** Sí
**Roles permitidos:** admin, doctor

**Body:**
```json
{
  "clinical_history": {
    "hereditary_history": {
      "diabetes": true,
      "hypertension": false
    },
    "pathological_history": {
      "allergies": ["penicilina"],
      "surgeries": []
    },
    "non_pathological_history": {
      "smoking": false,
      "alcohol": false
    },
    "gynecological_history": {}
  }
}
```

**Respuesta `201 Created`:** Objeto completo del historial.

---

### PATCH /api/v1/patients/:patient_id/clinical_history

Actualiza el historial clínico. El registro original queda preservado en `log_data`.

**Autenticación requerida:** Sí
**Roles permitidos:** admin, doctor

---

## 8. Endpoints — Notas de Evolución

Las notas de evolución son el núcleo del ECE. Están protegidas contra borrado físico por triggers PL/pgSQL (NOM-024). La columna `evolution` está cifrada en reposo.

### Tipos de nota (`note_type`)

| Valor | Descripción |
|-------|-------------|
| `evolution` | Nota de evolución en consulta (default) |
| `urgency` | Nota de urgencias |
| `interconsultation` | Nota de interconsulta |
| `admission` | Nota de ingreso hospitalario |
| `discharge` | Nota de egreso hospitalario |

### GET /api/v1/patients/:patient_id/progress_notes

**Autenticación requerida:** Sí
**Roles permitidos:** admin, doctor, nurse

**Respuesta `200 OK`:**
```json
[
  {
    "id": "...",
    "patient_id": "...",
    "doctor_id": "...",
    "note_type": "evolution",
    "vital_signs": {
      "heart_rate": 72,
      "blood_pressure_systolic": 120,
      "blood_pressure_diastolic": 80,
      "temperature": 36.5,
      "oxygen_saturation": 98,
      "weight": 70.5,
      "height": 170
    },
    "evolution": "Paciente refiere mejoría significativa. Persiste tos leve.",
    "diagnoses": [
      {
        "code": "J06.9",
        "description": "Infección aguda de las vías respiratorias superiores, no especificada"
      }
    ],
    "prognosis": "Favorable",
    "treatment_plan": "Continuar tratamiento por 5 días más.",
    "log_data": { ... },
    "discarded_at": null,
    "created_at": "...",
    "updated_at": "..."
  }
]
```

---

### POST /api/v1/patients/:patient_id/progress_notes

Crea una nueva nota de evolución. El doctor se asigna automáticamente desde el JWT.

**Autenticación requerida:** Sí
**Roles permitidos:** admin, doctor

**Body:**
```json
{
  "progress_note": {
    "note_type": "evolution",
    "vital_signs": {
      "heart_rate": 72,
      "blood_pressure_systolic": 120,
      "blood_pressure_diastolic": 80,
      "temperature": 36.5,
      "oxygen_saturation": 98
    },
    "evolution": "Descripción detallada de la evolución del paciente...",
    "diagnoses": [
      { "code": "J06.9", "description": "Infección aguda de vías respiratorias superiores" }
    ],
    "prognosis": "Favorable",
    "treatment_plan": "Reposo y antibiótico por 7 días."
  }
}
```

> **NOM-004:** El campo `diagnoses` debe referenciar códigos del catálogo CIE-10 oficial (ver sección de catálogos). El campo `evolution` se cifra automáticamente antes de persistir.

**Respuesta `201 Created`:** Objeto completo de la nota.

---

### PATCH /api/v1/patients/:patient_id/progress_notes/:id

Actualiza una nota existente (genera adenda — el original queda en `log_data`).

**Autenticación requerida:** Sí
**Roles permitidos:** admin, doctor

> **NOM-024:** No existe endpoint `DELETE`. Intentar eliminar físicamente una nota activa el trigger `prevent_hard_deletes` de PostgreSQL y retorna error.

---

## 9. Endpoints — Recetas

### GET /api/v1/patients/:patient_id/progress_notes/:progress_note_id/prescription

Obtiene la receta asociada a una nota de evolución.

**Autenticación requerida:** Sí
**Roles permitidos:** admin, doctor, nurse

**Respuesta `200 OK`:**
```json
{
  "id": "...",
  "progress_note_id": "...",
  "medications": [
    {
      "cve_code": "010.000.1430.00",
      "name": "Amoxicilina",
      "presentation": "Cápsulas 500 mg",
      "dose": "500 mg",
      "frequency": "cada 8 horas",
      "duration": "7 días",
      "route": "oral"
    }
  ],
  "instructions": "Tomar con alimentos. Completar el tratamiento aunque mejoren los síntomas.",
  "log_data": { ... },
  "created_at": "...",
  "updated_at": "..."
}
```

---

### POST /api/v1/patients/:patient_id/progress_notes/:progress_note_id/prescription

**Autenticación requerida:** Sí
**Roles permitidos:** admin, doctor

**Body:**
```json
{
  "prescription": {
    "medications": [
      {
        "cve_code": "010.000.1430.00",
        "name": "Amoxicilina",
        "presentation": "Cápsulas 500 mg",
        "dose": "500 mg",
        "frequency": "cada 8 horas",
        "duration": "7 días",
        "route": "oral"
      }
    ],
    "instructions": "Tomar con alimentos."
  }
}
```

> **NOM-024:** Se recomienda incluir `cve_code` del Cuadro Básico de Medicamentos del CSG para interoperabilidad. Consultar el endpoint `/api/v1/medications_catalogs`.

---

## 10. Endpoints — Consentimientos Informados

### GET /api/v1/patients/:patient_id/informed_consents

**Autenticación requerida:** Sí
**Roles permitidos:** admin, doctor, nurse

**Respuesta `200 OK`:**
```json
[
  {
    "id": "...",
    "patient_id": "...",
    "doctor_id": "...",
    "procedure_name": "Colonoscopía",
    "risks": "Perforación intestinal (< 0.1%), sangrado, reacción anestésica.",
    "benefits": "Diagnóstico y tratamiento de lesiones colorrectales.",
    "patient_accepted": true,
    "accepted_at": "2024-01-15T11:00:00.000Z",
    "log_data": { ... },
    "created_at": "...",
    "updated_at": "..."
  }
]
```

---

### POST /api/v1/patients/:patient_id/informed_consents

**Autenticación requerida:** Sí
**Roles permitidos:** admin, doctor

**Body:**
```json
{
  "informed_consent": {
    "procedure_name": "Colonoscopía",
    "risks": "Perforación intestinal (< 0.1%), sangrado, reacción anestésica.",
    "benefits": "Diagnóstico y tratamiento de lesiones colorrectales.",
    "patient_accepted": true,
    "accepted_at": "2024-01-15T11:00:00.000Z"
  }
}
```

---

## 11. Endpoints — Firmas Electrónicas

Implementa el flujo de **e.firma SAT (FIEL)** sin custodia de clave privada. La firma se genera en el cliente y el backend solo verifica.

### Flujo completo

```
Cliente (dispositivo del médico)
  1. Construye JSON determinista de la nota médica
  2. Firma con su clave privada (.key) + contraseña LOCAL
  3. Genera firma PKCS#7 Detached en Base64
  4. Envía: { payload, firma_b64, certificado_publico } → Backend

Backend (Eveni API)
  5. Carga certificados raíz del SAT (config/certs/sat/)
  6. Verifica la firma PKCS#7 con OpenSSL (flags DETACHED | BINARY)
  7. Si válida: persiste DigitalSignature con sello de tiempo
  8. Retorna: sello de tiempo del servidor
```

> **Seguridad:** El backend NUNCA recibe ni almacena la clave privada del médico.

### GET /api/v1/patients/:patient_id/progress_notes/:progress_note_id/digital_signatures

Lista las firmas de una nota.

**Autenticación requerida:** Sí
**Roles permitidos:** admin, doctor

**Respuesta `200 OK`:**
```json
[
  {
    "id": "...",
    "doctor_id": "...",
    "signable_type": "ProgressNote",
    "signable_id": "...",
    "signature_payload": "MIIFbQYJKoZIhvcNAQcDoIIFXjCC...",
    "certificate_serial": "20001000000300022762",
    "signed_at": "2024-01-15T12:00:00.000Z",
    "created_at": "..."
  }
]
```

---

### POST /api/v1/patients/:patient_id/progress_notes/:progress_note_id/digital_signatures

Verifica y registra una firma electrónica avanzada (e.firma SAT).

**Autenticación requerida:** Sí
**Roles permitidos:** doctor (únicamente el médico puede firmar)

**Body:**
```json
{
  "digital_signature": {
    "signature_payload": "MIIFbQYJKoZIhvcNAQcDoIIFXjCC...",
    "certificate_pem": "-----BEGIN CERTIFICATE-----\nMIIE...\n-----END CERTIFICATE-----",
    "original_payload": "{\"evolution\":\"Paciente en mejora...\",\"diagnoses\":[...]}",
    "certificate_serial": "20001000000300022762"
  }
}
```

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `signature_payload` | String (Base64) | Firma PKCS#7 Detached generada por la e.firma SAT |
| `certificate_pem` | String (PEM) | Certificado público del médico (.cer en formato PEM o Base64 DER) |
| `original_payload` | String | Texto plano original que fue firmado (JSON determinista) |
| `certificate_serial` | String | Número de serie del certificado SAT |

**Respuesta exitosa `201 Created`:**
```json
{
  "id": "...",
  "signed_at": "2024-01-15T12:00:00.000Z",
  "certificate_serial": "20001000000300022762",
  "message": "Firma electrónica verificada y registrada correctamente."
}
```

**Error de verificación `422 Unprocessable Entity`:**
```json
{
  "error": "Firma electrónica inválida: La firma PKCS#7 no pudo verificarse contra el certificado proporcionado."
}
```

---

## 12. Endpoints — Doctores

### GET /api/v1/doctors

**Autenticación requerida:** Sí

**Respuesta `200 OK`:**
```json
[
  {
    "id": "...",
    "user_id": "...",
    "professional_license": "12345678",
    "specialty": "Medicina General",
    "public_certificate": null,
    "discarded_at": null,
    "created_at": "...",
    "updated_at": "..."
  }
]
```

---

### POST /api/v1/doctors

Registra el perfil médico de un usuario con rol `doctor`.

**Body:**
```json
{
  "doctor": {
    "professional_license": "12345678",
    "specialty": "Cardiología",
    "public_certificate": "-----BEGIN CERTIFICATE-----\n..."
  }
}
```

> **NOM-004:** La `professional_license` (cédula profesional) es obligatoria y debe ser única. Almacenar el `public_certificate` (X.509 en PEM) habilita la verificación de firmas electrónicas.

---

## 13. Endpoints — Catálogos

Catálogos de solo lectura, alineados con los estándares de la DGIS y el CSG (NOM-024 § Interoperabilidad).

### GET /api/v1/cie10_diagnoses

Busca diagnósticos CIE-10.

**Autenticación:** No requerida

**Query params:**
- `?q=diabetes` — filtra por código o descripción

**Respuesta `200 OK`:**
```json
[
  {
    "id": "...",
    "code": "E11.9",
    "description": "Diabetes mellitus tipo 2 sin complicaciones",
    "category": "E11",
    "chapter": "IV"
  }
]
```

---

### GET /api/v1/medications_catalogs

Busca medicamentos del Cuadro Básico CSG.

**Autenticación:** No requerida

**Respuesta `200 OK`:**
```json
[
  {
    "id": "...",
    "cve_code": "010.000.1430.00",
    "name": "Amoxicilina",
    "active_ingredient": "Amoxicilina trihidrato",
    "route_of_administration": "Oral",
    "presentation": "Cápsulas 500 mg"
  }
]
```

---

### GET /api/v1/clues_establishments

Busca establecimientos de salud por CLUES.

**Autenticación:** No requerida

**Respuesta `200 OK`:**
```json
[
  {
    "id": "...",
    "clues_code": "DFSSA000000",
    "name": "Hospital General de México",
    "state_code": "DF",
    "municipality": "Cuauhtémoc",
    "institution_type": "SSA",
    "status": "active"
  }
]
```

---

## 14. Endpoints — HL7 FHIR R4

Namespace de interoperabilidad que expone los datos en formato estándar HL7 FHIR R4, conforme al espíritu del intercambio de información de la NOM-024.

**Content-Type de respuesta:** `application/fhir+json; fhirVersion=4.0`

### GET /api/fhir/patients/:fhir_id

Recurso `Patient` FHIR con CURP en el bloque `identifier`.

**Respuesta `200 OK`:**
```json
{
  "resourceType": "Patient",
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "meta": {
    "profile": ["http://hl7.org/fhir/StructureDefinition/Patient"],
    "lastUpdated": "2024-01-15T10:30:00Z"
  },
  "identifier": [
    {
      "use": "official",
      "system": "https://www.gob.mx/renapo",
      "type": {
        "coding": [
          {
            "system": "http://terminology.hl7.org/CodeSystem/v2-0203",
            "code": "NI",
            "display": "National unique individual identifier"
          }
        ],
        "text": "CURP"
      },
      "value": "HEGG560427MVZRRL04"
    }
  ],
  "name": [
    {
      "use": "official",
      "family": "García López",
      "given": ["Juan"]
    }
  ],
  "birthDate": "1956-04-27",
  "gender": "male"
}
```

---

### GET /api/fhir/observations/:id

Signos vitales de una nota de evolución como recursos FHIR `Observation` con códigos LOINC.

**Respuesta `200 OK`:**
```json
{
  "resourceType": "Bundle",
  "type": "searchset",
  "entry": [
    {
      "resourceType": "Observation",
      "id": "nota-id-heart_rate",
      "status": "final",
      "category": [
        {
          "coding": [
            {
              "system": "http://terminology.hl7.org/CodeSystem/observation-category",
              "code": "vital-signs",
              "display": "Vital Signs"
            }
          ]
        }
      ],
      "code": {
        "coding": [
          { "system": "http://loinc.org", "code": "8867-4", "display": "Heart rate" }
        ],
        "text": "Heart rate"
      },
      "subject": { "reference": "Patient/550e8400-..." },
      "effectiveDateTime": "2024-01-15T10:30:00Z",
      "valueQuantity": {
        "value": 72.0,
        "unit": "/min",
        "system": "http://unitsofmeasure.org",
        "code": "/min"
      }
    }
  ]
}
```

**Códigos LOINC soportados:**

| Campo `vital_signs` | Código LOINC | Descripción |
|---------------------|--------------|-------------|
| `blood_pressure_systolic` | 8480-6 | Systolic blood pressure |
| `blood_pressure_diastolic` | 8462-4 | Diastolic blood pressure |
| `heart_rate` | 8867-4 | Heart rate |
| `respiratory_rate` | 9279-1 | Respiratory rate |
| `temperature` | 8310-5 | Body temperature |
| `oxygen_saturation` | 2708-6 | Oxygen saturation |
| `weight` | 29463-7 | Body weight |
| `height` | 8302-2 | Body height |

---

### GET /api/fhir/conditions/:id

Diagnósticos de una nota como recursos FHIR `Condition` con sistema ICD-10.

**Respuesta `200 OK`:**
```json
{
  "resourceType": "Bundle",
  "type": "searchset",
  "entry": [
    {
      "resourceType": "Condition",
      "id": "nota-id-condition-0",
      "clinicalStatus": {
        "coding": [
          { "system": "http://terminology.hl7.org/CodeSystem/condition-clinical", "code": "active" }
        ]
      },
      "code": {
        "coding": [
          {
            "system": "http://hl7.org/fhir/sid/icd-10",
            "code": "J06.9",
            "display": "Infección aguda de las vías respiratorias superiores"
          }
        ]
      },
      "subject": { "reference": "Patient/550e8400-..." },
      "encounter": { "reference": "Encounter/nota-id" },
      "recordedDate": "2024-01-15T10:30:00Z",
      "recorder": { "reference": "Practitioner/doctor-id" }
    }
  ]
}
```

---

## 15. Validación CURP

La API valida la CURP en dos niveles:

### Nivel 1: Formato morfológico (Regex RENAPO)

| Posición | Contenido | Ejemplo |
|----------|-----------|---------|
| 1-4 | Iniciales apellidos + nombre | `HEGG` |
| 5-10 | Fecha nacimiento AAMMDD | `560427` |
| 11 | Sexo: `H`(ombre), `M`(ujer), `X`(no binario) | `M` |
| 12-13 | Clave INEGI del estado | `VZ` (Veracruz) |
| 14-16 | Consonantes internas | `RRL` |
| 17 | Siglo/Homonimia: 0-9 (≤1999), A-Z (≥2000) | `0` |
| 18 | Dígito verificador | `4` |

### Nivel 2: Dígito verificador (Algoritmo Módulo 10 RENAPO)

Implementación del algoritmo oficial con mapeo Ñ-aware:
- `0-9` → valores `0-9`
- `A-N` → valores `10-23`
- `Ñ` → valor `24`
- `O-Z` → valores `25-36`

El peso posicional se calcula como `(19 - posición)`, de izquierda a derecha.

**Claves de estado INEGI soportadas:**
`AS, BC, BS, CC, CL, CM, CS, CH, DF, DG, GT, GR, HG, JC, MC, MN, MS, NT, NL, OC, PL, QT, QR, SP, SL, SR, TC, TS, TL, VZ, YN, ZS, NE`

---

## 16. Firma Electrónica Avanzada (e.firma SAT)

### Generación de la firma (cliente)

```javascript
// Ejemplo conceptual en JavaScript (frontend/app móvil)
const payload = JSON.stringify({
  evolution: nota.evolution,
  diagnoses: nota.diagnoses,
  doctor_license: "12345678",
  timestamp: new Date().toISOString()
}, null, 0);  // JSON compacto y determinista

// Firmar con la clave privada del médico (solo en dispositivo local)
const signature = signPKCS7Detached(payload, privateKey, certificate);
const signatureB64 = btoa(signature);

// Enviar al backend
await api.post('/api/v1/patients/:id/progress_notes/:id/digital_signatures', {
  digital_signature: {
    signature_payload: signatureB64,
    certificate_pem: certificate.toPEM(),
    original_payload: payload,
    certificate_serial: certificate.serial
  }
});
```

### Validez jurídica

Para que el expediente tenga validez jurídica plena sin impresión en papel (NOM-024 § Firma Electrónica), el flujo debe:
1. Usar certificados X.509 vigentes emitidos por el SAT
2. Incluir el sello de tiempo del servidor como `signed_at`
3. Mantener los certificados raíz del SAT en `config/certs/sat/` actualizados

---

## 17. Errores y Códigos HTTP

| Código | Significado | Causa común |
|--------|-------------|-------------|
| `200 OK` | Éxito | Lectura/actualización exitosa |
| `201 Created` | Creado | Recurso creado correctamente |
| `401 Unauthorized` | No autenticado | Token JWT ausente, expirado o revocado |
| `403 Forbidden` | No autorizado | Rol sin permisos (Pundit) |
| `404 Not Found` | No encontrado | Recurso no existe o fue descartado |
| `422 Unprocessable Entity` | Error de validación | CURP inválida, campos requeridos faltantes, firma no verificada |
| `500 Internal Server Error` | Error del servidor | Contactar soporte |

### Formato de errores

```json
// Error de validación (422)
{
  "errors": ["Curp tiene un dígito verificador inválido", "Dob no puede estar en blanco"]
}

// Error de autorización (403)
{
  "error": "No autorizado para realizar esta acción."
}

// Error de firma (422)
{
  "error": "Firma electrónica inválida: La firma PKCS#7 no pudo verificarse."
}
```

---

## 18. Seguridad y Cumplimiento Normativo

### Cifrado en reposo (LFPDPPP)

Los siguientes campos se cifran con **ActiveRecord::Encryption** antes de persistir:

| Tabla | Campo | Tipo de cifrado |
|-------|-------|-----------------|
| `patients` | `first_name` | No determinístico (opaco) |
| `patients` | `last_name` | No determinístico (opaco) |
| `patients` | `curp` | **Determinístico** (permite búsquedas) |
| `progress_notes` | `evolution` | No determinístico (opaco) |

### Inmutabilidad (NOM-024)

Los siguientes registros están protegidos contra borrado físico por **triggers PL/pgSQL** en PostgreSQL:

- `progress_notes`
- `clinical_histories`
- `prescriptions`
- `informed_consents`

Intentar un `DELETE` físico retorna la excepción:
> `Prohibido por NOM-024-SSA3-2012: El borrado físico de registros médicos viola la retención obligatoria de 5 años.`

### Auditoría (NOM-024)

**Logidze** inyecta triggers `BEFORE INSERT/UPDATE` en todas las tablas clínicas. Cada cambio se registra en `log_data` (columna JSONB) con:
- Versión del documento (`v`)
- Timestamp del cambio (`ts`)
- Delta de campos modificados (`c`)

### Legal Hold (LFPDPPP vs NOM-004)

El conflicto entre el derecho de **Cancelación ARCO** (LFPDPPP) y la **retención de 5 años** (NOM-004) se resuelve mediante borrado lógico:

- `discard_at` se actualiza con la fecha (registro oculto a usuarios)
- El registro permanece en la base de datos para auditorías judiciales/administrativas
- Solo `admin` puede ver registros descartados

---

## 19. Importación de Catálogos Oficiales

Los catálogos deben poblarse con los archivos CSV oficiales de la Secretaría de Salud y el CSG.

### CIE-10 (Diagnósticos)

```bash
# Descargar CSV del CEMECE/DGIS y ejecutar:
rake catalogs:import_cie10 FILE=/ruta/al/cie10.csv
```

**Formato CSV esperado:** `code,description,category,chapter`

### Cuadro Básico de Medicamentos (CSG)

```bash
rake catalogs:import_medications FILE=/ruta/al/medications.csv
```

**Formato CSV esperado:** `cve_code,name,active_ingredient,route_of_administration,presentation`

### CLUES (Establecimientos)

```bash
rake catalogs:import_clues FILE=/ruta/al/clues.csv
```

**Formato CSV esperado:** `clues_code,name,state_code,municipality,institution_type,status`

---

## Apéndice: Variables de Entorno de Producción

| Variable | Descripción |
|----------|-------------|
| `DATABASE_URL` | URL de conexión PostgreSQL |
| `SECRET_KEY_BASE` | Llave maestra de Rails (mínimo 64 caracteres) |
| `ALLOWED_ORIGINS` | Orígenes CORS permitidos (separados por coma) |
| `EVENI_ECE_API_DATABASE_PASSWORD` | Contraseña de la base de datos en producción |

### Certificados SAT

Colocar los certificados raíz y cadena del SAT en:
```
config/certs/sat/
  ├── sat_root.cer      # Certificado raíz del SAT
  └── sat_intermediate.cer  # Certificado intermedio
```

Descargar desde: [Portal del SAT — Infraestructura PKI](https://www.sat.gob.mx/tramites/16703/obten-tu-certificado-de-e.firma)

---

*Documentación generada para Eveni ECE API v1.0.0 — Cumplimiento NOM-004, NOM-024 y LFPDPPP*
