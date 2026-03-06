module Api
  module V1
    class CluesEstablishmentsController < BaseController
      skip_before_action :authenticate_user!, only: [:index, :show]

      def index
        establishments = CluesEstablishment.all
        establishments = establishments.where("name ILIKE ? OR clues_code ILIKE ?",
                                              "%#{params[:q]}%", "%#{params[:q]}%") if params[:q].present?
        render json: establishments, status: :ok
      end

      def show
        render json: CluesEstablishment.find(params[:id]), status: :ok
      end
    end
  end
end
