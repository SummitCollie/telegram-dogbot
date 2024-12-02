# frozen_string_literal: true

class UserOptOut
  class << self
    def opt_out(db_user)
      db_user.update!(opt_out: true)
      db_user.messages.destroy_all
    end

    def opt_in(db_user)
      db_user.update!(opt_out: false)
    end

    def infotext(db_user)
      <<~INFOTEXT.strip
        <b>#{if db_user.opt_out
          '⭕️ You are currently opted-out and invisible to this bot.'
        else
          '🟢 You are currently opted-in and visible to this bot.'
        end}</b>

        <blockquote>😿 <i>I care about privacy!! This bot isn't designed to spy or collect data on you, it's just for fun and \
        <a href="https://github.com/SummitCollie/telegram-dogbot">fully open-source.</a>

        Even if you remain opted-in, all messages older than 48 hours are deleted on a nightly basis \
        (see <a href="https://github.com/SummitCollie/telegram-dogbot/blob/master/lib/tasks/nightly_data_purge.rake">\
        this code</a>).

        The only reason it stores messages for 48 hours is because it's necessary to provide chat/summarization features.</i></blockquote>

        Opting out means:
          • Your messages will never be stored by this bot.
          • Any commands you run will be ignored.
          • The bot will never reply to you.
          • You won't show up in summaries, stats, vibe checks, etc.
          • All of the above applies globally (all chatrooms).
          • You will start saying things like "bah humbug" in your daily life.
          • All of your messages will be deleted from the bot's DB immediately.

        Some edge cases: in certain situations, for example if another user tags the bot in a reply to one of your messages, \
        or if they translate one of your messages, the bot will still see your message while generating a response. \
        It won't store your message directly, but it'll store the other user's message and its own reply, \
        so little bits of your data could leak into LLM prompts that way I suppose. Take it up with the other user.

        #{if db_user.opt_out
            'Use <code>/im_deeply_sorry_please_take_me_back</code> to opt back in and make yourself visible to the bot again.'
          else
            'To confirm opt-out, run <code>/i_hate_you_and_never_want_to_see_you_again</code>'
          end}
      INFOTEXT
    end
  end
end
