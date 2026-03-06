require "rails_helper"

RSpec.describe User, type: :model do
  subject { build(:user) }

  describe "validaciones" do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should define_enum_for(:role).with_values(admin: 0, doctor: 1, nurse: 2, receptionist: 3) }
  end

  describe "borrado lógico (Legal Hold NOM-004)" do
    let(:user) { create(:user) }

    it "discard oculta el registro sin eliminarlo de la base de datos" do
      user.discard
      expect(User.kept).not_to include(user)
      expect(User.discarded).to include(user)
      expect(User.find(user.id)).to eq(user)  # sigue en BD
    end
  end

  describe "autenticación JWT" do
    it "tiene columna jti para revocación" do
      expect(User.column_names).to include("jti")
    end
  end
end
