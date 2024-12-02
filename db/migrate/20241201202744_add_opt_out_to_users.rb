class AddOptOutToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :opt_out, :boolean, null: false, default: false
  end
end
