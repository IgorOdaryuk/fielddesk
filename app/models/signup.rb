# Form object: creates the account, its first admin and (optionally) sample data.
class Signup
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :company_name, :string
  attribute :name, :string
  attribute :email_address, :string
  attribute :password, :string
  attribute :sample_data, :boolean, default: true

  validates :company_name, :name, :email_address, presence: true
  validates :password, length: { minimum: 10 }

  def self.open?
    Demo.enabled? || ENV["ALLOW_SIGNUPS"].present?
  end

  def sample_data? = sample_data

  # Returns the new admin user, or nil with errors set.
  def save
    return unless valid?

    account = Account.new(name: company_name, sandbox: Demo.enabled?, sample_data_loading: sample_data?, **Account.defaults)
    user = nil
    ActiveRecord::Base.transaction do
      account.save!
      ActsAsTenant.with_tenant(account) do
        user = User.create!(name: name, email_address: email_address, password: password, role: :admin)
      end
    end
    LoadSampleDataJob.perform_later(account, user) if sample_data?
    user
  rescue ActiveRecord::RecordInvalid => e
    e.record.errors.each { |error| errors.add(error.attribute == :name && e.record.is_a?(Account) ? :company_name : error.attribute, error.message) }
    nil
  end
end
