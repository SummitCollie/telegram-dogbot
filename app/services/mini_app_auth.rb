# frozen_string_literal: true

# Validates `Telegram.WebApp.initData` sent by the settings Mini App, which proves who's using it.
# https://core.telegram.org/bots/webapps#validating-data-received-via-the-mini-app
class MiniAppAuth
  # initData is signed when the Mini App opens, and people leave it open for a while
  MAX_AGE = 1.day

  class << self
    # The Telegram user (Hash with 'id', 'first_name', 'username', ...) if init_data is genuine & recent, otherwise nil
    def user(init_data, now: Time.current)
      fields = signed_fields(init_data)
      return unless fields

      auth_date = Time.zone.at(fields['auth_date'].to_i)
      return unless auth_date.between?(now - MAX_AGE, now + 1.minute)

      user = JSON.parse(fields['user'].to_s)
      user if user.is_a?(Hash) && user['id'].is_a?(Integer)
    rescue JSON::ParserError
      nil
    end

    # Also used to sign initData in tests
    def signature(fields)
      data_check_string = fields.sort.map { |key, value| "#{key}=#{value}" }.join("\n")
      OpenSSL::HMAC.hexdigest('SHA256', secret_key, data_check_string)
    end

    private

    # Fields of init_data (without its hash), if its hash is right
    def signed_fields(init_data)
      fields = Rack::Utils.parse_query(init_data.to_s)
      hash = fields.delete('hash')
      return unless hash.is_a?(String) && fields.values.all?(String)

      fields if ActiveSupport::SecurityUtils.secure_compare(signature(fields), hash)
    end

    def secret_key
      OpenSSL::HMAC.digest('SHA256', 'WebAppData', Rails.application.credentials.telegram.bot.token)
    end
  end
end
