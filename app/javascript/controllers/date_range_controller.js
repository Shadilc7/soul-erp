import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["filter", "customDates", "startDate", "endDate"]

  connect() {
    console.log("Date range controller connected!")
    console.log("Has filter target:", this.hasFilterTarget)
    console.log("Has customDates target:", this.hasCustomDatesTarget)
    this.toggleCustomDates()
  }

  toggleCustomDates() {
    const filterValue = this.filterTarget.value
    console.log("toggleCustomDates called, filter value:", filterValue)
    
    if (filterValue === 'custom') {
      console.log("Setting display to block")
      if (this.hasCustomDatesTarget) {
        this.customDatesTarget.style.display = 'block'
        console.log("Custom dates display set to:", this.customDatesTarget.style.display)
        // Make date fields required when custom is selected
        if (this.hasStartDateTarget) this.startDateTarget.required = true
        if (this.hasEndDateTarget) this.endDateTarget.required = true
      } else {
        console.log("ERROR: customDates target not found!")
      }
    } else {
      console.log("Setting display to none")
      if (this.hasCustomDatesTarget) {
        this.customDatesTarget.style.display = 'none'
        // Remove required when not custom
        if (this.hasStartDateTarget) this.startDateTarget.required = false
        if (this.hasEndDateTarget) this.endDateTarget.required = false
      }
    }
  }
}
