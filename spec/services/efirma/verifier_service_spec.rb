require "rails_helper"
require "openssl"
require "base64"

RSpec.describe Efirma::VerifierService do
  # Genera un par de claves RSA de prueba y firma un payload para simular e.firma SAT
  let(:key_pair)   { OpenSSL::PKey::RSA.generate(2048) }
  let(:payload)    { "Nota médica de prueba para Eveni — paciente: HEGG560427MVZRRL04" }
  let(:cert)       { generate_self_signed_cert(key_pair) }
  let(:sig_b64)    { sign_payload(payload, key_pair, cert) }

  describe "#call" do
    context "con firma PKCS#7 válida" do
      it "retorna success: true" do
        result = described_class.new(
          signature_b64: sig_b64,
          certificate_pem: cert.to_pem,
          original_payload: payload
        ).call

        expect(result.success?).to be true
        expect(result.error).to be_nil
      end
    end

    context "con payload alterado después de firmar" do
      it "retorna success: false por integridad comprometida" do
        result = described_class.new(
          signature_b64: sig_b64,
          certificate_pem: cert.to_pem,
          original_payload: "Payload alterado"
        ).call

        expect(result.success?).to be false
        expect(result.error).to be_present
      end
    end

    context "con firma inválida (Base64 corrupto)" do
      it "retorna success: false con mensaje de error" do
        result = described_class.new(
          signature_b64: "FIRMA_BASE64_INVALIDA==",
          certificate_pem: cert.to_pem,
          original_payload: payload
        ).call

        expect(result.success?).to be false
        expect(result.error).to be_present
      end
    end
  end

  private

  def generate_self_signed_cert(key)
    cert = OpenSSL::X509::Certificate.new
    cert.version   = 2
    cert.serial    = rand(1..9999)
    cert.subject   = OpenSSL::X509::Name.parse("/CN=Doctor Prueba Eveni/O=Test SAT/C=MX")
    cert.issuer    = cert.subject
    cert.public_key = key.public_key
    cert.not_before = Time.now
    cert.not_after  = Time.now + 365 * 24 * 60 * 60
    cert.sign(key, OpenSSL::Digest::SHA256.new)
    cert
  end

  def sign_payload(data, key, cert)
    p7 = OpenSSL::PKCS7.sign(
      cert, key, data, [],
      OpenSSL::PKCS7::DETACHED | OpenSSL::PKCS7::BINARY
    )
    Base64.strict_encode64(p7.to_der)
  end
end