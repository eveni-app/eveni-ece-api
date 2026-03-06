module Api
  module Fhir
    class BaseController < ApplicationController
      before_action :authenticate_user!

      # Encabezados FHIR R4
      before_action do
        response.headers["Content-Type"] = "application/fhir+json; fhirVersion=4.0"
      end
    end
  end
end
