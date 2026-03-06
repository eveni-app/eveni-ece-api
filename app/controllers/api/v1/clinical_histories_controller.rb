module Api
  module V1
    class ClinicalHistoriesController < BaseController
      before_action :set_patient

      def show
        @history = @patient.clinical_history
        authorize @history || ClinicalHistory
        render json: @history, status: :ok
      end

      def create
        authorize ClinicalHistory
        @history = @patient.build_clinical_history(history_params)
        if @history.save
          render json: @history, status: :created
        else
          render json: { errors: @history.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        @history = @patient.clinical_history
        authorize @history
        if @history.update(history_params)
          render json: @history, status: :ok
        else
          render json: { errors: @history.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_patient
        @patient = Patient.kept.find(params[:patient_id])
      end

      def history_params
        params.require(:clinical_history).permit(
          hereditary_history: {},
          pathological_history: {},
          non_pathological_history: {},
          gynecological_history: {}
        )
      end
    end
  end
end
