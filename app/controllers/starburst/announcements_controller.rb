# frozen_string_literal: true

module Starburst
  class AnnouncementsController < Starburst.base_controller.constantize
    def recent
      if respond_to?(Starburst.current_user_method, true) && send(Starburst.current_user_method)
        result = Announcement.all_recent_for(send(Starburst.current_user_method), 2.weeks.ago, params[:category])
        render json: result, only: [ :id, :title, :body ], status: :ok
      else
        render json: nil, status: :unprocessable_entity
      end
    end

    def mark_as_read
      announcement = Announcement.find(params[:id].to_i)
      if respond_to?(Starburst.current_user_method, true) && send(Starburst.current_user_method) && announcement
        if AnnouncementView.where(user_id: send(Starburst.current_user_method).id, announcement_id: announcement.id).first_or_create(user_id: send(Starburst.current_user_method).id, announcement_id: announcement.id)
          render json: :ok
        else
          render json: nil, status: :unprocessable_entity
        end
      else
        render json: nil, status: :unprocessable_entity
      end
    end
  end
end
