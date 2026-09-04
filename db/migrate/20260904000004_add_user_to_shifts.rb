class AddUserToShifts < ActiveRecord::Migration[8.1]
  def change
    add_reference :shifts, :user, null: false, foreign_key: true
  end
end
