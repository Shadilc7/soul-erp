// Dropdown handler for Turbo-enabled applications

function getBootstrap() {
  if (typeof window !== 'undefined' && window.bootstrap) return window.bootstrap;
  if (typeof bootstrap !== 'undefined') return bootstrap;
  return null;
}

export function initializeDropdowns() {
  const bs = getBootstrap();
  if (!bs || !bs.Dropdown) return;
  
  const dropdownToggles = document.querySelectorAll('[data-bs-toggle="dropdown"]');
  dropdownToggles.forEach(toggle => {
    try {
      bs.Dropdown.getOrCreateInstance(toggle);
    } catch (err) {}
  });
}

document.addEventListener('DOMContentLoaded', initializeDropdowns);
document.addEventListener('turbo:load', initializeDropdowns);
document.addEventListener('turbo:render', initializeDropdowns);
document.addEventListener('turbo:frame-render', initializeDropdowns);
document.addEventListener('turbo:frame-load', initializeDropdowns);