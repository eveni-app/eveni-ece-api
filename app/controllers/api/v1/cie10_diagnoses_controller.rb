module Api
  module V1
    class Cie10DiagnosesController < BaseController
      skip_before_action :authenticate_user!, only: [ :index, :show ]

      def index
        diagnoses = Cie10Diagnosis.all
        diagnoses = diagnoses.where("code ILIKE ?", "%#{params[:q]}%").or(
          Cie10Diagnosis.where("description ILIKE ?", "%#{params[:q]}%")
        ) if params[:q].present?
        render json: diagnoses, status: :ok
      end

      def show
        render json: Cie10Diagnosis.find(params[:id]), status: :ok
      end
    end
  end
end
