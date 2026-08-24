import { Controller } from "@hotwired/stimulus"

/**
 * Sidebar Controller
 * 
 * Handles sidebar behavior including:
 * - Mobile sidebar toggle
 * - Desktop sidebar collapse/expand
 * - Submenu toggling
 * - Scroll position preservation
 */
export default class extends Controller {
  static targets = ["sidebar", "mainContent", "backdrop"]

  connect() {
    // Handle initial mobile state
    this.checkMobileState()
    
    // Listen for window resize
    window.addEventListener('resize', this.checkMobileState.bind(this))
    
    // Add event listeners to sidebar links to preserve scroll position
    this.setupSidebarLinkListeners()
    
    // Check if sidebar should be collapsed (from localStorage)
    this.loadSidebarState()
  }

  /**
   * Toggle sidebar visibility (mobile) or collapse state (desktop)
   */
  toggle() {
    if (!this.hasSidebarTarget) return
    const sidebar = this.sidebarTarget
    const mainContent = this.hasMainContentTarget ? this.mainContentTarget : document.getElementById('main-content')
    const isMobile = window.innerWidth < 992
    
    if (isMobile) {
      // Mobile: show/hide sidebar and ensure full width/expanded state
      sidebar.classList.remove('collapsed')
      if (mainContent) mainContent.classList.remove('collapsed')
      sidebar.classList.toggle('show')
      if (this.hasBackdropTarget) {
        this.backdropTarget.classList.toggle('show')
      }
      document.body.style.overflow = sidebar.classList.contains('show') ? 'hidden' : ''
    } else {
      // Desktop: collapse/expand sidebar
      const isCollapsed = sidebar.classList.toggle('collapsed')
      if (mainContent) {
        mainContent.classList.toggle('collapsed', isCollapsed)
      }
    }
  }
  
  /**
   * Load sidebar state - by default always open on desktop
   */
  loadSidebarState() {
    if (!this.hasSidebarTarget) return
    const sidebar = this.sidebarTarget
    const mainContent = this.hasMainContentTarget ? this.mainContentTarget : document.getElementById('main-content')
    
    if (window.innerWidth >= 992) {
      sidebar.classList.remove('collapsed')
      if (mainContent) mainContent.classList.remove('collapsed')
    } else {
      sidebar.classList.remove('collapsed')
      if (mainContent) mainContent.classList.remove('collapsed')
    }
  }

  /**
   * Hide mobile sidebar
   */
  hide() {
    const sidebar = this.sidebarTarget
    if (sidebar) {
      sidebar.classList.remove('show')
      if (this.hasBackdropTarget) {
        this.backdropTarget.classList.remove('show')
      }
      document.body.style.overflow = ''
    }
  }

  /**
   * Check if viewport is mobile sized and update sidebar state
   */
  checkMobileState() {
    if (window.innerWidth >= 992) {
      this.hide()
      // Restore collapsed state for desktop
      this.loadSidebarState()
    } else {
      if (this.hasSidebarTarget) {
        this.sidebarTarget.classList.remove('collapsed')
      }
      if (this.hasMainContentTarget) {
        this.mainContentTarget.classList.remove('collapsed')
      }
    }
  }
  
  /**
   * Setup scroll position persistence for sidebar
   */
  setupSidebarLinkListeners() {
    const sidebar = document.getElementById('sidebar')
    if (!sidebar) return
    
    // Store the current scroll position in localStorage when clicking a link
    const links = sidebar.querySelectorAll('a.nav-link')
    links.forEach(link => {
      link.addEventListener('click', () => {
        localStorage.setItem('sidebarScrollPosition', sidebar.scrollTop)
      })
    })
    
    // Restore scroll position after page load
    if (localStorage.getItem('sidebarScrollPosition')) {
      const scrollPosition = parseInt(localStorage.getItem('sidebarScrollPosition'))
      sidebar.scrollTop = scrollPosition
    }
  }

  disconnect() {
    window.removeEventListener('resize', this.checkMobileState.bind(this))
  }
} 