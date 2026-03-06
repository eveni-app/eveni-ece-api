module Api
  module Fhir
    class PatientsController < BaseController
      def show
        patient = Patient.kept.find(params[:fhir_id])
        authorize patient, :show?
        render json: ::Fhir::PatientBlueprint.render_as_hash(patient), status: :ok
      end
    end
  end
end
