import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["questionItem", "bundleDropZone", "questionSearch", "bundleCountBadge", "toastContainer", "questionPoolContainer"]
  static values = {
    categoryId: Number
  }

  connect() {
    this.csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    this.draggedCard = null
    this.draggedBundleItem = null
    this.initSortable()
  }

  initSortable() {
    if (typeof Sortable === "undefined") return

    // 1. Question Pool Sortable for Touch & Mobile
    const poolContainer = this.element.querySelector("#question-pool-container")
    if (poolContainer && !poolContainer._sortable) {
      poolContainer._sortable = Sortable.create(poolContainer, {
        group: {
          name: "question_pool",
          pull: "clone",
          put: false
        },
        animation: 150,
        sort: true,
        handle: ".drag-handle",
        onEnd: async (evt) => {
          this.updatePoolSerialNumbers()
          await this.saveQuestionOrder()

          const targetBundle = evt.to.closest('[data-bundle-id]')
          if (targetBundle && evt.to !== poolContainer) {
            const questionId = evt.item.dataset.questionId
            const bundleId = targetBundle.dataset.bundleId
            const bundleName = targetBundle.dataset.bundleName || ""
            if (evt.item.parentNode) evt.item.parentNode.removeChild(evt.item)
            if (questionId && bundleId) {
              await this.assignQuestionToBundle(questionId, bundleId, bundleName, targetBundle)
            }
          }
        }
      })
    }

    // 2. Bundle Items Sortable for touch re-ordering & drop
    const bundleContainers = this.element.querySelectorAll(".bundle-items-container")
    bundleContainers.forEach(container => {
      this.initBundleContainerSortable(container)
    })
  }

  initBundleContainerSortable(container) {
    if (typeof Sortable === "undefined" || !container || container._sortable) return

    container._sortable = Sortable.create(container, {
      group: {
        name: "question_pool",
        pull: false,
        put: true
      },
      animation: 150,
      handle: ".drag-handle",
      onAdd: async (evt) => {
        const itemEl = evt.item
        const questionId = itemEl.dataset.questionId
        const bundleId = container.dataset.bundleId
        const bundleCard = container.closest('[data-bundle-id]')
        const bundleName = bundleCard?.dataset.bundleName || ""

        if (itemEl.parentNode) itemEl.parentNode.removeChild(itemEl)

        if (questionId && bundleId) {
          await this.assignQuestionToBundle(questionId, bundleId, bundleName, container)
        }
      },
      onUpdate: async (evt) => {
        const bundleId = container.dataset.bundleId
        this.updateBundleSerialNumbers(container)
        await this.saveBundleQuestionsOrder(bundleId, container)
      }
    })
  }

  switchMobileTab(event) {
    const targetTab = event.currentTarget.dataset.tabTarget
    const poolCol = this.element.querySelector("#question-pool-column")
    const bundlesCol = this.element.querySelector("#bundles-column")
    const tabBtns = this.element.querySelectorAll("[data-tab-target]")

    tabBtns.forEach(btn => {
      if (btn.dataset.tabTarget === targetTab) {
        btn.classList.add("active", "btn-primary")
        btn.classList.remove("btn-outline-primary")
      } else {
        btn.classList.remove("active", "btn-primary")
        btn.classList.add("btn-outline-primary")
      }
    })

    if (targetTab === "pool") {
      poolCol?.classList.remove("d-none-mobile")
      bundlesCol?.classList.add("d-none-mobile")
    } else {
      poolCol?.classList.add("d-none-mobile")
      bundlesCol?.classList.remove("d-none-mobile")
    }
  }

  // --- Search & Filter ---
  filterQuestions(event) {
    const query = event.target.value.toLowerCase().trim()
    this.questionItemTargets.forEach(card => {
      const text = card.textContent.toLowerCase()
      if (text.includes(query)) {
        card.style.display = ""
      } else {
        card.style.display = "none"
      }
    })
  }

  // --- Question Pool Drag and Drop Re-ordering ---
  poolDragOver(event) {
    event.preventDefault()
    if (!this.draggedCard) return

    const container = event.currentTarget
    const afterElement = this.getDragAfterElement(container, event.clientY)
    if (afterElement == null) {
      container.appendChild(this.draggedCard)
    } else {
      container.insertBefore(this.draggedCard, afterElement)
    }
  }

  async poolDrop(event) {
    event.preventDefault()
    if (this.draggedCard) {
      this.updatePoolSerialNumbers()
      await this.saveQuestionOrder()
      this.draggedCard = null
    }
  }

  getDragAfterElement(container, y) {
    const draggableElements = [...container.querySelectorAll('[data-bundle-builder-target="questionItem"]:not(.dragging)')]

    return draggableElements.reduce((closest, child) => {
      const box = child.getBoundingClientRect()
      const offset = y - box.top - box.height / 2
      if (offset < 0 && offset > closest.offset) {
        return { offset: offset, element: child }
      } else {
        return closest
      }
    }, { offset: Number.NEGATIVE_INFINITY }).element
  }

  // --- Question Pool Re-order Handlers ---
  async moveUp(event) {
    event.preventDefault()
    event.stopPropagation()
    const card = event.currentTarget.closest('[data-bundle-builder-target="questionItem"]')
    if (!card) return
    const allCards = Array.from(this.questionItemTargets)
    const index = allCards.indexOf(card)
    if (index > 0) {
      const prevCard = allCards[index - 1]
      card.parentNode.insertBefore(card, prevCard)
      this.updatePoolSerialNumbers()
      await this.saveQuestionOrder()
    }
  }

  async moveDown(event) {
    event.preventDefault()
    event.stopPropagation()
    const card = event.currentTarget.closest('[data-bundle-builder-target="questionItem"]')
    if (!card) return
    const allCards = Array.from(this.questionItemTargets)
    const index = allCards.indexOf(card)
    if (index < allCards.length - 1) {
      const nextCard = allCards[index + 1]
      card.parentNode.insertBefore(nextCard, card)
      this.updatePoolSerialNumbers()
      await this.saveQuestionOrder()
    }
  }

  updatePoolSerialNumbers() {
    this.questionItemTargets.forEach((card, index) => {
      const serialBadge = card.querySelector(".pool-item-serial")
      if (serialBadge) serialBadge.textContent = `#${index + 1}`
    })
  }

  async saveQuestionOrder() {
    const questionIds = Array.from(this.questionItemTargets).map(card => card.dataset.questionId)
    try {
      const response = await fetch(`/admin/question_categories/${this.categoryIdValue}/questions/reorder`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({ question_ids: questionIds })
      })
      const data = await response.json()
      if (response.ok && data.status === "success") {
        this.showToast("Questions reordered successfully", "success")
      }
    } catch (err) {
      console.error(err)
    }
  }

  // --- Bundle Item Drag and Drop Re-ordering ---
  bundleItemDragStart(event) {
    this.draggedBundleItem = event.currentTarget
    this.draggedBundleItem.classList.add("dragging", "opacity-50")
    event.stopPropagation()
  }

  bundleItemDragEnd(event) {
    if (this.draggedBundleItem) {
      this.draggedBundleItem.classList.remove("dragging", "opacity-50")
      this.draggedBundleItem = null
    }
  }

  bundleItemDragOver(event) {
    event.preventDefault()
    event.stopPropagation()
    if (!this.draggedBundleItem) return

    const container = event.currentTarget
    const afterElement = this.getBundleDragAfterElement(container, event.clientY)
    if (afterElement == null) {
      container.appendChild(this.draggedBundleItem)
    } else {
      container.insertBefore(this.draggedBundleItem, afterElement)
    }
  }

  async bundleItemDrop(event) {
    event.preventDefault()
    event.stopPropagation()
    await this.drop(event)
  }

  getBundleDragAfterElement(container, y) {
    const draggableElements = [...container.querySelectorAll('.bundle-question-item:not(.dragging)')]

    return draggableElements.reduce((closest, child) => {
      const box = child.getBoundingClientRect()
      const offset = y - box.top - box.height / 2
      if (offset < 0 && offset > closest.offset) {
        return { offset: offset, element: child }
      } else {
        return closest
      }
    }, { offset: Number.NEGATIVE_INFINITY }).element
  }

  // --- Bundle Questions Reordering via Buttons ---
  async moveBundleItemUp(event) {
    event.stopPropagation()
    const btn = event.currentTarget
    const itemCard = btn.closest(".bundle-question-item")
    if (!itemCard) return
    const prev = itemCard.previousElementSibling
    if (prev && prev.classList.contains("bundle-question-item")) {
      const container = itemCard.parentNode
      container.insertBefore(itemCard, prev)
      this.updateBundleSerialNumbers(container)
      const bundleId = btn.dataset.bundleId || container.dataset.bundleId
      await this.saveBundleQuestionsOrder(bundleId, container)
    }
  }

  async moveBundleItemDown(event) {
    event.stopPropagation()
    const btn = event.currentTarget
    const itemCard = btn.closest(".bundle-question-item")
    if (!itemCard) return
    const next = itemCard.nextElementSibling
    if (next && next.classList.contains("bundle-question-item")) {
      const container = itemCard.parentNode
      container.insertBefore(next, itemCard)
      this.updateBundleSerialNumbers(container)
      const bundleId = btn.dataset.bundleId || container.dataset.bundleId
      await this.saveBundleQuestionsOrder(bundleId, container)
    }
  }

  updateBundleSerialNumbers(container) {
    const items = container.querySelectorAll(".bundle-question-item")
    items.forEach((item, index) => {
      const badge = item.querySelector(".bundle-item-serial")
      if (badge) badge.textContent = `#${index + 1}`
    })
  }

  async saveBundleQuestionsOrder(bundleId, container) {
    const items = container.querySelectorAll(".bundle-question-item")
    const questionIds = Array.from(items).map(item => item.dataset.questionId)

    try {
      const response = await fetch(`/admin/question_categories/${this.categoryIdValue}/bundles/${bundleId}/reorder_questions`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({ question_ids: questionIds })
      })
      const data = await response.json()
      if (response.ok && data.status === "success") {
        this.showToast("Bundle questions reordered successfully", "success")
      }
    } catch (err) {
      console.error(err)
    }
  }

  // --- Drag and Drop Handlers for Bundle Assignment ---
  dragStart(event) {
    this.draggedCard = event.currentTarget
    this.draggedCard.classList.add("dragging", "opacity-50")
    const questionId = event.currentTarget.dataset.questionId
    const questionTitle = event.currentTarget.dataset.questionTitle
    event.dataTransfer.setData("text/plain", questionId)
    event.dataTransfer.setData("application/json", JSON.stringify({ id: questionId, title: questionTitle }))
    event.dataTransfer.effectAllowed = "copyMove"
  }

  dragEnd(event) {
    if (this.draggedCard) {
      this.draggedCard.classList.remove("dragging", "opacity-50")
      this.draggedCard = null
    }
  }

  dragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = this.draggedBundleItem ? "move" : "copy"
    const zone = event.currentTarget.closest('[data-bundle-builder-target="bundleDropZone"]') || event.currentTarget
    zone.classList.add("border-primary", "bg-primary-subtle", "shadow-sm")
  }

  dragLeave(event) {
    const zone = event.currentTarget.closest('[data-bundle-builder-target="bundleDropZone"]') || event.currentTarget
    zone.classList.remove("border-primary", "bg-primary-subtle", "shadow-sm")
  }

  async drop(event) {
    event.preventDefault()
    const zone = event.currentTarget.closest('[data-bundle-builder-target="bundleDropZone"]') || event.currentTarget
    zone.classList.remove("border-primary", "bg-primary-subtle", "shadow-sm")

    const questionId = event.dataTransfer.getData("text/plain")
    const bundleId = zone.dataset.bundleId
    const bundleName = zone.dataset.bundleName

    if (this.draggedBundleItem) {
      const container = this.draggedBundleItem.parentNode
      this.updateBundleSerialNumbers(container)
      const bId = container.dataset.bundleId || bundleId
      await this.saveBundleQuestionsOrder(bId, container)
      this.draggedBundleItem = null
      return
    }

    if (!questionId || !bundleId) return

    await this.assignQuestionToBundle(questionId, bundleId, bundleName, zone)
  }

  // --- Click-to-Assign Handler ---
  async assignFromSelect(event) {
    const select = event.currentTarget
    const bundleId = select.value
    const questionId = select.dataset.questionId
    const bundleName = select.options[select.selectedIndex].text

    if (!bundleId) return

    const zone = this.bundleDropZoneTargets.find(z => z.dataset.bundleId === bundleId)
    await this.assignQuestionToBundle(questionId, bundleId, bundleName, zone)
    select.value = "" // Reset select
  }

  // --- Quick Remove Handler ---
  async removeQuestion(event) {
    const btn = event.currentTarget
    const bundleId = btn.dataset.bundleId
    const questionId = btn.dataset.questionId

    try {
      const response = await fetch(`/admin/question_categories/${this.categoryIdValue}/bundles/${bundleId}/remove_question/${questionId}`, {
        method: "DELETE",
        headers: {
          "X-CSRF-Token": this.csrfToken,
          "Accept": "text/vnd.turbo-stream.html, application/json"
        }
      })

      if (response.ok) {
        const contentType = response.headers.get("content-type") || ""
        if (contentType.includes("turbo-stream")) {
          const streamHtml = await response.text()
          if (window.Turbo) {
            window.Turbo.renderStreamMessage(streamHtml)
          }
          const container = document.getElementById(`bundle_items_${bundleId}`)
          if (container) this.updateBundleSerialNumbers(container)
        } else {
          const data = await response.json()
          this.showToast(data.message, data.status === "warning" ? "warning" : "success")
        }
      } else {
        this.showToast("Failed to remove question", "danger")
      }
    } catch (err) {
      console.error(err)
      this.showToast("An error occurred while removing question", "danger")
    }
  }

  // --- Helper Methods ---
  async assignQuestionToBundle(questionId, bundleId, bundleName, zone) {
    if (!questionId || !bundleId) return

    const lockKey = `${questionId}_${bundleId}`
    if (!this.pendingAssignments) this.pendingAssignments = new Set()
    if (this.pendingAssignments.has(lockKey)) {
      return
    }
    this.pendingAssignments.add(lockKey)

    try {
      const response = await fetch(`/admin/question_categories/${this.categoryIdValue}/bundles/${bundleId}/add_question`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken,
          "Accept": "text/vnd.turbo-stream.html, application/json"
        },
        body: JSON.stringify({ question_id: questionId })
      })

      if (response.ok) {
        const contentType = response.headers.get("content-type") || ""
        if (contentType.includes("turbo-stream")) {
          const streamHtml = await response.text()
          if (window.Turbo) {
            window.Turbo.renderStreamMessage(streamHtml)
          }
          const container = zone || document.getElementById(`bundle_items_${bundleId}`)
          if (container) this.updateBundleSerialNumbers(container)
        } else {
          const data = await response.json()
          this.showToast(data.message, data.status === "warning" ? "warning" : "success")
        }
      } else {
        this.showToast("Failed to add question to bundle", "warning")
      }
    } catch (err) {
      console.error(err)
      this.showToast("An error occurred while adding question to bundle", "danger")
    } finally {
      this.pendingAssignments.delete(lockKey)
    }
  }

  updateBundleCount(bundleId, count) {
    const badge = this.element.querySelector(`[data-bundle-count-id="${bundleId}"]`)
    if (badge) badge.textContent = `${count} ${count === 1 ? 'question' : 'questions'}`
  }

  updateQuestionBadge(questionId, bundleId, added) {
    const card = this.element.querySelector(`[data-question-id="${questionId}"]`)
    if (!card) return
    const bundleBadge = card.querySelector(".bundle-assigned-badge")
    if (bundleBadge) {
      bundleBadge.classList.remove("d-none")
    }
  }

  showToast(message, type = "success") {
    let container = document.getElementById("toast-container")
    if (!container) {
      container = document.createElement("div")
      container.id = "toast-container"
      container.className = "toast-container position-fixed bottom-0 end-0 p-3"
      container.style.zIndex = "1100"
      document.body.appendChild(container)
    }

    const toastEl = document.createElement("div")
    toastEl.className = `toast align-items-center text-bg-${type} border-0 show mb-2`
    toastEl.setAttribute("role", "alert")
    toastEl.innerHTML = `
      <div class="d-flex">
        <div class="toast-body d-flex align-items-center gap-2">
          <i class="bi ${type === 'success' ? 'bi-check-circle-fill' : 'bi-exclamation-triangle-fill'} fs-5"></i>
          <span>${message}</span>
        </div>
        <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button>
      </div>
    `

    container.appendChild(toastEl)
    setTimeout(() => {
      toastEl.classList.remove("show")
      setTimeout(() => toastEl.remove(), 300)
    }, 3500)
  }
}
