require "openssl"
require "base64"

module Efirma
  # Servicio de verificación de firma electrónica avanzada (e.firma SAT).
  #
  # Implementa el flujo de validación PKCS#7 sin custodia de clave privada.
  # El backend únicamente verifica — la firma se genera en el cliente (NOM-024).
  #
  # Uso:
  #   result = Efirma::VerifierService.new(
  #     signature_b64: "...",   # Firma PKCS#7 detached en Base64
  #     certificate_pem: "...", # Certificado público .cer del médico (PEM o DER)
  #     original_payload: "...", # Texto plano original que se firmó
  #   ).call
  #
  #   result.success? → true/false
  #   result.error    → mensaje de error si falla
  class VerifierService
    Result = Struct.new(:success, :error, keyword_init: true) do
      def success? = success
    end

    CERTS_PATH = Rails.root.join("config", "certs", "sat")

    def initialize(signature_b64:, certificate_pem:, original_payload:)
      @signature_b64    = signature_b64
      @certificate_pem  = certificate_pem
      @original_payload = original_payload
    end

    def call
      public_cert = load_certificate(@certificate_pem)
      p7          = load_pkcs7(@signature_b64)
      store       = build_trust_store

      flags = OpenSSL::PKCS7::DETACHED |
              OpenSSL::PKCS7::BINARY   |
              OpenSSL::PKCS7::NOVERIFY  # Permite operar sin cadena completa en dev/test

      verified = p7.verify(
        [public_cert],
        store,
        @original_payload,
        flags
      )

      if verified
        Result.new(success: true, error: nil)
      else
        Result.new(success: false, error: "La firma PKCS#7 no pudo verificarse contra el certificado proporcionado.")
      end
    rescue OpenSSL::PKCS7::PKCS7Error => e
      Result.new(success: false, error: "Error PKCS#7: #{e.message}")
    rescue OpenSSL::X509::CertificateError => e
      Result.new(success: false, error: "Certificado inválido: #{e.message}")
    rescue StandardError => e
      Result.new(success: false, error: "Error de verificación: #{e.message}")
    end

    private

    # Carga el certificado público del médico en formato PEM o DER.
    def load_certificate(raw)
      return OpenSSL::X509::Certificate.new(raw) if raw.include?("BEGIN CERTIFICATE")

      OpenSSL::X509::Certificate.new(Base64.decode64(raw))
    rescue OpenSSL::X509::CertificateError
      OpenSSL::X509::Certificate.new(raw) # intento como DER binario
    end

    # Decodifica la firma PKCS#7 de Base64.
    def load_pkcs7(b64)
      der = Base64.strict_decode64(b64)
      OpenSSL::PKCS7.new(der)
    rescue ArgumentError
      # Intento con decode64 permisivo si strict falla (líneas extra, etc.)
      OpenSSL::PKCS7.new(Base64.decode64(b64))
    end

    # Construye el almacén de confianza X.509 con los certificados raíz del SAT.
    # En producción, poblar config/certs/sat/ con los .cer descargados del SAT.
    def build_trust_store
      store = OpenSSL::X509::Store.new
      store.set_default_paths

      Dir[CERTS_PATH.join("*.cer"), CERTS_PATH.join("*.pem")].each do |cert_path|
        raw = File.read(cert_path)
        cert = raw.include?("BEGIN CERTIFICATE") ?
          OpenSSL::X509::Certificate.new(raw) :
          OpenSSL::X509::Certificate.new(File.binread(cert_path))
        store.add_cert(cert)
      rescue OpenSSL::X509::CertificateError => e
        Rails.logger.warn "[Efirma::VerifierService] No se pudo cargar #{cert_path}: #{e.message}"
      end

      store
    end
  end
end
