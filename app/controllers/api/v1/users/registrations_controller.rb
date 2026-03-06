module Api
  module V1
    module Users
      class RegistrationsController < Devise::RegistrationsController
        respond_to :json

        before_action :configure_sign_up_params, only: [:create]

        private

        def respond_with(resource, _opts = {})
          if resource.persisted?
            render json: {
              message: "Usuario registrado correctamente.",
              user: { id: resource.id, email: resource.email, role: resource.role }
            }, status: :created
          else
            render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def configure_sign_up_params
          devise_parameter_sanitizer.permit(:sign_up, keys: [:role])
        end
      end
    end
  end
end
