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

// Global event delegation listener to guarantee dropdown toggling across all Turbo navigations
document.addEventListener('click', function(e) {
  const toggle = e.target.closest('[data-bs-toggle="dropdown"]');
  if (toggle) {
    const bs = getBootstrap();
    if (bs && bs.Dropdown) {
      try {
        const instance = bs.Dropdown.getOrCreateInstance(toggle);
        const menu = toggle.nextElementSibling?.classList.contains('dropdown-menu') ? 
                     toggle.nextElementSibling : 
                     toggle.closest('.dropdown')?.querySelector('.dropdown-menu');
        
        if (menu) {
          if (menu.classList.contains('show')) {
            instance.hide();
          } else {
            // Close any other open dropdown menus first
            document.querySelectorAll('.dropdown-menu.show').forEach(openMenu => {
              if (openMenu !== menu) {
                const otherToggle = openMenu.closest('.dropdown')?.querySelector('[data-bs-toggle="dropdown"]');
                if (otherToggle) {
                  const otherInst = bs.Dropdown.getInstance(otherToggle);
                  if (otherInst) otherInst.hide();
                }
              }
            });
            instance.show();
          }
        }
      } catch (err) {
        console.warn('Dropdown toggle error:', err);
      }
    }
  }
});