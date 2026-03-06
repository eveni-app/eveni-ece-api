module Api
  module V1
    class DigitalSignaturesController < BaseController
      before_action :set_patient
      before_action :set_progress_note

      def index
        authorize DigitalSignature
        signatures = @progress_note.digital_signatures
        render json: signatures, status: :ok
      end

      def create
        authorize DigitalSignature
        result = Efirma::VerifierService.new(
          signature_b64: signature_params[:signature_payload],
          certificate_pem: signature_params[:certificate_pem],
          original_payload: signature_params[:original_payload]
        ).call

        unless result.success?
          return render json: { error: "Firma electrónica inválida: #{result.error}" },
                        status: :unprocessable_entity
        end

        signature = @progress_note.digital_signatures.new(
          doctor: current_user.doctor,
          signature_payload: signature_params[:signature_payload],
          certificate_serial: signature_params[:certificate_serial],
          signed_at: Time.current
        )

        if signature.save
          render json: signature, status: :created
        else
          render json: { errors: signature.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_patient
        @patient = Patient.kept.find(params[:patient_id])
      end

      def set_progress_note
        @progress_note = @patient.progress_notes.kept.find(params[:progress_note_id])
      end

      def signature_params
        params.require(:digital_signature).permit(
          :signature_payload, :certificate_pem, :original_payload, :certificate_serial
        )
      end
    end
  end
end
