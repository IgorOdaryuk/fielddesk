class User < ApplicationRecord
  include Auditable

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :assigned_jobs, class_name: "Job", foreign_key: :technician_id, dependent: :nullify, inverse_of: :technician
  has_many :job_notes, dependent: :restrict_with_error

  enum :role, { admin: 0, dispatcher: 1, technician: 2 }, validate: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 10 }, allow_nil: true
  validates :color, format: { with: /\A#\h{6}\z/ }

  scope :active, -> { where(active: true) }
  scope :technicians, -> { technician.active.order(:name) }

  def staff?
    admin? || dispatcher?
  end

  def first_name
    name.split.first
  end
end
