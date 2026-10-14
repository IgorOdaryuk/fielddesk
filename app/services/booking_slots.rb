# Two-hour arrival windows customers can book online. A window is open when at
# least one technician has nothing overlapping it; the job goes to whoever is
# least busy that day.
class BookingSlots
  WINDOW_STARTS = [ 8, 10, 12, 14, 16 ].freeze
  WINDOW_MINUTES = 120
  LEAD_TIME = 2.hours # no booking a window that starts in the next two hours

  Slot = Data.define(:starts_at, :ends_at, :technician) do
    def available? = !technician.nil?
    def key = starts_at.iso8601
    def label = "#{starts_at.strftime('%-l%P')}–#{ends_at.strftime('%-l%P')}"
  end

  def initialize(days: 6, now: Time.current)
    @now = now
    @dates = (now.to_date..(now.to_date + days)).to_a
    @technicians = User.technicians.to_a
    range = @dates.first.beginning_of_day..@dates.last.end_of_day
    @jobs = Job.where.not(status: :canceled).where.not(technician_id: nil).between(range).to_a
  end

  # [[date, [Slot, ...]], ...], skipping days with no windows left.
  def by_day
    @dates.filter_map do |date|
      slots = WINDOW_STARTS.filter_map do |hour|
        starts_at = Time.zone.local(date.year, date.month, date.day, hour)
        next if starts_at < @now + LEAD_TIME

        ends_at = starts_at + WINDOW_MINUTES.minutes
        Slot.new(starts_at:, ends_at:, technician: free_technician(starts_at, ends_at))
      end
      [ date, slots ] if slots.any?
    end
  end

  def find(key)
    by_day.flat_map(&:last).find { |slot| slot.key == key && slot.available? }
  end

  private
    def free_technician(from, to)
      free = @technicians.reject { |tech| busy?(tech, from, to) }
      free.min_by { |tech| [ jobs_on(tech, from.to_date), tech.id ] }
    end

    def busy?(tech, from, to)
      @jobs.any? { |job| job.technician_id == tech.id && job.scheduled_at < to && job.scheduled_end > from }
    end

    def jobs_on(tech, date)
      @jobs.count { |job| job.technician_id == tech.id && job.scheduled_at.to_date == date }
    end
end
