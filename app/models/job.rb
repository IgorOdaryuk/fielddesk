class Job < ApplicationRecord
  include Auditable

  APPLIANCES = [ "Refrigerator", "Washer", "Dryer", "Dishwasher", "Oven", "Range", "Cooktop",
                 "Microwave", "Freezer", "Ice maker", "Wine cooler", "Garbage disposal" ].freeze

  # Who may move a job where. Technicians only drive their own field visit;
  # everything else (booking, rescheduling, canceling) is a dispatcher call.
  TRANSITIONS = {
    "unscheduled" => %w[scheduled canceled],
    "scheduled"   => %w[en_route unscheduled canceled],
    "en_route"    => %w[in_progress scheduled],
    "in_progress" => %w[completed],
    "completed"   => %w[in_progress],
    "canceled"    => %w[unscheduled]
  }.freeze
  TECHNICIAN_STATUSES = %w[en_route in_progress completed].freeze

  belongs_to :customer
  belongs_to :property
  belongs_to :technician, class_name: "User", optional: true
  belongs_to :created_by, class_name: "User", optional: true
  has_many :notes, -> { chronological }, class_name: "JobNote", dependent: :destroy
  has_one :invoice, dependent: :restrict_with_error
  has_many :outbound_messages, dependent: :nullify
  has_many_attached :photos

  enum :status, { unscheduled: 0, scheduled: 1, en_route: 2, in_progress: 3, completed: 4, canceled: 5 }, validate: true
  enum :priority, { low: 0, normal: 1, urgent: 2 }, prefix: true, validate: true

  validates :appliance, :problem, presence: true
  validates :source, inclusion: { in: Customer::SOURCES }, allow_blank: true
  validates :duration_minutes, numericality: { only_integer: true, in: 15..600 }
  validates :scheduled_at, :technician, presence: true, if: -> { scheduled? || en_route? || in_progress? }
  validates :cancel_reason, presence: true, if: :canceled?
  validate :property_belongs_to_customer
  validate :technician_is_a_technician
  validate :technician_is_free, if: -> { technician_id && scheduled_at && !canceled? }
  validate :photos_are_images

  before_save :stamp_field_times
  after_commit :refresh_dispatch_screens
  after_update_commit :notify_customer, if: -> { saved_change_to_status? }

  scope :open, -> { where(status: %i[unscheduled scheduled en_route in_progress]) }
  scope :on_day, ->(date) { where(scheduled_at: date.in_time_zone.all_day) }
  scope :between, ->(range) { where(scheduled_at: range) }
  scope :overlapping, ->(from, to) {
    where("jobs.scheduled_at < ? AND jobs.scheduled_at + make_interval(mins => jobs.duration_minutes) > ?", to, from)
  }
  scope :for_technician, ->(user) { where(technician: user) }
  scope :newest_first, -> { order(created_at: :desc) }
  scope :by_schedule, -> { order(:scheduled_at) }

  def self.search(query)
    return all if query.blank?

    q = "%#{sanitize_sql_like(query.strip)}%"
    left_joins(:customer).where("jobs.number ILIKE :q OR jobs.appliance ILIKE :q OR jobs.brand ILIKE :q OR customers.name ILIKE :q", q: q)
  end

  def allowed_transitions_for(user)
    targets = TRANSITIONS.fetch(status, [])
    return targets if user.staff?
    return [] unless user.technician? && technician_id == user.id

    targets & TECHNICIAN_STATUSES
  end

  def transition_to!(new_status, by:, cancel_reason: nil)
    new_status = new_status.to_s
    unless allowed_transitions_for(by).include?(new_status)
      errors.add(:status, "can't change from #{status.humanize.downcase} to #{new_status.humanize.downcase}")
      raise ActiveRecord::RecordInvalid, self
    end

    update!(status: new_status, cancel_reason: cancel_reason.presence || self.cancel_reason)
  rescue ActiveRecord::RecordInvalid
    restore_attributes(%i[status cancel_reason started_at completed_at])
    raise
  end

  def scheduled_end
    scheduled_at && scheduled_at + duration_minutes.minutes
  end

  def title
    "#{number} · #{[ brand, appliance ].compact_blank.join(' ')}"
  end

  private
    def notify_customer
      case status
      when "en_route" then Messaging.notify(:on_my_way, job: self)
      when "completed" then Messaging.notify(:review_request, job: self, send_at: Company.review_request_delay.from_now)
      end
    end

    def stamp_field_times
      return unless will_save_change_to_status?

      self.started_at = Time.current if in_progress? && started_at.nil?
      self.completed_at = completed? ? (completed_at || Time.current) : nil
    end

    def property_belongs_to_customer
      return if property.nil? || customer.nil?

      errors.add(:property, "must belong to the selected customer") if property.customer_id != customer_id
    end

    def technician_is_free
      clash = Job.where(technician_id: technician_id).where.not(id: id).where.not(status: :canceled)
                 .overlapping(scheduled_at, scheduled_end).first
      return unless clash

      errors.add(:base, "#{technician.first_name} is already booked: #{clash.number} #{clash.scheduled_at.strftime('%-l:%M %P')}–#{clash.scheduled_end.strftime('%-l:%M %P')}")
    end

    # Open dashboards and schedule boards re-render themselves (Turbo 8 morph).
    def refresh_dispatch_screens
      broadcast_refresh_later_to :dispatch
    end

    def technician_is_a_technician
      return if technician.nil?

      errors.add(:technician, "must be an active technician") unless technician.technician? && technician.active?
    end

    def photos_are_images
      photos.each do |photo|
        next if photo.content_type.to_s.start_with?("image/") && photo.byte_size <= 15.megabytes

        errors.add(:photos, "must be images under 15 MB")
        break
      end
    end
end
