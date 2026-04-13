import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "titleInput", "startDate", "endDate", "submitButton",
    "typeSelect", "individualView", "sectionView",
    "sectionSelect", "sectionParticipantsView", "sectionParticipantsList",
    "sectionParticipantsCounter", "participantsCounter",
    "questionsCounter",
    "selectAllQuestions",
    "selectAllSections",
    "selectAllRecipients",
    "recipientsSelectAllContainer",
    "sectionParticipantsContainer",
    "error"
  ]

  connect() {
    console.log("Assignment form controller connected")
    
    // Initialize the selectedAssignmentType property
    const individualRadio = this.element.querySelector('input[name="assignment[assignment_type]"][value="individual"]')
    const sectionRadio = this.element.querySelector('input[name="assignment[assignment_type]"][value="section"]')
    
    if (individualRadio && individualRadio.checked) {
      this.selectedAssignmentType = 'individual'
      console.log("Initial assignment type: individual")
      this.showRecipientsSelectAll()
    } else if (sectionRadio && sectionRadio.checked) {
      this.selectedAssignmentType = 'section'
      console.log("Initial assignment type: section")
      this.hideRecipientsSelectAll()
    } else {
      this.selectedAssignmentType = null
      console.log("No assignment type selected initially")
    }
    
    // Check if we're on the assignment creation page or the take assignment page
    const isCreationPage = this.hasQuestionsCounterTarget;
    
    if (isCreationPage) {
      this.updateAllCounters()
      this.validateForm()
      this.validateDates()
      
      // Initialize select all checkboxes
      if (this.hasSelectAllQuestionsTarget) {
        this.updateSelectAllQuestions()
      }
      
      if (this.hasSelectAllSectionsTarget) {
        this.updateSelectAllSections()
      }
      
      if (this.hasSelectAllRecipientsTarget) {
        this.updateSelectAllRecipients()
      }
    }
    
    // Setup rating stars for both pages
    if (typeof this.setupRatingStars === 'function') {
      this.setupRatingStars()
    }
  }

  handleTypeChange(event) {
    console.log("Type changed:", event.target.value)
    
    // Get the selected type from the radio button
    const selectedType = event.target.value
    console.log("Selected assignment type:", selectedType)
    
    // Store the selected type in a class property instead of trying to set the target
    this.selectedAssignmentType = selectedType
    
    // Show/hide appropriate views if they exist
    if (this.hasIndividualViewTarget) {
      console.log("Toggling individual view:", selectedType === 'individual')
      this.individualViewTarget.classList.toggle('d-none', selectedType !== 'individual')
    } else {
      console.log("individualViewTarget not found")
    }
    
    if (this.hasSectionViewTarget) {
      console.log("Toggling section view:", selectedType === 'section')
      this.sectionViewTarget.classList.toggle('d-none', selectedType !== 'section')
    } else {
      console.log("sectionViewTarget not found")
    }

    // Show/hide the recipients select all checkbox
    if (selectedType === 'individual') {
      this.showRecipientsSelectAll()
    } else {
      this.hideRecipientsSelectAll()
    }

    // Clear selections when switching types
    if (selectedType === 'individual') {
      this.clearSectionSelections()
    } else {
      this.clearParticipantSelections()
    }

    // Hide participants view when switching types
    if (selectedType === 'section') {
      if (this.hasSectionParticipantsViewTarget) {
        this.sectionParticipantsViewTarget.classList.add('d-none')
      }
      if (this.hasSectionParticipantsListTarget) {
        this.sectionParticipantsListTarget.innerHTML = ''
      }
    }

    this.validateForm()
  }

  handleSectionChange(event) {
    console.log("Section changed:", event.target.value)
    
    // Skip if the targets don't exist
    if (!this.hasSectionParticipantsViewTarget || !this.hasSectionParticipantsListTarget) return;
    
    const sectionId = event.target.value
    if (!sectionId) {
      this.sectionParticipantsViewTarget.classList.add('d-none')
      this.sectionParticipantsListTarget.innerHTML = ''
      return
    }

    // Fetch participants for the selected section
    fetch(`/institute_admin/sections/${sectionId}/participants`)
      .then(response => response.json())
      .then(participants => {
        this.sectionParticipantsViewTarget.classList.remove('d-none')
        
        // Generate checkboxes for participants, all pre-checked
        const participantsHtml = participants.map(participant => `
          <div class="form-check mb-2">
            <input type="checkbox" 
                   name="assignment[participant_ids][]" 
                   value="${participant.id}" 
                   id="participant_${participant.id}" 
                   class="form-check-input"
                   checked
                   data-action="change->assignment-form#updateSectionParticipantsCounter">
            <label class="form-check-label" for="participant_${participant.id}">
              ${participant.full_name || 'Participant'}
            </label>
          </div>
        `).join('')
        
        this.sectionParticipantsListTarget.innerHTML = participantsHtml
        
        // Only call updateSectionParticipantsCounter if the target exists
        if (this.hasSectionParticipantsCounterTarget) {
          this.updateSectionParticipantsCounter()
        }
      })
  }

  updateSectionParticipantsCounter() {
    // Skip if the targets don't exist
    if (!this.hasSectionParticipantsCounterTarget || !this.hasSectionParticipantsListTarget) return;
    
    const count = this.sectionParticipantsListTarget.querySelectorAll('input:checked').length
    this.sectionParticipantsCounterTarget.textContent = `${count} Selected`
    this.validateForm()
  }

  updateParticipantsCounter() {
    // Skip if the target doesn't exist
    if (!this.hasParticipantsCounterTarget) return;
    
    const count = document.querySelectorAll('input[name="assignment[participant_ids][]"]:checked').length
    this.participantsCounterTarget.textContent = `${count} Selected`
    this.validateForm()
  }

  clearSectionSelections() {
    this.element.querySelectorAll('input[name="assignment[section_ids][]"]').forEach(checkbox => {
      checkbox.checked = false
    })
  }

  clearParticipantSelections() {
    this.element.querySelectorAll('input[name="assignment[participant_ids][]"]').forEach(checkbox => {
      checkbox.checked = false
    })
  }

  validateDates() {
    const startDate = this.element.querySelector('#assignment_start_date')
    const endDate = this.element.querySelector('#assignment_end_date')
    
    if (!startDate || !endDate) return;

    startDate.addEventListener('change', () => {
      const minEnd = startDate.value
      endDate.min = minEnd
      if (endDate.value && endDate.value < minEnd) {
        endDate.value = minEnd
      }
      this.validateForm()
    })

    endDate.addEventListener('change', () => {
      const maxStart = endDate.value
      if (startDate.value && startDate.value > maxStart) {
        startDate.value = maxStart
      }
      this.validateForm()
    })
  }

  updateQuestionsCount() {
    if (!this.hasQuestionsCounterTarget) return;
    
    const count = document.querySelectorAll('input[name="assignment[question_ids][]"]:checked').length
    this.questionsCounterTarget.textContent = `${count} Selected`
    this.validateForm()
  }

  updateAllCounters() {
    if (this.hasQuestionsCounterTarget) this.updateQuestionsCount()
    if (this.hasParticipantsCounterTarget) this.updateParticipantsCounter()
  }

  validateForm() {
    console.log("Validating form")
    
    // Skip validation if we're not on the creation page or if any required target is missing
    if (!this.hasSubmitButtonTarget) return;
    
    let title = ""
    let startDate = ""
    let endDate = ""
    
    if (this.hasTitleInputTarget) {
      title = this.titleInputTarget.value.trim()
    }
    
    if (this.hasStartDateTarget) {
      startDate = this.startDateTarget.value
    }
    
    if (this.hasEndDateTarget) {
      endDate = this.endDateTarget.value
    }
    
    const hasQuestions = this.hasQuestionsSelected()
    const hasAssignees = this.hasAssigneesSelected()

    const isValid = title && startDate && endDate && hasQuestions && hasAssignees
    console.log("Form validation:", { title, startDate, endDate, hasQuestions, hasAssignees, isValid })
    
    this.submitButtonTarget.disabled = !isValid
  }

  hasQuestionsSelected() {
    // If we're not on the creation page, return true
    if (!this.hasQuestionsCounterTarget) return true;
    
    const questions = document.querySelectorAll('input[name="assignment[question_ids][]"]:checked').length
    return questions > 0
  }

  hasAssigneesSelected() {
    console.log("Checking if assignees are selected")
    
    // Use the stored assignment type if available
    let assignmentType = this.selectedAssignmentType
    
    // If not available, get it from the radio buttons
    if (!assignmentType) {
      const individualRadio = this.element.querySelector('input[name="assignment[assignment_type]"][value="individual"]')
      const sectionRadio = this.element.querySelector('input[name="assignment[assignment_type]"][value="section"]')
      
      if (!individualRadio || !sectionRadio) {
        console.log("Radio buttons not found, returning true")
        return true
      }
      
      assignmentType = individualRadio.checked ? 'individual' : 'section'
    }
    
    console.log("Assignment type for validation:", assignmentType)
    
    if (assignmentType === 'section') {
      // Check if any sections are selected
      const selectedSections = document.querySelectorAll('input[name="assignment[section_ids][]"]:checked').length
      console.log("Selected sections:", selectedSections)
      
      if (selectedSections > 0) {
        // If we have sections selected, check if any participants are selected
        const selectedParticipants = document.querySelectorAll('input[name="assignment[participant_ids][]"]:checked').length
        console.log("Selected participants:", selectedParticipants)
        return selectedParticipants > 0
      }
      
      return false
    } else {
      // For individual type, check if any participants are selected
      const selectedParticipants = document.querySelectorAll('input[name="assignment[participant_ids][]"]:checked').length
      console.log("Selected participants (individual):", selectedParticipants)
      return selectedParticipants > 0
    }
  }

  toggleAllQuestions(event) {
    console.log("Toggle all questions:", event.target.checked)
    const checked = event.target.checked
    this.element.querySelectorAll('.question-checkbox').forEach(checkbox => {
      checkbox.checked = checked
    })
    this.updateQuestionsCount()
  }

  updateSelectAllQuestions() {
    // Skip if the target doesn't exist
    if (!this.hasSelectAllQuestionsTarget) return;
    
    const totalQuestions = this.element.querySelectorAll('.question-checkbox').length
    const checkedQuestions = this.element.querySelectorAll('.question-checkbox:checked').length
    this.selectAllQuestionsTarget.checked = totalQuestions === checkedQuestions
  }

  toggleAllSections(event) {
    console.log("Toggle all sections:", event.target.checked)
    const checked = event.target.checked
    this.element.querySelectorAll('.section-checkbox').forEach(checkbox => {
      checkbox.checked = checked
      this.handleSectionSelection({ target: checkbox })
    })
  }

  handleSectionSelection(event) {
    console.log("Section selection changed")
    
    const checkbox = event.target
    const sectionId = checkbox.dataset.sectionId
    
    if (!sectionId) {
      console.error("No section ID found in the checkbox data attribute")
      return
    }
    
    console.log(`Section ${sectionId} selection changed to ${checkbox.checked}`)
    
    // Get the section name from the label
    let sectionName = "Section"
    const label = checkbox.nextElementSibling
    if (label) {
      sectionName = label.textContent.trim()
    }
    
    const participantsContainerId = `section_${sectionId}_participants`
    
    if (checkbox.checked) {
      console.log(`Fetching participants for section ${sectionId}`)

      // Guard: skip if container already exists (prevents duplicates from rapid clicks or toggleAll)
      if (document.getElementById(participantsContainerId)) {
        console.log(`Container for section ${sectionId} already exists, skipping fetch`)
        return
      }
      
      // Show loading indicator
      if (this.hasSectionParticipantsContainerTarget) {
        const loadingHtml = `
          <div id="loading_${sectionId}" class="text-center p-3">
            <div class="spinner-border text-primary" role="status">
              <span class="visually-hidden">Loading...</span>
            </div>
            <p class="mt-2">Loading participants...</p>
          </div>
        `
        this.sectionParticipantsContainerTarget.insertAdjacentHTML('beforeend', loadingHtml)
      }
      
      fetch(`/institute_admin/sections/${sectionId}/participants`)
        .then(response => {
          if (!response.ok) {
            throw new Error(`HTTP error! Status: ${response.status}`)
          }
          return response.json()
        })
        .then(participants => {
          console.log(`Received ${participants.length} participants for section ${sectionId}:`, participants)
          
          // Remove loading indicator if it exists
          const loadingElement = document.getElementById(`loading_${sectionId}`)
          if (loadingElement) {
            loadingElement.remove()
          }
          
          if (this.hasSectionParticipantsContainerTarget) {
            // Guard: skip if container was already inserted by a concurrent fetch
            if (document.getElementById(participantsContainerId)) {
              console.log(`Container for section ${sectionId} already exists after fetch, skipping insert`)
              return
            }

            if (participants.length === 0) {
              const emptyHtml = `
                <div id="section_${sectionId}_participants" class="card border mb-3">
                  <div class="card-header bg-light py-2">
                    <h6 class="mb-0 section-name">${sectionName}</h6>
                  </div>
                  <div class="card-body">
                    <div class="alert alert-info mb-0">
                      <i class="bi bi-info-circle me-2"></i>
                      No participants found in this section.
                    </div>
                  </div>
                </div>
              `
              this.sectionParticipantsContainerTarget.insertAdjacentHTML('beforeend', emptyHtml)
            } else {
              const containerHtml = this.createParticipantsContainer(sectionId, participants, sectionName)
              this.sectionParticipantsContainerTarget.insertAdjacentHTML('beforeend', containerHtml)
            }
            
            this.validateForm()
          } else {
            console.error("sectionParticipantsContainerTarget not found")
          }
        })
        .catch(error => {
          console.error("Error fetching participants:", error)
          
          // Remove loading indicator and show error
          const loadingElement = document.getElementById(`loading_${sectionId}`)
          if (loadingElement) {
            loadingElement.remove()
          }
          
          if (this.hasSectionParticipantsContainerTarget) {
            const errorHtml = `
              <div id="error_${sectionId}" class="alert alert-danger">
                <i class="bi bi-exclamation-triangle-fill me-2"></i>
                Error loading participants: ${error.message}
              </div>
            `
            this.sectionParticipantsContainerTarget.insertAdjacentHTML('beforeend', errorHtml)
          }
        })
    } else {
      console.log(`Removing participants container for section ${sectionId}`)
      const container = document.getElementById(participantsContainerId)
      if (container) {
        container.remove()
      } else {
        console.warn(`Container for section ${sectionId} not found`)
      }
      
      // Also remove any error messages
      const errorElement = document.getElementById(`error_${sectionId}`)
      if (errorElement) {
        errorElement.remove()
      }
      
      this.validateForm()
    }
    
    this.updateSelectAllSections()
  }

  createParticipantsContainer(sectionId, participants, sectionName) {
    console.log(`Creating participants container for section ${sectionId} with ${participants.length} participants`)
    console.log("Participants data:", participants)
    
    if (!participants || !Array.isArray(participants) || participants.length === 0) {
      return `
        <div id="section_${sectionId}_participants" class="card border mb-3">
          <div class="card-header bg-light py-2">
            <h6 class="mb-0 section-name">${sectionName || 'Section'}</h6>
          </div>
          <div class="card-body">
            <div class="alert alert-info mb-0">
              <i class="bi bi-info-circle me-2"></i>
              No participants found in this section.
            </div>
          </div>
        </div>
      `
    }
    
    const participantsHtml = participants.map(participant => {
      // Safely get participant name, with fallback
      let participantName = "Participant"
      
      if (participant.full_name) {
        participantName = participant.full_name
      } else if (participant.user && participant.user.full_name) {
        participantName = participant.user.full_name
      } else if (participant.name) {
        participantName = participant.name
      } else {
        participantName = `Participant ${participant.id}`
      }
      
      console.log(`Participant ${participant.id} name:`, participantName)
      
      return `
        <div class="form-check">
          <input type="checkbox" 
                 name="assignment[participant_ids][]" 
                 value="${participant.id}" 
                 id="participant_${participant.id}" 
                 class="form-check-input section-${sectionId}-participant"
                 checked
                 data-action="change->assignment-form#updateCounter change->assignment-form#updateSectionSelectAll"
                 data-section-id="${sectionId}">
          <label class="form-check-label d-flex align-items-center gap-2" for="participant_${participant.id}">
            ${participantName}
            ${participant.participant_type ? `<span class="badge bg-secondary" style="font-size:0.7em;">${participant.participant_type.charAt(0).toUpperCase() + participant.participant_type.slice(1)}</span>` : ''}
          </label>
        </div>
      `
    }).join('')

    return `
      <div id="section_${sectionId}_participants" class="card border mb-3">
        <div class="card-header bg-light d-flex justify-content-between align-items-center py-2">
          <div>
            <h6 class="mb-0 section-name">${sectionName || 'Section'}</h6>
          </div>
          <div class="d-flex align-items-center gap-2">
            <div class="form-check mb-0">
              <input type="checkbox" 
                     id="select_all_participants_${sectionId}" 
                     class="form-check-input"
                     checked
                     data-action="change->assignment-form#toggleSectionParticipants"
                     data-section-id="${sectionId}">
              <label class="form-check-label small" for="select_all_participants_${sectionId}">
                Select All
              </label>
            </div>
            <span class="badge bg-secondary">
              ${participants.length} participants
            </span>
          </div>
        </div>
        <div class="card-body">
          ${participantsHtml}
        </div>
      </div>
    `
  }

  updateSelectAllSections() {
    // Skip if the target doesn't exist
    if (!this.hasSelectAllSectionsTarget) return;
    
    const totalSections = this.element.querySelectorAll('.section-checkbox').length
    const checkedSections = this.element.querySelectorAll('.section-checkbox:checked').length
    this.selectAllSectionsTarget.checked = totalSections === checkedSections
  }

  toggleSectionParticipants(event) {
    console.log("Toggle section participants")
    const checkbox = event.target
    const sectionId = checkbox.dataset.sectionId
    const checked = checkbox.checked
    
    this.element.querySelectorAll(`.section-${sectionId}-participant`).forEach(participantCheckbox => {
      participantCheckbox.checked = checked
    })
    
    // Only call updateParticipantsCounter if it exists and we have the target
    if (this.hasParticipantsCounterTarget) {
      this.updateParticipantsCounter()
    }
    
    this.validateForm()
  }

  updateSectionSelectAll(event) {
    const checkbox = event.target
    const sectionId = checkbox.dataset.sectionId
    const selectAllCheckbox = document.getElementById(`select_all_participants_${sectionId}`)
    
    if (!selectAllCheckbox) return;
    
    const totalParticipants = this.element.querySelectorAll(`.section-${sectionId}-participant`).length
    const checkedParticipants = this.element.querySelectorAll(`.section-${sectionId}-participant:checked`).length
    
    selectAllCheckbox.checked = totalParticipants === checkedParticipants
    
    this.validateForm()
  }

  // This is the method that's called from the view for individual question checkboxes
  updateCounter(event) {
    console.log("updateCounter called for", event.target.className)
    const checkbox = event.target
    
    // Determine which counter to update based on the checkbox class
    if (checkbox.classList.contains('question-checkbox')) {
      this.updateQuestionsCount()
    } else if (checkbox.name === 'assignment[participant_ids][]') {
      // For participant checkboxes
      if (this.hasParticipantsCounterTarget) {
        this.updateParticipantsCounter()
      }
    }
    
    this.validateForm()
  }

  setupRatingStars() {
    console.log("Setting up rating stars");
    
    // Find all star rating containers
    const ratingContainers = document.querySelectorAll('.star-rating');
    console.log(`Found ${ratingContainers.length} rating containers`);
    
    if (!ratingContainers.length) return;
    
    ratingContainers.forEach(container => {
      const inputs = container.querySelectorAll('input[type="radio"]');
      const labels = container.querySelectorAll('label');
      
      if (!inputs.length || !labels.length) return;
      
      const questionId = inputs[0]?.dataset.questionId;
      const valueDisplay = document.getElementById(`rating_value_${questionId}`);
      
      console.log(`Setting up rating for question ${questionId} with ${inputs.length} inputs and ${labels.length} labels`);
      
      // Add click event to each label
      labels.forEach(label => {
        const starIcon = label.querySelector('i');
        
        // Replace with empty star initially
        if (starIcon) {
          starIcon.classList.remove('bi-star-fill');
          starIcon.classList.add('bi-star');
        }
        
        label.addEventListener('click', (event) => {
          event.preventDefault();
          console.log(`Star clicked: ${label.getAttribute('for')}`);
          
          const input = document.getElementById(label.getAttribute('for'));
          if (input) {
            input.checked = true;
            
            // Get the star value from the input ID
            const starValue = parseInt(input.value);
            console.log(`Selected star value: ${starValue}`);
            
            // Update all stars
            labels.forEach(l => {
              const icon = l.querySelector('i');
              const starNum = parseInt(l.getAttribute('for').split('_')[0].replace('star', ''));
              
              if (starNum <= starValue) {
                icon.classList.remove('bi-star');
                icon.classList.add('bi-star-fill');
                icon.style.color = '#FFD700';
              } else {
                icon.classList.remove('bi-star-fill');
                icon.classList.add('bi-star');
                icon.style.color = '#ddd';
              }
            });
            
            // Only call validateField if the method exists
            if (this.validateField) {
              this.validateField({ target: input });
            }
            
            // Update the rating value display
            if (valueDisplay) {
              valueDisplay.textContent = `${starValue} ${starValue === 1 ? 'star' : 'stars'} selected`;
            }
          }
        });
      });
      
      // Add hover effects to the container
      container.addEventListener('mouseover', (event) => {
        if (event.target.tagName === 'I' || event.target.tagName === 'LABEL') {
          const label = event.target.tagName === 'I' ? event.target.parentNode : event.target;
          const value = parseInt(label.getAttribute('for').split('_')[0].replace('star', ''));
          
          // Update all stars on hover
          labels.forEach(l => {
            const icon = l.querySelector('i');
            const starNum = parseInt(l.getAttribute('for').split('_')[0].replace('star', ''));
            
            if (starNum <= value) {
              icon.classList.remove('bi-star');
              icon.classList.add('bi-star-fill');
              icon.style.color = '#FFD700';
            } else {
              icon.classList.remove('bi-star-fill');
              icon.classList.add('bi-star');
              icon.style.color = '#ddd';
            }
          });
        }
      });
      
      // Remove hover effect when leaving the container
      container.addEventListener('mouseleave', () => {
        // Reset to selected state
        const selectedInput = Array.from(inputs).find(input => input.checked);
        const selectedValue = selectedInput ? parseInt(selectedInput.value) : 0;
        
        labels.forEach(l => {
          const icon = l.querySelector('i');
          const starNum = parseInt(l.getAttribute('for').split('_')[0].replace('star', ''));
          
          if (starNum <= selectedValue) {
            icon.classList.remove('bi-star');
            icon.classList.add('bi-star-fill');
            icon.style.color = '#FFD700';
          } else {
            icon.classList.remove('bi-star-fill');
            icon.classList.add('bi-star');
            icon.style.color = '#ddd';
          }
        });
      });
    });
  }

  toggleAllParticipants(event) {
    console.log("Toggle all participants:", event.target.checked)
    const checked = event.target.checked
    this.element.querySelectorAll('.participant-checkbox').forEach(checkbox => {
      checkbox.checked = checked
    })
    this.updateParticipantsCounter()
    
    // Keep both select all checkboxes in sync
    if (this.hasSelectAllRecipientsTarget && event.target !== this.selectAllRecipientsTarget) {
      this.selectAllRecipientsTarget.checked = checked
    }
  }

  updateSelectAllRecipients() {
    // Skip if the target doesn't exist
    if (!this.hasSelectAllRecipientsTarget) return;
    
    const totalParticipants = this.element.querySelectorAll('.participant-checkbox').length
    const checkedParticipants = this.element.querySelectorAll('.participant-checkbox:checked').length
    this.selectAllRecipientsTarget.checked = totalParticipants === checkedParticipants && totalParticipants > 0
  }

  showRecipientsSelectAll() {
    if (this.hasRecipientsSelectAllContainerTarget) {
      this.recipientsSelectAllContainerTarget.classList.remove('d-none')
    }
  }

  hideRecipientsSelectAll() {
    if (this.hasRecipientsSelectAllContainerTarget) {
      this.recipientsSelectAllContainerTarget.classList.add('d-none')
    }
  }
} 