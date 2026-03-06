module Fhir
  # Serializa diagnósticos de ProgressNote (array CIE-10) al recurso FHIR Condition.
  # Referencia: https://hl7.org/fhir/R4/condition.html
  class ConditionBlueprint < Blueprinter::Base
    # Transforma el array diagnoses de un ProgressNote en resources FHIR Condition
    def self.render_diagnoses(progress_note)
      progress_note.diagnoses.map.with_index do |diagnosis, index|
        {
          resourceType: "Condition",
          id: "#{progress_note.id}-condition-#{index}",
          clinicalStatus: {
            coding: [
              { system: "http://terminology.hl7.org/CodeSystem/condition-clinical",
                code: "active" }
            ]
          },
          verificationStatus: {
            coding: [
              { system: "http://terminology.hl7.org/CodeSystem/condition-ver-status",
                code: "confirmed" }
            ]
          },
          code: {
            coding: [
              {
                system: "http://hl7.org/fhir/sid/icd-10",
                code: diagnosis["code"],
                display: diagnosis["description"]
              }
            ],
            text: diagnosis["description"]
          },
          subject: { reference: "Patient/#{progress_note.patient_id}" },
          encounter: { reference: "Encounter/#{progress_note.id}" },
          recordedDate: progress_note.created_at&.iso8601,
          recorder: { reference: "Practitioner/#{progress_note.doctor_id}" }
        }
      end
    end
  end
end
