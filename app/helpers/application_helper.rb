module ApplicationHelper
  STATUS_STYLES = {
    "unscheduled" => "bg-amber-50 text-amber-700 ring-amber-600/20",
    "scheduled"   => "bg-blue-50 text-blue-700 ring-blue-600/20",
    "en_route"    => "bg-violet-50 text-violet-700 ring-violet-600/20",
    "in_progress" => "bg-orange-50 text-orange-700 ring-orange-600/20",
    "completed"   => "bg-emerald-50 text-emerald-700 ring-emerald-600/20",
    "canceled"    => "bg-slate-100 text-slate-500 ring-slate-500/20"
  }.freeze

  TRANSITION_LABELS = {
    "scheduled" => "Mark scheduled", "unscheduled" => "Unschedule", "en_route" => "On my way",
    "in_progress" => "Start work", "completed" => "Complete job", "canceled" => "Cancel job"
  }.freeze

  def status_badge(status)
    tag.span(status.to_s.humanize,
             class: "inline-flex items-center rounded-md px-2 py-0.5 text-xs font-medium ring-1 ring-inset #{STATUS_STYLES[status.to_s]}")
  end

  def priority_badge(job)
    return unless job.priority_urgent?

    tag.span("Urgent", class: "inline-flex items-center rounded-md bg-red-50 px-2 py-0.5 text-xs font-medium text-red-700 ring-1 ring-inset ring-red-600/20")
  end

  def transition_label(status)
    TRANSITION_LABELS.fetch(status, status.humanize)
  end

  def phone_link(e164)
    return tag.span("—", class: "text-slate-400") if e164.blank?

    link_to PhoneNumber.format(e164), "tel:#{e164}", class: "text-brand-600 hover:underline"
  end

  def job_window(job)
    return "Not scheduled" unless job.scheduled_at

    "#{l(job.scheduled_at, format: '%a %b %-d')} · #{job.scheduled_at.strftime('%-l:%M%P')}–#{job.scheduled_end.strftime('%-l:%M%P')}"
  end

  def tech_dot(user)
    return tag.span("Unassigned", class: "text-slate-400") unless user

    tag.span(class: "inline-flex items-center gap-1.5") do
      tag.span(class: "size-2 rounded-full", style: "background: #{user.color}") + user.name
    end
  end

  def nav_link(label, path, active: current_page?(path))
    link_to label, path, class: [ "nav-link", ("nav-link-active" if active) ]
  end

  SOURCE_LABELS = { "google_ads" => "Google Ads", "lsa" => "Local Services Ads" }.freeze

  def source_label(source)
    return "Unknown" if source.blank?

    SOURCE_LABELS.fetch(source.to_s, source.to_s.humanize)
  end

  def page_nav(pagy)
    pagy.pages > 1 ? pagy.series_nav.html_safe : nil
  end
end
