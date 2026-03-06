module Api
  module Fhir
    class ConditionsController < BaseController
      def show
        note = ProgressNote.kept.find(params[:id])
        authorize note, :show?
        conditions = ::Fhir::ConditionBlueprint.render_diagnoses(note)
        render json: { resourceType: "Bundle", type: "searchset", entry: conditions }, status: :ok
      end

      def index
        patient = Patient.kept.find(params[:patient_id]) if params[:patient_id]
        notes = patient ? patient.progress_notes.kept : ProgressNote.kept
        conditions = notes.flat_map { |n| ::Fhir::ConditionBlueprint.render_diagnoses(n) }
        render json: { resourceType: "Bundle", type: "searchset", total: conditions.size, entry: conditions },
               status: :ok
      end
    end
  end
end
