# frozen_string_literal: true

class TelegramWebhooksController
  module LocalesHelpers
    # module_function

    # TODO: handle these chat commands:
    # - /locales
    #   prints locales data like this:
    #   Melbourne, Australia / 13:45 / ⛈️ 70F 21.1C
    #   Tokyo, Japan / 12:34 / ☀️ 30F -1C
    # - /locales_add raleigh nc
    #   looks up the most likely place in some api and adds it to this db_chat's locales
    # - /locales_remove raleigh
    #   removes the most likely match
  end
end
