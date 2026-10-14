class JobNote < ApplicationRecord
  include Auditable

  belongs_to :job, touch: true
  belongs_to :user

  validates :body, presence: true, length: { maximum: 5_000 }

  scope :chronological, -> { order(:created_at) }
end
