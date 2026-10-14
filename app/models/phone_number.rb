# US phone numbers are stored as E.164 (+1XXXXXXXXXX) so the same number
# always encrypts to the same ciphertext and stays searchable.
module PhoneNumber
  module_function

  def normalize(raw)
    return nil if raw.blank?

    digits = raw.to_s.gsub(/\D/, "")
    digits = digits.delete_prefix("1") if digits.length == 11
    digits.length == 10 ? "+1#{digits}" : raw.to_s.strip
  end

  def format(e164)
    return "" if e164.blank?
    return e164 unless e164.match?(/\A\+1\d{10}\z/)

    d = e164.delete_prefix("+1")
    "(#{d[0, 3]}) #{d[3, 3]}-#{d[6, 4]}"
  end
end
