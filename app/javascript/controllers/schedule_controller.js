import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Drag jobs between technician columns and times on the schedule board.
// Drops snap to 15 minutes; the server has the final word on conflicts.
export default class extends Controller {
  static targets = ["column", "job", "message"]
  static values = { date: String, startHour: Number, pxPerHour: Number }

  dragStart(event) {
    const job = event.currentTarget
    this.dragged = job
    this.grabOffset = event.clientY - job.getBoundingClientRect().top
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", job.dataset.jobId)
    requestAnimationFrame(() => job.classList.add("opacity-40"))
  }

  dragEnd(event) {
    event.currentTarget.classList.remove("opacity-40")
    this.columnTargets.forEach((c) => c.classList.remove("bg-brand-50"))
  }

  dragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    this.columnTargets.forEach((c) => c.classList.toggle("bg-brand-50", c === event.currentTarget))
  }

  async drop(event) {
    event.preventDefault()
    const column = event.currentTarget
    const jobId = event.dataTransfer.getData("text/plain")
    if (!jobId) return

    // Jobs dragged from the "waiting" list have no grab offset on the grid.
    const offset = this.dragged?.dataset.onGrid === "true" ? this.grabOffset : 0
    const y = event.clientY - column.getBoundingClientRect().top - offset
    const minutes = Math.max(0, Math.round((y / this.pxPerHourValue) * 4) * 15)
    const hour = this.startHourValue + Math.floor(minutes / 60)
    const time = `${this.dateValue}T${String(hour).padStart(2, "0")}:${String(minutes % 60).padStart(2, "0")}:00`

    const response = await fetch(`/jobs/${jobId}/reschedule`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content
      },
      body: JSON.stringify({ technician_id: column.dataset.technicianId, scheduled_at: time })
    })
    const result = await response.json().catch(() => ({}))
    this.show(result.message || result.error || "Something went wrong.", response.ok)
    if (response.ok) Turbo.visit(window.location.href, { action: "replace" })
  }

  show(text, ok) {
    if (!this.hasMessageTarget) return
    this.messageTarget.textContent = text
    this.messageTarget.className = `mb-4 rounded-lg px-4 py-2.5 text-sm font-medium ring-1 ${ok
      ? "bg-emerald-50 text-emerald-700 ring-emerald-600/20"
      : "bg-red-50 text-red-700 ring-red-600/20"}`
  }
}
