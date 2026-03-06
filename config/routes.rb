Rails.application.routes.draw do
  # Devise con JWT — endpoints de autenticación
  devise_for :users,
    path: "api/v1/users",
    controllers: {
      sessions: "api/v1/users/sessions",
      registrations: "api/v1/users/registrations"
    }

  # Namespace API v1 — consumo interno de la aplicación Eveni
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resources :patients, except: [:destroy] do
        resource :clinical_history, only: [:show, :create, :update]
        resources :progress_notes, except: [:destroy] do
          resource :prescription, only: [:show, :create]
          resources :digital_signatures, only: [:create, :index]
        end
        resources :informed_consents, except: [:destroy]
      end

      resources :doctors, except: [:destroy]
      resources :cie10_diagnoses, only: [:index, :show]
      resources :medications_catalogs, only: [:index, :show]
      resources :clues_establishments, only: [:index, :show]
    end

    # Namespace FHIR — interoperabilidad HL7 FHIR R4 (NOM-024)
    namespace :fhir do
      resources :patients, only: [:show], param: :fhir_id
      resources :observations, only: [:show, :index]
      resources :conditions, only: [:show, :index]
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
