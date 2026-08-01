// Dropdown handler for Turbo-enabled applications

document.addEventListener('DOMContentLoaded', initializeDropdowns);
document.addEventListener('turbo:load', initializeDropdowns);
document.addEventListener('turbo:render', initializeDropdowns);
document.addEventListener('turbo:frame-render', initializeDropdowns);

// Function to initialize all dropdowns
function initializeDropdowns() {
  if (typeof bootstrap === 'undefined') {
    return;
  }
  
  // Get all dropdown toggles
  const dropdownToggles = document.querySelectorAll('[data-bs-toggle="dropdown"]');
  
  // Initialize each dropdown using Bootstrap's native API without duplicate click listeners
  dropdownToggles.forEach(toggle => {
    let instance = bootstrap.Dropdown.getInstance(toggle);
    if (!instance) {
      new bootstrap.Dropdown(toggle);
    }
  });
} 