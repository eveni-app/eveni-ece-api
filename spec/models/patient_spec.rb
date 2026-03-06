require "rails_helper"

RSpec.describe Patient, type: :model do
  describe "validaciones de CURP (NOM-024 § Identificación)" do
    it "acepta una CURP válida con dígito verificador correcto" do
      patient = build(:patient, curp: "HEGG560427MVZRRL04")
      expect(patient).to be_valid
    end

    it "rechaza una CURP con formato incorrecto" do
      patient = build(:patient, curp: "CURP_INVALIDA_123")
      expect(patient).not_to be_valid
      expect(patient.errors[:curp].join).to include("formato")
    end

    it "rechaza una CURP con dígito verificador incorrecto" do
      # CURP con todos los campos válidos pero el dígito 18 alterado
      patient = build(:patient, curp: "HEGG560427MVZRRL09")
      expect(patient).not_to be_valid
      expect(patient.errors[:curp].join).to include("dígito verificador")
    end

    it "rechaza una CURP demasiado corta" do
      patient = build(:patient, curp: "HEGG5604")
      expect(patient).not_to be_valid
    end

    it "rechaza una CURP nula" do
      patient = build(:patient, curp: nil)
      expect(patient).not_to be_valid
    end
  end

  describe "cifrado de datos sensibles (LFPDPPP)" do
    let(:patient) { create(:patient, first_name: "Guadalupe", last_name: "Ramírez") }

    it "almacena el nombre cifrado en la base de datos" do
      raw = ActiveRecord::Base.connection.execute(
        "SELECT first_name FROM patients WHERE id = '#{patient.id}'"
      ).first["first_name"]
      expect(raw).not_to eq("Guadalupe")
    end

    it "descifra correctamente el nombre al leerlo desde el modelo" do
      expect(patient.reload.first_name).to eq("Guadalupe")
    end

    it "permite búsqueda por CURP (deterministic encryption)" do
      found = Patient.find_by(curp: patient.curp)
      expect(found).to eq(patient)
    end
  end

  describe "borrado lógico (Legal Hold NOM-004 retención 5 años)" do
    let(:patient) { create(:patient) }

    it "discard oculta el registro sin eliminarlo físicamente" do
      patient.discard
      expect(Patient.kept).not_to include(patient)
      expect(Patient.find(patient.id)).to eq(patient)
    end

    it "no permite destroy directamente (NOM-004)" do
      expect { patient.destroy }.not_to change(Patient, :count)
    end
  end
end