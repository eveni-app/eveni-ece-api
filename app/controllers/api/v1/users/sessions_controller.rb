module Api
  module V1
    module Users
      class SessionsController < Devise::SessionsController
        respond_to :json

        private

        def respond_with(resource, _opts = {})
          render json: {
            message: "Sesión iniciada correctamente.",
            user: {
              id: resource.id,
              email: resource.email,
              role: resource.role
            }
          }, status: :ok
        end

        def respond_to_on_destroy
          if current_user
            render json: { message: "Sesión cerrada correctamente." }, status: :ok
          else
            render json: { message: "No se pudo cerrar la sesión." }, status: :unauthorized
          end
        end
      end
    end
  end
end
