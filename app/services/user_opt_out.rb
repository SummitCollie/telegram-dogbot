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
        <b>You are currently #{db_user.opt_out ? 'opted-out and invisible' : 'opted-in and visible'} to this bot.</b>

        <blockquote><i>Please note: I care about privacy!! This bot is not designed to spy or collect data on you, it's just for fun and \
        <a href="https://github.com/SummitCollie/telegram-dogbot">fully open-source.</a>

        Even if you remain opted-in, all messages older than 48 hours are deleted on a nightly basis \
        (<a href="https://github.com/SummitCollie/telegram-dogbot/blob/master/lib/tasks/nightly_data_purge.rake">\
        source code for proof</a>).

        The only reason it stores messages for 48 hours is because it's necessary to provide chat/summarization features.</i></blockquote>

        Opting out means:
          • Your messages will never be stored by this bot.
          • Any commands you run will be ignored.
          • The bot will never reply to you.
          • You won't show up in chat summaries, chat stats, vibe checks, etc.
          • All of the above applies globally, in every chatroom where the bot is present.
          • All messages from you will immediately be deleted from the bot's DB.

        In certain situations, like if another user tags the bot in a reply to one of your messages, \
        or translates one of your messages, the bot will see that single message but it won't be stored \
        (it will only be used to generate that single response).

        #{if db_user.opt_out
            'Use <code>/opt_in</code> to make yourself visible to the bot again.'
          else
            'To confirm opt-out, run <code>/really_opt_out_for_real_im_not_kidding</code>'
          end}
      INFOTEXT
    end
  end
end
