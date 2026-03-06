  Fases completadas                                                                                                                                                

  Fase 1 — Inicialización
  - Rails 8.1.2 API + PostgreSQL 16, todas las gemas del plan instaladas
  - Extensiones UUID (pgcrypto, uuid-ossp), todos los IDs como UUID

  Fase 2 — Seguridad y Actores
  - Devise + devise-jwt con estrategia JTIMatcher (revocación de sesiones)
  - Roles RBAC via enum: admin, doctor, nurse, receptionist

  Fase 3 — Identidad CURP
  - CurpValidator con regex morfológico RENAPO + algoritmo Módulo 10 Ñ-aware
  - ActiveRecord::Encryption para first_name, last_name (opaco) y curp (deterministic para búsquedas)
  - Soft delete con discard en Users, Doctors, Patients (Legal Hold NOM-004)

  Fase 4 — ECE + Auditoría Inmutable
  - Modelos: ClinicalHistory, ProgressNote, Prescription, InformedConsent
  - Triggers PL/pgSQL prevent_hard_deletes en 4 tablas — nadie puede hacer DELETE físico
  - logidze inyecta triggers de auditoría (INSERT/UPDATE) → columna log_data

  Fase 5 — Firma Electrónica SAT
  - Efirma::VerifierService — verificación PKCS#7 con banderas DETACHED | BINARY | NOVERIFY
  - Modelo polimórfico DigitalSignature con sello de tiempo signed_at

  Fase 6 — Catálogos + FHIR
  - Catálogos: Cie10Diagnosis, MedicationsCatalog, CluesEstablishment
  - Rake tasks para importar CSV oficiales de la SSA
  - Namespace /api/fhir con serializadores Blueprinter: Patient → FHIR Patient, vital_signs → FHIR Observation, diagnoses → FHIR Condition

  Fase 7 — Suite de Pruebas
  - 14 unit tests (CurpValidator, Patient, User, ProgressNote)
  - 9 integration tests (triggers NOM-024, Logidze)
  - 6 functional/request tests (RBAC, JWT, CURP inválida → 422)
  - 3 service tests (Efirma PKCS#7)

  Pendiente para producción

  1. Poblar config/certs/sat/ con certificados raíz del SAT
  2. Importar catálogos: rake catalogs:import_cie10 FILE=cie10.csv
  3. Configurar variables de entorno de producción