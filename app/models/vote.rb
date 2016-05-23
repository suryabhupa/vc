class Vote < ActiveRecord::Base
  METRICS = %w(fit team product market)

  belongs_to :user
  belongs_to :company

  validates :company, uniqueness: { scope: [:user, :final] }
  validates :final, inclusion: [true, false]
  validates :overall, numericality: { in: (1..5).to_a - [3] }, if: :final?
  validates :reason, presence: true, if: :final?

  METRICS.each { |metric| validates metric, numericality: { in: 1..5 } }

  scope :final, -> { where(final: true) }
  scope :valid, -> { final.joins(:user).where(users: { active: true }) }
  scope :yes, -> { final.where('overall > ?', 3) }
  scope :no, -> { final.where('overall < ?', 3) }
end
