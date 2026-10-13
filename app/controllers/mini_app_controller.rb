# frozen_string_literal: true

# Settings Mini App for premium DMs (https://core.telegram.org/bots/webapps), opened from the
# menu button in DMs (see Premium.setup_private_chat). `show` serves the page; it calls the JSON
# endpoints with `Authorization: tma <initData>`, which identifies the user (see MiniAppAuth).
class MiniAppController < ActionController::API
  PAGE = Rails.root.join('data/mini_app/index.html')
  CONTENT_SECURITY_POLICY = "default-src 'self'; script-src 'self' 'unsafe-inline' https://telegram.org; " \
                            "style-src 'self' 'unsafe-inline'; img-src 'self' data:; frame-ancestors *"

  before_action :authenticate!, except: :show
  before_action :require_consent!, only: %i[update_settings reset_settings invoice]

  rescue_from Telegram::Bot::Error do |error|
    TelegramTools.logger.warn("Mini App Telegram request failed: #{error.message}")
    render json: { error: 'Telegram had a problem, try again in a bit' }, status: :bad_gateway
  end

  def show
    response.headers['Content-Security-Policy'] = CONTENT_SECURITY_POLICY
    response.headers['Cache-Control'] = 'no-cache'
    render body: PAGE.read, content_type: 'text/html'
  end

  def state
    render json: state_json
  end

  def consent
    @setting.consent!
    render json: state_json
  end

  def update_settings
    if @setting.update(settings_params)
      render json: state_json
    else
      render json: { error: @setting.errors.full_messages.to_sentence }, status: :unprocessable_content
    end
  end

  def reset_settings
    @setting.reset_persona!
    render json: state_json
  end

  def forget
    forgotten = @user.forget_dms!
    render json: state_json.merge(forgotten:)
  end

  def invoice
    return render json: { error: "You're already premium" }, status: :conflict if @user.premium?

    render json: { link: Premium.invoice_link(@user) }
  end

  # Cancel or re-enable renewal of the subscription
  def renewal
    unless Premium.set_renewal_canceled!(@user, params[:canceled] == true)
      return render json: { error: 'No subscription to change' }, status: :conflict
    end

    render json: state_json
  end

  private

  def authenticate!
    init_data = request.authorization.to_s.delete_prefix('tma ')
    telegram_user = MiniAppAuth.user(init_data)
    return render json: { error: 'Please reopen this from Telegram' }, status: :unauthorized unless telegram_user
    return render json: { error: 'Premium is disabled' }, status: :not_found unless Premium.enabled?

    @user = User.find_or_initialize_by(api_id: telegram_user['id'])
    @user.update!(first_name: telegram_user['first_name'], username: telegram_user['username'])
    @setting = @user.dm_setting!
  end

  def require_consent!
    return if @setting.consented?

    render json: { error: 'Please agree to the terms first' }, status: :forbidden
  end

  # Blank text fields mean "use the default"
  def settings_params
    permitted = params.require(:settings).permit(*DmSetting::EDITABLE_ATTRIBUTES)
    DmSetting::MAX_LENGTHS.each_key do |attr|
      permitted[attr] = permitted[attr].to_s.strip.presence if permitted.key?(attr)
    end
    permitted
  end

  def state_json
    {
      user: { first_name: @user.first_name },
      consented: @setting.consented?,
      premium: premium_json,
      settings: @setting.slice(*DmSetting::EDITABLE_ATTRIBUTES),
      stored_messages: @user.dm_chat&.messages&.count || 0,
      options: {
        presets: DmSetting::PRESETS, max_lengths: DmSetting::MAX_LENGTHS, retention_days: DmSetting::RETENTION_DAYS,
        reply_lengths: DmSetting.reply_lengths.keys, creativity_levels: DmSetting::TEMPERATURES.size
      }
    }
  end

  def premium_json
    payment = @user.current_payment

    {
      active: @user.premium?, owner: @user.owner?, until: @user.premium_until&.iso8601, price: Premium.price,
      recurring: payment&.is_recurring || false, renewal_canceled: payment&.renewal_canceled? || false
    }
  end
end
