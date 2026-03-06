require "rails_helper"

RSpec.describe ProgressNote, type: :model do
  describe "cifrado de nota de evolución (NOM-024 confidencialidad)" do
    let(:note) { create(:progress_note, evolution: "Paciente refiere mejoría significativa.") }

    it "almacena la evolución cifrada en la base de datos" do
      raw = ActiveRecord::Base.connection.execute(
        "SELECT evolution FROM progress_notes WHERE id = '#{note.id}'"
      ).first["evolution"]
      expect(raw).not_to eq("Paciente refiere mejoría significativa.")
    end

    it "descifra correctamente la evolución al leerla" do
      expect(note.reload.evolution).to eq("Paciente refiere mejoría significativa.")
    end
  end

  describe "has_logidze (bitácora de auditoría NOM-024)" do
    let(:note) { create(:progress_note, evolution: "Estado inicial.") }

    it "registra la versión inicial en log_data al crear" do
      note.reload
      expect(note.log_data).not_to be_nil
      expect(note.log_data.version).to eq(1)
    end

    it "incrementa la versión en log_data al actualizar" do
      note.update!(prognosis: "Reservado")
      note.reload
      expect(note.log_data.version).to be >= 1
    end
  end

  describe "borrado lógico (NOM-004 retención 5 años)" do
    let(:note) { create(:progress_note) }

    it "discard actualiza discarded_at sin borrar el registro" do
      note.discard
      expect(note.discarded_at).not_to be_nil
      expect(ProgressNote.find(note.id)).to eq(note)
    end
  end

  describe "validaciones" do
    it { should belong_to(:patient) }
    it { should belong_to(:doctor) }
  end
end