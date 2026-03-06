module Fhir
  # Serializa un Patient de Rails al recurso HL7 FHIR R4 Patient.
  # Referencia: https://hl7.org/fhir/R4/patient.html
  class PatientBlueprint < Blueprinter::Base
    field :resourceType do
      "Patient"
    end

    field :id, name: :id

    field :identifier do |patient|
      [
        {
          use: "official",
          system: "https://www.gob.mx/renapo",
          type: {
            coding: [
              { system: "http://terminology.hl7.org/CodeSystem/v2-0203", code: "NI", display: "National unique individual identifier" }
            ],
            text: "CURP"
          },
          value: patient.curp
        }
      ]
    end

    field :name do |patient|
      [
        {
          use: "official",
          family: patient.last_name,
          given: [ patient.first_name ]
        }
      ]
    end

    field :birthDate do |patient|
      patient.dob&.iso8601
    end

    field :gender do |patient|
      case patient.sex
      when "male"       then "male"
      when "female"     then "female"
      when "non_binary" then "other"
      end
    end

    field :meta do |patient|
      {
        profile: [ "http://hl7.org/fhir/StructureDefinition/Patient" ],
        lastUpdated: patient.updated_at&.iso8601
      }
    end
  end
end
