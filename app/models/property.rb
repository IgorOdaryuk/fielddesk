class Property < ApplicationRecord
  include Auditable

  belongs_to :customer
  has_many :jobs, dependent: :restrict_with_error

  validates :street, :city, :zip, presence: true
  validates :state, presence: true, length: { is: 2 }
  validates :zip, format: { with: /\A\d{5}(-\d{4})?\z/ }

  normalizes :state, with: ->(s) { s.strip.upcase }

  def one_line
    [ [ street, unit ].compact_blank.join(" "), city, "#{state} #{zip}" ].join(", ")
  end

  def maps_url
    "https://www.google.com/maps/search/?api=1&query=#{ERB::Util.url_encode(one_line)}"
  end
end
