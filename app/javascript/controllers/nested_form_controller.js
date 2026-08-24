import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["template", "items"]

  connect() {
    // Add at least two options for question types that require options
    const questionType = document.getElementById('question_question_type')?.value
    const existingOptions = this.visibleOptionItems()
    
    if (['multiple_choice', 'checkboxes', 'dropdown'].includes(questionType) && existingOptions.length === 0) {
      this.add()
      this.add()
    }

    this.updatePlaceholders()
    this.updateOptionIndicators()
  }

  add(event) {
    if (event) event.preventDefault()
    
    // Get the template HTML and replace NEW_RECORD with a unique ID
    const timestamp = new Date().getTime()
    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, timestamp)
    
    // Append the new option to the items container
    this.itemsTarget.insertAdjacentHTML('beforeend', content)
    
    const newOption = this.itemsTarget.lastElementChild
    const textField = newOption.querySelector('input[name*="[text]"]')
    if (textField && !textField.getAttribute('value')) {
      textField.value = ''
    }
    
    // Update placeholders and indicators
    this.updatePlaceholders()
    this.updateOptionIndicators()
  }

  remove(event) {
    event.preventDefault()
    
    const item = event.target.closest('.option-item')
    const allVisible = this.visibleOptionItems()
    
    // Don't allow removing if there are only 2 options left
    if (allVisible.length <= 2) {
      return
    }
    
    // If this is a persisted record, mark it for destruction instead of removing from DOM
    const destroyInput = item.querySelector('input[name*="_destroy"]')
    if (destroyInput) {
      destroyInput.value = "1"
      item.style.display = "none"
    } else {
      // Otherwise just remove it from the DOM
      item.remove()
    }

    this.updatePlaceholders()
  }
  
  visibleOptionItems() {
    return Array.from(this.itemsTarget.querySelectorAll('.option-item')).filter(
      el => el.style.display !== 'none'
    )
  }

  updatePlaceholders() {
    const visibleOptions = this.visibleOptionItems()
    visibleOptions.forEach((optionItem, index) => {
      const textField = optionItem.querySelector('input[name*="[text]"]')
      if (textField) {
        textField.placeholder = `Option ${index + 1}`
      }
    })
  }

  updateOptionIndicators() {
    const questionType = document.getElementById('question_question_type')?.value
    if (!questionType) return
    
    const indicators = document.querySelectorAll('.option-indicator i')
    indicators.forEach(indicator => {
      indicator.className = `bi ${
        questionType === 'multiple_choice' ? 'bi-circle' :
        questionType === 'checkboxes' ? 'bi-square' :
        'bi-chevron-down'
      }`
    })
  }
} 