class LlmsRun < ApplicationRecord
  RUN_TTL = 24.hours
  PAID_TTL = 30.days

  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  validates :content, presence: true
  validates :expires_at, presence: true

  def self.create_run(content)
    create!(
      content: content,
      expires_at: Time.current + RUN_TTL
    )
  end

  def self.find_active(id)
    active.find_by(id: id)
  end

  def self.delete_expired
    expired.delete_all
  end

  def mark_paid!
    update!(
      paid_at: Time.current,
      expires_at: Time.current + PAID_TTL
    )
  end

  def paid?
    paid_at.present?
  end
end
