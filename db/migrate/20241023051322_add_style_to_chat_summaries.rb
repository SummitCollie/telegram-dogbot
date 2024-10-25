# frozen_string_literal: true

class AddStyleToChatSummaries < ActiveRecord::Migration[7.1]
  def change
    add_column :chat_summaries, :style, :string,
               null: true, comment: "User-provided style like 'as a love letter'"

    change_column_comment :chat_summaries, :summary_type,
                          from: '0=default 1=nice 2=vibe_check',
                          to: '0=default 1=custom 2=vibe_check'
  end
end
