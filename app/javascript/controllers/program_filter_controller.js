import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "completedRow"]

  connect() {
    this.syncVisibility()
  }
  
  toggleCompleted(event) {
    this.syncVisibility(event.target.checked)
  }

  syncVisibility(forcedState) {
    const checkbox = this.hasToggleTarget ? this.toggleTarget : this.element.querySelector('#show-completed')
    const showCompleted = typeof forcedState === 'boolean'
      ? forcedState
      : checkbox
        ? checkbox.checked
        : true

    const completedRows = this.hasCompletedRowTarget
      ? this.completedRowTargets
      : this.element.querySelectorAll('tr[data-program-status="completed"]')

    completedRows.forEach(row => {
      row.style.display = showCompleted ? '' : 'none'
    })
  }
}
