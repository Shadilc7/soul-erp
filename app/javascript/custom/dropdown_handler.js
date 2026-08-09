// Dropdown handler for Turbo-enabled applications

function getBootstrap() {
  return window.bootstrap || (typeof bootstrap !== 'undefined' ? bootstrap : null);
}

export function initializeDropdowns() {
  const bs = getBootstrap();
  if (!bs || !bs.Dropdown) return;
  
  const dropdownToggles = document.querySelectorAll('[data-bs-toggle="dropdown"]');
  dropdownToggles.forEach(toggle => {
    let instance = bs.Dropdown.getInstance(toggle);
    if (!instance) {
      new bs.Dropdown(toggle);
    }
  });
}

document.addEventListener('DOMContentLoaded', initializeDropdowns);
document.addEventListener('turbo:load', initializeDropdowns);
document.addEventListener('turbo:render', initializeDropdowns);
document.addEventListener('turbo:frame-render', initializeDropdowns);

// Global event delegation listener to guarantee dropdown toggling across all Turbo navigations
document.addEventListener('click', function(e) {
  const toggle = e.target.closest('[data-bs-toggle="dropdown"]');
  if (toggle) {
    const bs = getBootstrap();
    if (bs && bs.Dropdown) {
      let instance = bs.Dropdown.getInstance(toggle);
      if (!instance) {
        instance = new bs.Dropdown(toggle);
      }
    }
  }
});