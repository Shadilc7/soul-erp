// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "custom/dropdown_handler"
import * as bootstrap from "bootstrap"

// Make bootstrap globally available
window.bootstrap = bootstrap;

// Track initialization to prevent duplicate initializations
let pageInitialized = false;

/**
 * Utility function to check if current URL belongs to a section
 */
function isUrlInSection(patterns) {
  const currentPath = window.location.pathname;
  return patterns.some(pattern => currentPath.includes(pattern));
}

/**
 * Initialize submenu states based on current page and saved state
 */
function initializeSubmenuStates() {
  try {
    // Check which section the current page belongs to
    const isTrainingSection = isUrlInSection([
      '/institute_admin/trainers',
      '/institute_admin/training_programs',
      '/institute_admin/attendances'
    ]);
    
    const isAssessmentsSection = isUrlInSection([
      '/institute_admin/questions',
      '/institute_admin/assignments',
      '/institute_admin/responses'
    ]);
    
    const openSubmenuId = localStorage.getItem('openSubmenu');
    
    // Handle Training submenu
    const trainingSubmenu = document.getElementById('trainingSubmenu');
    const trainingToggle = document.querySelector('a[href="#trainingSubmenu"]');
    
    if (trainingSubmenu && trainingToggle) {
      if (isTrainingSection) {
        // Open training submenu for training pages
        trainingSubmenu.classList.add('show');
        trainingToggle.setAttribute('aria-expanded', 'true');
        trainingToggle.classList.add('active-parent');
      } else if (openSubmenuId !== 'trainingSubmenu') {
        // Close unless specifically opened by user
        trainingSubmenu.classList.remove('show');
        trainingToggle.setAttribute('aria-expanded', 'false');
        trainingToggle.classList.remove('active-parent');
      }
    }
    
    // Handle Assessments submenu
    const assessmentsSubmenu = document.getElementById('assessmentsSubmenu');
    const assessmentsToggle = document.querySelector('a[href="#assessmentsSubmenu"]');
    
    if (assessmentsSubmenu && assessmentsToggle) {
      if (isAssessmentsSection) {
        // Open assessments submenu for assessment pages
        assessmentsSubmenu.classList.add('show');
        assessmentsToggle.setAttribute('aria-expanded', 'true');
        assessmentsToggle.classList.add('active-parent');
      } else if (openSubmenuId !== 'assessmentsSubmenu') {
        // Close unless specifically opened by user
        assessmentsSubmenu.classList.remove('show');
        assessmentsToggle.setAttribute('aria-expanded', 'false');
        assessmentsToggle.classList.remove('active-parent');
      }
    }
    
    // User explicitly saved submenu state overrides default behavior
    if (openSubmenuId) {
      const submenu = document.getElementById(openSubmenuId);
      const toggle = document.querySelector(`a[href="#${openSubmenuId}"]`);
      
      if (submenu && toggle) {
        submenu.classList.add('show');
        toggle.setAttribute('aria-expanded', 'true');
        toggle.classList.add('active-parent');
      }
    }
  } catch (error) {
    console.error('Error initializing submenu states:', error);
  }
}

/**
 * Initialize Bootstrap components
 */
function initializeBootstrapComponents() {
  try {
    const bs = typeof window !== 'undefined' ? window.bootstrap : null;
    if (!bs) return;

    // Dropdowns
    const dropdownElementList = document.querySelectorAll('[data-bs-toggle="dropdown"]');
    dropdownElementList.forEach(el => {
      try {
        bs.Dropdown.getOrCreateInstance(el);
      } catch (e) {}
    });
    
    // Tooltips
    const tooltipTriggerList = document.querySelectorAll('[data-bs-toggle="tooltip"]');
    tooltipTriggerList.forEach(el => {
      try {
        bs.Tooltip.getOrCreateInstance(el);
      } catch (e) {}
    });
    
    // Popovers
    const popoverTriggerList = document.querySelectorAll('[data-bs-toggle="popover"]');
    popoverTriggerList.forEach(el => {
      try {
        bs.Popover.getOrCreateInstance(el);
      } catch (e) {}
    });
    
    pageInitialized = true;
  } catch (error) {
    console.error('Error initializing Bootstrap components:', error);
  }
}

/**
 * Clean up lingering Bootstrap modals and backdrops for Turbo
 */
function cleanupModalBackdrops() {
  try {
    const bs = typeof window !== 'undefined' ? window.bootstrap : null;
    document.querySelectorAll('.modal-backdrop').forEach(backdrop => backdrop.remove());
    document.querySelectorAll('.modal.show').forEach(modalEl => {
      try {
        const modalInstance = bs?.Modal?.getInstance(modalEl);
        if (modalInstance) {
          modalInstance.hide();
          modalInstance.dispose();
        }
      } catch (e) {}
      modalEl.classList.remove('show');
      modalEl.style.display = 'none';
      modalEl.setAttribute('aria-hidden', 'true');
    });
    document.body.classList.remove('modal-open');
    document.body.style.removeProperty('overflow');
    document.body.style.removeProperty('padding-right');
  } catch (error) {
    console.error('Error cleaning up modal backdrops:', error);
  }
}

/**
 * Clean up Bootstrap component instances before navigation
 */
function cleanupBootstrapComponents() {
  try {
    const bs = typeof window !== 'undefined' ? window.bootstrap : null;
    cleanupModalBackdrops();

    if (bs) {
      // Clean up tooltips
      const tooltips = document.querySelectorAll('[data-bs-toggle="tooltip"]');
      tooltips.forEach(element => {
        const tooltip = bs.Tooltip?.getInstance(element);
        if (tooltip) tooltip.dispose();
      });
      
      // Clean up popovers
      const popovers = document.querySelectorAll('[data-bs-toggle="popover"]');
      popovers.forEach(element => {
        const popover = bs.Popover?.getInstance(element);
        if (popover) popover.dispose();
      });
      
      // Clean up dropdowns
      const dropdowns = document.querySelectorAll('[data-bs-toggle="dropdown"]');
      dropdowns.forEach(element => {
        const dropdown = bs.Dropdown?.getInstance(element);
        if (dropdown) dropdown.dispose();
      });
    }
  } catch (error) {
    console.error('Error cleaning up Bootstrap components:', error);
  }
}

/**
 * Setup dynamic option fields for question forms
 */
function setupDynamicOptionFields() {
  const addOptionButton = document.getElementById('add-option')
  if (addOptionButton) {
    addOptionButton.addEventListener('click', () => {
      const container = document.getElementById('options-container')
      const newOption = document.createElement('div')
      newOption.className = 'input-group mb-2'
      newOption.innerHTML = `
        <input type="text" name="question[options][]" class="form-control">
        <button type="button" class="btn btn-outline-danger remove-option">
          <i class="bi bi-trash"></i>
        </button>
      `
      container.appendChild(newOption)
    })
  }

  // Handle option removal
  document.addEventListener('click', (e) => {
    if (e.target.closest('.remove-option')) {
      e.target.closest('.input-group').remove()
    }
  })
}

// Initialize components when Turbo loads a page
document.addEventListener('turbo:load', () => {
  cleanupModalBackdrops();
  
  requestAnimationFrame(() => {
    initializeSubmenuStates();
    initializeBootstrapComponents();
    setupDynamicOptionFields();
  });
});

// Reset initialization flag when starting navigation
document.addEventListener('turbo:visit', () => {
  pageInitialized = false;
  cleanupModalBackdrops();
});

document.addEventListener('turbo:before-visit', () => {
  cleanupModalBackdrops();
});

// Clean up lingering modal backdrops before Turbo caches page snapshot
document.addEventListener('turbo:before-cache', () => {
  cleanupModalBackdrops();
});

// Clean up components before navigation
document.addEventListener('turbo:before-render', () => {
  cleanupBootstrapComponents();
});

// Close modal backdrop automatically when clicking links inside modals
document.addEventListener('click', (e) => {
  const link = e.target.closest('.modal a[href]');
  if (link) {
    const modalEl = link.closest('.modal');
    if (modalEl) {
      try {
        const bs = typeof window !== 'undefined' ? window.bootstrap : null;
        const instance = bs?.Modal?.getInstance(modalEl);
        if (instance) {
          instance.hide();
          instance.dispose();
        }
      } catch (err) {}
    }
    cleanupModalBackdrops();
  }
});

// Close modal backdrop automatically when submitting forms inside modals
document.addEventListener('submit', (e) => {
  if (e.target.closest('.modal')) {
    cleanupModalBackdrops();
  }
});

// Immediately hide Bootstrap modal instance when Turbo begins form submission
document.addEventListener('turbo:submit-start', (e) => {
  const modalEl = e.target.closest('.modal');
  if (modalEl) {
    try {
      const bs = typeof window !== 'undefined' ? window.bootstrap : null;
      const instance = bs?.Modal?.getInstance(modalEl);
      if (instance) instance.hide();
    } catch (err) {}
    cleanupModalBackdrops();
  }
});

document.addEventListener('turbo:submit-end', () => {
  cleanupModalBackdrops();
});
