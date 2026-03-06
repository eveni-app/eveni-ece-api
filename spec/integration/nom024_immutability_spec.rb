require "rails_helper"

# Tests de integración para verificar la inmutabilidad impuesta por los
# triggers PL/pgSQL (NOM-024-SSA3-2012 — registros inalterables)
RSpec.describe "NOM-024 Inmutabilidad de registros clínicos", type: :model do
  let(:note)    { create(:progress_note) }
  let(:history) { create(:clinical_history) }

  describe "Trigger prevent_hard_deletes en progress_notes" do
    it "impide el borrado físico de una nota de evolución" do
      expect {
        ActiveRecord::Base.connection.execute(
          "DELETE FROM progress_notes WHERE id = '#{note.id}'"
        )
      }.to raise_error(ActiveRecord::StatementInvalid, /NOM-024|Prohibido/)
    end

    it "permite el borrado lógico (discard) sin activar el trigger" do
      expect { note.discard }.not_to raise_error
      expect(note.discarded_at).not_to be_nil
    end

    it "mantiene el registro físicamente después del discard" do
      note.discard
      expect(ProgressNote.find(note.id)).to eq(note)
    end
  end

  describe "Trigger prevent_hard_deletes en clinical_histories" do
    it "impide el borrado físico del historial clínico" do
      expect {
        ActiveRecord::Base.connection.execute(
          "DELETE FROM clinical_histories WHERE id = '#{history.id}'"
        )
      }.to raise_error(ActiveRecord::StatementInvalid, /NOM-024|Prohibido/)
    end
  end

  describe "Logidze — trazabilidad de cambios (NOM-024 § bitácora)" do
    it "registra la versión inicial en log_data al crear una nota" do
      note.reload
      expect(note.log_data).not_to be_nil
      expect(note.log_data.version).to eq(1)
    end

    it "incrementa la versión en log_data al actualizar una nota" do
      note.update!(prognosis: "Reservado")
      note.reload
      expect(note.log_data.version).to be >= 2
    end

    it "conserva el historial de versiones en log_data" do
      note.update!(prognosis: "Nuevo pronóstico")
      note.reload
      expect(note.log_data.versions.size).to be >= 2
    end
  end
end