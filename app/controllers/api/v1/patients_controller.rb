module Api
  module V1
    class PatientsController < BaseController
      before_action :set_patient, only: [:show, :update]

      def index
        authorize Patient
        patients = policy_scope(Patient).kept
        render json: patients, status: :ok
      end

      def show
        authorize @patient
        render json: @patient, status: :ok
      end

      def create
        authorize Patient
        patient = Patient.new(patient_params)
        if patient.save
          render json: patient, status: :created
        else
          render json: { errors: patient.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        authorize @patient
        if @patient.update(patient_params)
          render json: @patient, status: :ok
        else
          render json: { errors: @patient.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_patient
        @patient = Patient.kept.find(params[:id])
      end

      def patient_params
        params.require(:patient).permit(:curp, :first_name, :last_name, :dob, :sex, :email, :phone)
      end
    end
  end
end
