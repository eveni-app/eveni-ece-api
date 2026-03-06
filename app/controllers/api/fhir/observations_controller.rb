module Api
  module Fhir
    class ObservationsController < BaseController
      def show
        note = ProgressNote.kept.find(params[:id])
        authorize note, :show?
        observations = ::Fhir::ObservationBlueprint.render_vital_signs(note)
        render json: { resourceType: "Bundle", type: "searchset", entry: observations }, status: :ok
      end

      def index
        patient = Patient.kept.find(params[:patient_id]) if params[:patient_id]
        notes = patient ? patient.progress_notes.kept : ProgressNote.kept
        observations = notes.flat_map { |n| ::Fhir::ObservationBlueprint.render_vital_signs(n) }
        render json: { resourceType: "Bundle", type: "searchset", total: observations.size, entry: observations },
               status: :ok
      end
    end
  end
end
