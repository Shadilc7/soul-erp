import { Controller } from "@hotwired/stimulus"
// No Chart.js import here! Use global Chart from CDN

export default class extends Controller {
  static targets = ["participants", "programs", "resources", "ratings"]
  static values = {
    stats: Object
  }

  connect() {
    this.colors = {
      primary: '#0d6efd',
      success: '#198754',
      info: '#0dcaf0',
      warning: '#ffc107'
    }
    this.initializeCharts()
  }

  initializeCharts() {
    if (this.hasParticipantsTarget) {
      this.initParticipantsChart()
    }
    if (this.hasProgramsTarget) {
      this.initProgramsChart()
    }
    if (this.hasResourcesTarget) {
      this.initResourcesChart()
    }
    if (this.hasRatingsTarget) {
      this.initRatingsChart()
    }
  }

  initParticipantsChart() {
    const stats = this.statsValue
    new Chart(this.participantsTarget, {
      type: 'bar',
      data: {
        labels: stats.labels,
        datasets: [{
          label: 'Total Participants',
          data: stats.participants,
          backgroundColor: this.colors.primary
        }, {
          label: 'Active Participants',
          data: stats.active_participants,
          backgroundColor: this.colors.success
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { position: 'bottom' }
        }
      }
    })
  }

  initProgramsChart() {
    const stats = this.statsValue
    new Chart(this.programsTarget, {
      type: 'bar',
      data: {
        labels: stats.labels,
        datasets: [{
          label: 'Total Programs',
          data: stats.programs,
          backgroundColor: this.colors.info
        }, {
          label: 'Active Programs',
          data: stats.active_programs,
          backgroundColor: this.colors.success
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { position: 'bottom' }
        }
      }
    })
  }

  initResourcesChart() {
    const stats = this.statsValue
    const canvas = this.resourcesTarget
    if (!canvas) return
    const ctx = canvas.getContext('2d')

    // Vertical gradients for each dataset
    const gradSections = ctx.createLinearGradient(0, 0, 0, canvas.height)
    gradSections.addColorStop(0, '#60a5fa')
    gradSections.addColorStop(1, '#2563eb')

    const gradAssignments = ctx.createLinearGradient(0, 0, 0, canvas.height)
    gradAssignments.addColorStop(0, '#34d399')
    gradAssignments.addColorStop(1, '#059669')

    new Chart(canvas, {
      type: 'bar',
      data: {
        labels: stats.labels,
        datasets: [{
          label: 'Sections',
          data: stats.sections,
          backgroundColor: gradSections,
          borderRadius: 6,
          barPercentage: 0.6,
          categoryPercentage: 0.6,
          maxBarThickness: 36
        }, {
          label: 'Assignments',
          data: stats.assignments,
          backgroundColor: gradAssignments,
          borderRadius: 6,
          barPercentage: 0.6,
          categoryPercentage: 0.6,
          maxBarThickness: 36
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: 'index', intersect: false },
        plugins: {
          legend: { position: 'bottom', align: 'start', labels: { usePointStyle: true, padding: 12, boxWidth: 10, boxHeight: 6 } },
          tooltip: { padding: 10, backgroundColor: 'rgba(33,37,41,0.95)', titleFont: { size: 13, weight: '600' }, bodyFont: { size: 13 }, cornerRadius: 6 }
        },
        scales: {
          x: { grid: { display: false }, ticks: { maxRotation: 0, autoSkip: true } },
          y: { beginAtZero: true, title: { display: true, text: 'Count' }, ticks: { precision: 0 }, grid: { color: 'rgba(15, 23, 42, 0.04)' } }
        }
      }
    })
  }

  initRatingsChart() {
    const stats = this.statsValue
    new Chart(this.ratingsTarget, {
      type: 'line',
      data: {
        labels: stats.labels,
        datasets: [{
          label: 'Average Rating',
          data: stats.avg_ratings,
          borderColor: this.colors.warning,
          backgroundColor: `${this.colors.warning}33`,
          fill: true,
          tension: 0.4,
          pointRadius: 4,
          pointHoverRadius: 6,
          pointBackgroundColor: this.colors.warning
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { position: 'bottom', labels: { usePointStyle: true, pointStyle: 'circle', padding: 12, boxWidth: 10, boxHeight: 6 } }
        },
        scales: {
          y: {
            min: 0,
            max: 5,
            ticks: {
              stepSize: 1
            }
          }
        }
      }
    })
  }
}