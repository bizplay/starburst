module Starburst
  class Announcement < ActiveRecord::Base
    validates :body, presence: true

    serialize :limit_to_users

    scope :ready_for_delivery, lambda {
      where("(start_delivering_at < ? OR start_delivering_at IS NULL)
				AND (stop_delivering_at > ? OR stop_delivering_at IS NULL)", Time.current, Time.current)
    }

    scope :unread_by, lambda { |current_user|
      joins("LEFT JOIN starburst_announcement_views ON
				starburst_announcement_views.announcement_id = starburst_announcements.id AND
				starburst_announcement_views.user_id = #{sanitize_sql_for_conditions(current_user.id)}")
        .where('starburst_announcement_views.announcement_id IS NULL AND starburst_announcement_views.user_id IS NULL')
    }

    scope :in_delivery_order, -> { order('start_delivering_at ASC') }
    scope :in_reverse_delivery_order, -> { order('start_delivering_at DESC') }

    scope :newer_than, lambda { |from_time|
      where("(start_delivering_at >= ? OR (start_delivering_at IS NULL AND starburst_announcements.created_at >= ?))", from_time, from_time)
    }

    scope :in_category, lambda { |category|
      where(category.nil? ? "" : "category = '#{category}'")
    }

    scope :with_read_by, lambda { |current_user|
      joins("LEFT JOIN starburst_announcement_views ON
				starburst_announcement_views.announcement_id = starburst_announcements.id AND
        starburst_announcement_views.user_id = #{sanitize_sql_for_conditions(current_user.id)}")
        .select('starburst_announcements.*, COUNT(starburst_announcement_views.id) AS read')
        .group('starburst_announcements.id')
    }

    def self.current(current_user)
      raise ArgumentError, 'User is required to find current announcement' unless current_user.present?

      find_announcement_for_current_user(ready_for_delivery.unread_by(current_user).in_delivery_order, current_user)
    end

    def self.find_announcement_for_current_user(announcements, user)
      announcements_for_current_user(announcements, user).first
    end

    def self.announcements_for_current_user(announcements, user)
      user_as_array = user.serializable_hash(methods: Starburst.user_instance_methods)

      announcements.select do |announcement| 
        user_matches_conditions(user_as_array, announcement.limit_to_users)
      end
    end

    def self.all_recent_for(current_user, as_of = 2.weeks.ago, in_category = nil)
      announcements_for_current_user(ready_for_delivery.newer_than(as_of).with_read_by(current_user).in_category(in_category).in_reverse_delivery_order, current_user)
    end

    def self.user_matches_conditions(user, conditions = nil)
      if conditions
        conditions.each do |condition|
          return false if user[condition[:field]] != condition[:value]
        end
      end
      true
    end
  end
end
