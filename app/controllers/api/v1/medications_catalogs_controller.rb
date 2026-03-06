module Api
  module V1
    class MedicationsCatalogsController < BaseController
      skip_before_action :authenticate_user!, only: [:index, :show]

      def index
        meds = MedicationsCatalog.all
        meds = meds.where("name ILIKE ? OR cve_code ILIKE ?",
                          "%#{params[:q]}%", "%#{params[:q]}%") if params[:q].present?
        render json: meds, status: :ok
      end

      def show
        render json: MedicationsCatalog.find(params[:id]), status: :ok
      end
    end
  end
end
