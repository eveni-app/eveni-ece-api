require "rails_helper"

RSpec.describe "Api::V1::Patients", type: :request do
  let(:doctor_user)      { create(:user, :doctor) }
  let(:receptionist_user) { create(:user, :receptionist) }
  let(:patient)          { create(:patient) }

  describe "GET /api/v1/patients" do
    context "cuando el usuario es doctor (autorizado)" do
      it "devuelve 200 OK con lista de pacientes" do
        patient
        get "/api/v1/patients", headers: auth_headers_for(doctor_user)
        expect(response).to have_http_status(:ok)
      end
    end

    context "sin autenticación JWT" do
      it "devuelve 401 Unauthorized" do
        get "/api/v1/patients"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/patients" do
    let(:valid_params) do
      {
        patient: {
          curp: "HEGG560427MVZRRL04",
          first_name: "Juan",
          last_name: "García",
          dob: "1985-01-15",
          sex: "male"
        }
      }
    end

    context "cuando el doctor crea un paciente con CURP válida" do
      it "devuelve 201 Created" do
        post "/api/v1/patients",
             params: valid_params,
             headers: auth_headers_for(doctor_user)
        expect(response).to have_http_status(:created)
      end
    end

    context "con CURP inválida" do
      it "devuelve 422 Unprocessable Entity" do
        post "/api/v1/patients",
             params: { patient: valid_params[:patient].merge(curp: "CURP_INVALIDA_999") },
             headers: auth_headers_for(doctor_user)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["errors"]).to be_present
      end
    end
  end

  describe "GET /api/v1/patients/:id/progress_notes — restricción de roles (NOM-024 RBAC)" do
    let!(:note) { create(:progress_note, patient: patient) }

    context "cuando el usuario es recepcionista" do
      it "devuelve 403 Forbidden al intentar acceder a notas médicas" do
        get "/api/v1/patients/#{patient.id}/progress_notes",
            headers: auth_headers_for(receptionist_user)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "cuando el usuario es doctor" do
      it "devuelve 200 OK con las notas del paciente" do
        create(:doctor, user: doctor_user)
        get "/api/v1/patients/#{patient.id}/progress_notes",
            headers: auth_headers_for(doctor_user)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end