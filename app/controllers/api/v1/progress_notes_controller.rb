module Api
  module V1
    class ProgressNotesController < BaseController
      before_action :set_patient
      before_action :set_note, only: [:show, :update]

      def index
        authorize ProgressNote
        notes = policy_scope(@patient.progress_notes).kept
        render json: notes, status: :ok
      end

      def show
        authorize @note
        render json: @note, status: :ok
      end

      def create
        authorize ProgressNote
        note = @patient.progress_notes.new(note_params)
        note.doctor = current_user.doctor
        if note.save
          render json: note, status: :created
        else
          render json: { errors: note.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        authorize @note
        if @note.update(note_params)
          render json: @note, status: :ok
        else
          render json: { errors: @note.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_patient
        @patient = Patient.kept.find(params[:patient_id])
      end

      def set_note
        @note = @patient.progress_notes.kept.find(params[:id])
      end

      def note_params
        params.require(:progress_note).permit(
          :evolution, :prognosis, :treatment_plan, :note_type,
          vital_signs: {},
          diagnoses: []
        )
      end
    end
  end
end
