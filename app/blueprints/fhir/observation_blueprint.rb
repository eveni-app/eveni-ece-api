module Fhir
  # Serializa signos vitales (vital_signs JSONB) de ProgressNote al recurso FHIR Observation.
  # Referencia: https://hl7.org/fhir/R4/observation.html
  class ObservationBlueprint < Blueprinter::Base
    # Mapeo de campos de signos vitales a códigos LOINC estándar
    VITAL_SIGN_CODES = {
      "blood_pressure_systolic"  => { code: "8480-6",  display: "Systolic blood pressure",  unit: "mm[Hg]" },
      "blood_pressure_diastolic" => { code: "8462-4",  display: "Diastolic blood pressure", unit: "mm[Hg]" },
      "heart_rate"               => { code: "8867-4",  display: "Heart rate",               unit: "/min" },
      "respiratory_rate"         => { code: "9279-1",  display: "Respiratory rate",         unit: "/min" },
      "temperature"              => { code: "8310-5",  display: "Body temperature",         unit: "Cel" },
      "oxygen_saturation"        => { code: "2708-6",  display: "Oxygen saturation",        unit: "%" },
      "weight"                   => { code: "29463-7", display: "Body weight",              unit: "kg" },
      "height"                   => { code: "8302-2",  display: "Body height",              unit: "cm" }
    }.freeze

    # Transforma un ProgressNote en un array de recursos FHIR Observation
    def self.render_vital_signs(progress_note)
      progress_note.vital_signs.filter_map do |key, value|
        next if value.blank?

        meta = VITAL_SIGN_CODES[key]
        next unless meta

        {
          resourceType: "Observation",
          id: "#{progress_note.id}-#{key}",
          status: "final",
          category: [
            {
              coding: [
                { system: "http://terminology.hl7.org/CodeSystem/observation-category",
                  code: "vital-signs", display: "Vital Signs" }
              ]
            }
          ],
          code: {
            coding: [
              { system: "http://loinc.org", code: meta[:code], display: meta[:display] }
            ],
            text: meta[:display]
          },
          subject: { reference: "Patient/#{progress_note.patient_id}" },
          effectiveDateTime: progress_note.created_at&.iso8601,
          valueQuantity: {
            value: value.to_f,
            unit: meta[:unit],
            system: "http://unitsofmeasure.org",
            code: meta[:unit]
          }
        }
      end
    end
  end
end
