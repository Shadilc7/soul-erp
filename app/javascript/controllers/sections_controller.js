import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "instituteSelect", "sectionSelect" ]

  connect() {
    // If institute already selected (e.g. validation failure re-render), load its sections
    const instituteId = this.instituteSelectTarget.value
    if (instituteId) {
      const preselectedSectionId = this.sectionSelectTarget.dataset.preselectedSectionId
      this._fetchAndPopulate(instituteId, preselectedSectionId)
    } else {
      this.updateSections([])
    }
  }

  fetchSections() {
    const instituteId = this.instituteSelectTarget.value
    if (!instituteId) {
      this.updateSections([])
      return
    }

    this._fetchAndPopulate(instituteId, null)
  }

  _fetchAndPopulate(instituteId, preselectedSectionId) {
    fetch(`/sections/fetch?institute_id=${instituteId}`)
      .then(response => response.json())
      .then(sections => {
        this.updateSections(sections, preselectedSectionId)
      })
      .catch(error => {
        console.error("Error fetching sections:", error)
        this.updateSections([])
      })
  }

  updateSections(sections, preselectedSectionId = null) {
    const options = [
      `<option value="">Select Section</option>`
    ]

    sections.forEach(section => {
      const selected = preselectedSectionId && String(section.id) === String(preselectedSectionId) ? ' selected' : ''
      options.push(`<option value="${section.id}"${selected}>${section.name}</option>`)
    })

    this.sectionSelectTarget.innerHTML = options.join('')
  }
}
