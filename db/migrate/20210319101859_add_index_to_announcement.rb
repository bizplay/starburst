class AddIndexToAnnouncement < ActiveRecord::Migration[5.2]
  def change
    add_index :starburst_announcements, :group_id
  end
end
