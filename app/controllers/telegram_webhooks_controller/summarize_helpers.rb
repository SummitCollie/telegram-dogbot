# frozen_string_literal: true

class TelegramWebhooksController
  module SummarizeHelpers
    extend self

    def ensure_summarize_allowed!
      # Delete old ChatSummaries that aren't complete after 1 minute
      db_chat.chat_summaries.where(status: :running, created_at: ...1.minute.ago).destroy_all

      return unless db_chat&.summarize_job_running?

      raise FuckyWuckies::SummarizeJobFailure.new(
        frontend_message: 'Still working on another summary!!',
        sticker: :heavy_typing
      ), 'Summarize job already in progress: ' \
         "chat api_id=#{chat.id}"
    end

    # Returns [url, style_text]
    def parse_summarize_url_command
      cmd_entity = first_url_entity(payload)
      replied_entity = first_url_entity(payload.reply_to_message)

      if cmd_entity.blank? && replied_entity.blank?
        raise FuckyWuckies::MissingArgsError.new(
          severity: Logger::Severity::INFO,
          db_chat:,
          frontend_message: "📝 <b><u>Summarize URL</u></b>\n      " \
                            "<i>Error: no URL provided</i>\n\n" \
                            "#{summarize_help_text}",
          parse_mode: 'HTML'
        ), 'Aborting URL summarization, no URL found: ' \
           "chat api_id=#{db_chat.id} title=#{db_chat.title}"
      end

      if cmd_entity
        # Ignore replied msg, URL in command msg takes priority
        offset = cmd_entity.offset
        length = cmd_entity.length

        url = payload.text[offset, length]

        style_text = [
          payload.text[..offset - 1],
          payload.text[(offset + length)..]
        ].map(&:strip)
                     .compact_blank
                     .join(', ')
      else
        # No URL in command msg, so use the one from the replied msg
        offset = replied_entity.offset
        length = replied_entity.length

        url = payload.reply_to_message.text[offset, length]
        style_text = payload.text
      end

      [url, TelegramTools.strip_bot_command('summarize_url', style_text)]
    end

    def first_url_entity(api_message)
      api_message.try(:entities)&.find { |e| e.type == 'url' }
    end

    def summarize_help_text
      <<~HELPINFO.strip
        <blockquote><code>/summarize</code> has split into <code>/summarize_chat</code> and <code>/summarize_url</code>!

        <code>/summarize_nicely</code> was removed because both <code>/summarize_url</code> and <code>/summarize_chat</code> now support custom summary styles (see below).
        </blockquote>
        • <b>Default neutral style:</b> <pre>/summarize_url https://example.com/article</pre>

        • <b>Custom style:</b>
          (URL/style order doesn't matter) <pre>/summarize_url https://example.com/article as though it's being presented as evidence in a court case</pre>

        <code>/summarize_chat</code> works the same way.
      HELPINFO
    end
  end
end
