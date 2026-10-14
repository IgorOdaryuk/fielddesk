# Form object behind the public booking page.
class Booking
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :phone, :string
  attribute :email, :string
  attribute :street, :string
  attribute :unit, :string
  attribute :city, :string
  attribute :state, :string, default: "FL"
  attribute :zip, :string
  attribute :appliance, :string
  attribute :brand, :string
  attribute :problem, :string
  attribute :slot, :string
  attribute :website, :string # honeypot: real people leave it empty

  validates :name, :phone, :street, :city, :state, :zip, :appliance, :problem, :slot, presence: true
  validates :appliance, inclusion: { in: Job::APPLIANCES }, allow_blank: true
  validates :zip, format: { with: /\A\d{5}\z/ }, allow_blank: true
  validate :phone_is_us_number

  attr_reader :job

  def spam? = website.present?

  def save(slots: BookingSlots.new)
    return false unless valid?

    chosen = slots.find(slot)
    unless chosen
      errors.add(:slot, "was just taken. Please pick another time.")
      return false
    end

    ActiveRecord::Base.transaction do
      customer = Customer.find_by(phone: PhoneNumber.normalize(phone)) ||
                 Customer.create!(name: name, phone: phone, email: email.presence, source: "website")
      property = customer.properties.find_by(street: street.strip, zip: zip) ||
                 customer.properties.create!(street: street, unit: unit, city: city, state: state, zip: zip)
      @job = Job.create!(customer: customer, property: property, appliance: appliance, brand: brand.presence, problem: problem,
                         source: "website", status: :scheduled, technician: chosen.technician, scheduled_at: chosen.starts_at,
                         duration_minutes: BookingSlots::WINDOW_MINUTES)
    end
    Messaging.notify(:booking_confirmation, job: @job)
    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.record.errors.full_messages.to_sentence)
    false
  end

  private
    def phone_is_us_number
      return if phone.blank?

      errors.add(:phone, "must be a 10-digit US number") unless PhoneNumber.normalize(phone).to_s.match?(/\A\+1\d{10}\z/)
    end
end
