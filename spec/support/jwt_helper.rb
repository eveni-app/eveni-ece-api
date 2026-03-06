module JwtHelper
  # Genera un JWT válido para el usuario dado y lo retorna en el header Authorization.
  # Asegura que el usuario tenga un JTI válido antes de generar el token.
  def auth_headers_for(user)
    user.update_column(:jti, SecureRandom.uuid) if user.jti.blank?
    token, = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)
    { "Authorization" => "Bearer #{token}" }
  end
end

RSpec.configure do |config|
  config.include JwtHelper, type: :request
end
