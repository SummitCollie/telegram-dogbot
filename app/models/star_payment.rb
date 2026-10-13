# frozen_string_literal: true

# A Telegram Stars payment for premium (the first payment of a subscription, or a renewal).
# Not deleted by the data purge or /forget: needed for refunds & payment disputes.
class StarPayment < ApplicationRecord
  belongs_to :user

  scope :not_refunded, -> { where(refunded_at: nil) }

  def refunded?
    refunded_at.present?
  end

  def renewal_canceled?
    renewal_canceled_at.present?
  end
end
