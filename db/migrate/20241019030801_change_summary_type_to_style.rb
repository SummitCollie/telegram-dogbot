# frozen_string_literal: true

class ChangeSummaryTypeToStyle < ActiveRecord::Migration[7.1]
  def change
    change_table :chat_summaries, bulk: true do |t|
      t.remove :summary_type, type: :integer
      t.column :style, :string, null: true, comment: "User-provided style text like 'as a love letter'"
    end
  end
end
