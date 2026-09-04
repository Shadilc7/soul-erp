import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "dropzone",
    "fileInput",
    "fileInfo",
    "fileName",
    "fileSize",
    "previewContainer",
    "previewTableHead",
    "previewTableBody",
    "previewRowCount",
    "submitBtn",
    "progressBar",
    "progressText",
    "statusPill",
    "statusMessage",
    "logEntries",
    "statsTotal",
    "statsSuccess",
    "statsFailed",
    "errorSection",
    "downloadFailedBtn",
    "builderBtn",
    "logCounter"
  ]

  static values = {
    statusUrl: String,
    currentStatus: String,
    pollInterval: { type: Number, default: 1500 }
  }

  connect() {
    if (this.hasStatusUrlValue && (this.currentStatusValue === "pending" || this.currentStatusValue === "processing")) {
      this.startPolling()
    }
  }

  disconnect() {
    this.stopPolling()
  }

  // --- Drag & Drop Handlers ---
  dragOver(event) {
    event.preventDefault()
    event.stopPropagation()
    if (this.hasDropzoneTarget) {
      this.dropzoneTarget.classList.add("border-primary", "bg-primary-subtle")
    }
  }

  dragLeave(event) {
    event.preventDefault()
    event.stopPropagation()
    if (this.hasDropzoneTarget) {
      this.dropzoneTarget.classList.remove("border-primary", "bg-primary-subtle")
    }
  }

  drop(event) {
    event.preventDefault()
    event.stopPropagation()
    if (this.hasDropzoneTarget) {
      this.dropzoneTarget.classList.remove("border-primary", "bg-primary-subtle")
    }

    const files = event.dataTransfer.files
    if (files && files.length > 0) {
      this.fileInputTarget.files = files
      this.handleFileSelected()
    }
  }

  triggerFileInput() {
    if (this.hasFileInputTarget) {
      this.fileInputTarget.click()
    }
  }

  handleFileSelected() {
    const file = this.fileInputTarget.files[0]
    if (!file) return

    // Display File Info
    if (this.hasFileInfoTarget) {
      this.fileInfoTarget.classList.remove("d-none")
      const icon = this.fileInfoTarget.querySelector("i")
      if (icon) {
        if (file.name.toLowerCase().endsWith(".xls") || file.name.toLowerCase().endsWith(".xlsx")) {
          icon.className = "bi bi-file-earmark-excel text-success fs-5"
        } else {
          icon.className = "bi bi-filetype-csv text-success fs-5"
        }
      }
    }
    if (this.hasFileNameTarget) {
      this.fileNameTarget.textContent = file.name
    }
    if (this.hasFileSizeTarget) {
      this.fileSizeTarget.textContent = this.formatBytes(file.size)
    }

    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.disabled = false
    }

    // Client-side Preview (read up to 256KB to capture XML structure & sample rows)
    this.generatePreview(file)
  }

  clearFile(event) {
    if (event) event.stopPropagation()
    this.fileInputTarget.value = ""
    if (this.hasFileInfoTarget) {
      this.fileInfoTarget.classList.add("d-none")
    }
    if (this.hasPreviewContainerTarget) {
      this.previewContainerTarget.classList.add("d-none")
    }
    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.disabled = true
    }
  }

  generatePreview(file) {
    if (!this.hasPreviewContainerTarget) return

    const fileName = file.name ? file.name.toLowerCase() : ""
    const isXlsx = fileName.endsWith(".xlsx")

    const reader = new FileReader()
    const slice = file.slice(0, 256 * 1024)

    reader.onload = (e) => {
      const text = e.target.result

      // 1. Binary XLSX detection (Zip header PK\x03\x04 or .xlsx extension with non-XML content)
      if (isXlsx || text.startsWith("PK\x03\x04")) {
        this.previewBinaryFile(file, "Excel Workbook (.xlsx)")
        return
      }

      // 2. SpreadsheetML XML (.xls) detection
      if (text.includes("urn:schemas-microsoft-com:office:spreadsheet") ||
          (text.includes("<Workbook") && text.includes("<Table")) ||
          (text.trim().startsWith("<?xml") && (text.includes("<Row") || text.includes("<Table")))) {
        this.previewSpreadsheetML(text)
        return
      }

      // 3. Fallback: Parse standard CSV
      this.previewCsv(text)
    }

    reader.readAsText(slice)
  }

  previewSpreadsheetML(xmlText) {
    const rows = this.extractSpreadsheetMLRowsRegex(xmlText)
    if (rows.length === 0) return

    const headers = rows[0]
    this.renderPreviewHeaders(headers)

    const dataRows = []
    for (let i = 1; i < rows.length && dataRows.length < 5; i++) {
      const row = rows[i]
      // Skip guide row if detected
      if (row.some(cell => cell.toLowerCase().startsWith("e.g.") || cell.toLowerCase().includes("accept only numbers"))) continue
      dataRows.push(row)
    }

    this.renderPreviewRows(dataRows, headers.length)

    this.previewContainerTarget.classList.remove("d-none")
    if (this.hasPreviewRowCountTarget) {
      this.previewRowCountTarget.textContent = `Showing first ${dataRows.length} sample rows of uploaded file`
    }
  }

  extractSpreadsheetMLRowsRegex(xmlText) {
    const rows = []
    const rowRegex = /<Row\b[^>]*>([\s\S]*?)<\/Row>/gi
    let match
    while ((match = rowRegex.exec(xmlText)) !== null) {
      const rowContent = match[1]
      const cellRegex = /<Cell\b([^>]*)>([\s\S]*?)<\/Cell>|<Cell\b([^>]*)\/>/gi
      const cells = []
      let cellMatch
      let colIdx = 0
      while ((cellMatch = cellRegex.exec(rowContent)) !== null) {
        const attrs = cellMatch[1] || cellMatch[3] || ""
        const inner = cellMatch[2] || ""
        const indexAttr = /ss:Index="(\d+)"/i.exec(attrs) || /Index="(\d+)"/i.exec(attrs)
        if (indexAttr) {
          const targetIndex = parseInt(indexAttr[1], 10) - 1
          while (colIdx < targetIndex) {
            cells.push("")
            colIdx++
          }
        }
        const dataMatch = /<Data\b[^>]*>([\s\S]*?)<\/Data>/i.exec(inner)
        const cellValue = dataMatch ? this.unescapeXml(dataMatch[1].trim()) : ""
        cells.push(cellValue)
        colIdx++
      }
      if (cells.length > 0 && !cells.every(c => c === "")) {
        rows.push(cells)
      }
    }
    return rows
  }

  unescapeXml(str) {
    return str
      .replace(/&amp;/g, "&")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&quot;/g, "\"")
      .replace(/&apos;/g, "'")
  }

  previewBinaryFile(file, formatName) {
    this.renderPreviewHeaders(["Format", "Filename", "File Size", "Import Status"])
    const rows = [
      [
        formatName,
        file.name,
        this.formatBytes(file.size),
        "Workbook format verified. Rows will be fully parsed and validated upon submission."
      ]
    ]
    this.renderPreviewRows(rows, 4)
    this.previewContainerTarget.classList.remove("d-none")
    if (this.hasPreviewRowCountTarget) {
      this.previewRowCountTarget.textContent = `${formatName} detected and ready for import`
    }
  }

  previewCsv(text) {
    const lines = text.split(/\r?\n/).filter(line => line.trim().length > 0)
    if (lines.length === 0) return

    // Parse headers
    const headers = this.parseCsvLine(lines[0])
    this.renderPreviewHeaders(headers)

    // Parse first up to 5 data rows
    const dataRows = []
    for (let i = 1; i < lines.length && dataRows.length < 5; i++) {
      const row = this.parseCsvLine(lines[i])
      // Skip guide row if detected
      if (row.some(cell => cell.toLowerCase().startsWith("e.g.") || cell.toLowerCase().includes("accept only numbers"))) continue
      dataRows.push(row)
    }

    this.renderPreviewRows(dataRows, headers.length)

    this.previewContainerTarget.classList.remove("d-none")
    if (this.hasPreviewRowCountTarget) {
      this.previewRowCountTarget.textContent = `Showing first ${dataRows.length} sample rows of uploaded file`
    }
  }

  parseCsvLine(text) {
    const result = []
    let cur = ""
    let inQuotes = false

    for (let i = 0; i < text.length; i++) {
      const ch = text[i]
      if (ch === '"') {
        if (inQuotes && text[i + 1] === '"') {
          cur += '"'
          i++
        } else {
          inQuotes = !inQuotes
        }
      } else if (ch === ',' && !inQuotes) {
        result.push(cur.trim())
        cur = ""
      } else {
        cur += ch
      }
    }
    result.push(cur.trim())
    return result
  }

  renderPreviewHeaders(headers) {
    if (!this.hasPreviewTableHeadTarget) return
    let html = "<tr>"
    headers.forEach((h, idx) => {
      html += `<th class="text-nowrap px-3 py-2 bg-light text-dark fw-semibold small border-bottom">${this.escapeHtml(h || `Col ${idx + 1}`)}</th>`
    })
    html += "</tr>"
    this.previewTableHeadTarget.innerHTML = html
  }

  renderPreviewRows(rows, expectedCols) {
    if (!this.hasPreviewTableBodyTarget) return
    let html = ""
    rows.forEach((row, rIdx) => {
      html += "<tr>"
      for (let c = 0; c < expectedCols; c++) {
        const val = row[c] || ""
        html += `<td class="text-nowrap px-3 py-2 text-muted small border-bottom" style="max-width: 250px; overflow: hidden; text-overflow: ellipsis;">${this.escapeHtml(val)}</td>`
      }
      html += "</tr>"
    })
    this.previewTableBodyTarget.innerHTML = html
  }

  // --- Real-time Polling for Import Status ---
  startPolling() {
    this.pollTimer = setInterval(() => {
      this.fetchStatus()
    }, this.pollIntervalValue)
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
      this.pollTimer = null
    }
  }

  async fetchStatus() {
    if (!this.hasStatusUrlValue) return

    try {
      const response = await fetch(this.statusUrlValue, {
        headers: { "Accept": "application/json" }
      })
      if (!response.ok) return

      const data = await response.json()
      this.updateStatusView(data)

      if (data.completed) {
        this.stopPolling()
      }
    } catch (err) {
      console.error("Failed to poll import status:", err)
    }
  }

  updateStatusView(data) {
    // Update KPI stats
    if (this.hasStatsTotalTarget) this.statsTotalTarget.textContent = data.total_rows
    if (this.hasStatsSuccessTarget) this.statsSuccessTarget.textContent = data.successful_rows
    if (this.hasStatsFailedTarget) this.statsFailedTarget.textContent = data.failed_rows

    // Update Progress Bar
    let pct = 10
    if (data.status === "completed") pct = 100
    else if (data.status === "partially_completed") pct = 100
    else if (data.status === "failed") pct = 100
    else if (data.total_rows > 0) {
      const processed = (data.successful_rows || 0) + (data.failed_rows || 0)
      pct = Math.max(15, Math.min(95, Math.round((processed / data.total_rows) * 100)))
    }

    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${pct}%`
      this.progressBarTarget.setAttribute("aria-valuenow", pct)
      if (data.status === "completed") {
        this.progressBarTarget.className = "progress-bar bg-success progress-bar-striped"
      } else if (data.status === "partially_completed") {
        this.progressBarTarget.className = "progress-bar bg-warning progress-bar-striped"
      } else if (data.status === "failed") {
        this.progressBarTarget.className = "progress-bar bg-danger"
      } else {
        this.progressBarTarget.className = "progress-bar progress-bar-striped progress-bar-animated bg-primary"
      }
    }

    if (this.hasProgressTextTarget) {
      this.progressTextTarget.textContent = `${pct}%`
    }

    // Update Status Pill
    if (this.hasStatusPillTarget) {
      if (data.status === "completed") {
        this.statusPillTarget.className = "badge bg-success-subtle text-success border border-success-subtle rounded-pill px-3 py-1.5 fw-semibold"
        this.statusPillTarget.innerHTML = `<i class="bi bi-check-circle-fill me-1"></i> Completed`
      } else if (data.status === "partially_completed") {
        this.statusPillTarget.className = "badge bg-warning-subtle text-warning-emphasis border border-warning-subtle rounded-pill px-3 py-1.5 fw-semibold"
        this.statusPillTarget.innerHTML = `<i class="bi bi-exclamation-triangle-fill me-1"></i> Completed with Errors`
      } else if (data.status === "failed") {
        this.statusPillTarget.className = "badge bg-danger-subtle text-danger border border-danger-subtle rounded-pill px-3 py-1.5 fw-semibold"
        this.statusPillTarget.innerHTML = `<i class="bi bi-x-circle-fill me-1"></i> Failed`
      } else {
        this.statusPillTarget.className = "badge bg-primary-subtle text-primary border border-primary-subtle rounded-pill px-3 py-1.5 fw-semibold"
        this.statusPillTarget.innerHTML = `<span class="spinner-border spinner-border-sm me-1" role="status"></span> Processing...`
      }
    }

    // Update Logs Stream
    if (this.hasLogEntriesTarget && Array.isArray(data.process_log)) {
      if (this.hasLogCounterTarget) {
        this.logCounterTarget.textContent = `${data.process_log.length} Events`
      }
      let logsHtml = ""
      data.process_log.forEach(item => {
        logsHtml += this.renderLogItem(item)
      })
      this.logEntriesTarget.innerHTML = logsHtml
      // Scroll to bottom smoothly
      this.logEntriesTarget.scrollTop = this.logEntriesTarget.scrollHeight
    }

    // Update Error Section if failed rows exist
    if (this.hasErrorSectionTarget && data.failed_rows > 0) {
      this.errorSectionTarget.classList.remove("d-none")
      if (this.hasDownloadFailedBtnTarget) {
        this.downloadFailedBtnTarget.classList.remove("d-none")
      }
    }
  }

  renderLogItem(item) {
    const level = item.level || "info"
    const time = item.time || ""
    const message = item.message || ""

    if (level === "success") {
      const rowMatch = message.match(/^Row\s+(\d+):\s+Created question\s+'([^']+)'\s*\(([^)]+)\)(.*)$/i)
      if (rowMatch) {
        const rowNum = rowMatch[1]
        const title = rowMatch[2]
        const meta = rowMatch[3]
        const extra = (rowMatch[4] || "").trim()
        const metaParts = meta.split(",").map(s => s.trim())
        const qType = metaParts[0] || "Question"
        const dayRange = metaParts[1] || ""

        return `
          <div class="timeline-step">
            <div class="timeline-node bg-success-subtle text-success border border-success border-opacity-25">
              <i class="bi bi-check-lg fs-6"></i>
            </div>
            <div class="timeline-content-card">
              <div class="d-flex align-items-center justify-content-between flex-wrap gap-2 mb-1.5">
                <div class="d-flex align-items-center gap-2">
                  <span class="badge bg-success-subtle text-success border border-success-subtle rounded-pill px-2.5 py-0.5 small fw-semibold">
                    Question Created
                  </span>
                  <span class="fw-bold text-dark small">Row ${rowNum}</span>
                </div>
                <span class="text-muted small" style="font-size: 0.75rem;">
                  <i class="bi bi-clock me-1"></i>${this.escapeHtml(time)}
                </span>
              </div>
              <div class="text-dark fw-semibold mb-1.5 small text-truncate" title="${this.escapeHtml(title)}">
                ${this.escapeHtml(title)}
              </div>
              <div class="d-flex align-items-center flex-wrap gap-1.5">
                <span class="badge bg-light text-secondary border rounded-pill px-2 py-0.5 small" style="font-size: 0.72rem;">
                  <i class="bi bi-tag me-1 text-primary"></i>${this.escapeHtml(qType)}
                </span>
                ${dayRange ? `<span class="badge bg-light text-secondary border rounded-pill px-2 py-0.5 small" style="font-size: 0.72rem;"><i class="bi bi-calendar3 me-1 text-info"></i>${this.escapeHtml(dayRange)}</span>` : ""}
                ${extra ? `<span class="badge bg-light text-secondary border rounded-pill px-2 py-0.5 small" style="font-size: 0.72rem;"><i class="bi bi-list-check me-1 text-success"></i>${this.escapeHtml(extra.replace(/\.$/, ""))}</span>` : ""}
              </div>
            </div>
          </div>
        `
      }

      return `
        <div class="timeline-step">
          <div class="timeline-node bg-success-subtle text-success border border-success border-opacity-25">
            <i class="bi bi-check-circle-fill fs-6"></i>
          </div>
          <div class="timeline-content-card">
            <div class="d-flex align-items-center justify-content-between flex-wrap gap-2 mb-1">
              <span class="badge bg-success-subtle text-success border border-success-subtle rounded-pill px-2.5 py-0.5 small fw-semibold">
                Success
              </span>
              <span class="text-muted small" style="font-size: 0.75rem;"><i class="bi bi-clock me-1"></i>${this.escapeHtml(time)}</span>
            </div>
            <div class="text-dark small">${this.escapeHtml(message)}</div>
          </div>
        </div>
      `
    } else if (level === "error") {
      return `
        <div class="timeline-step">
          <div class="timeline-node bg-danger-subtle text-danger border border-danger border-opacity-25">
            <i class="bi bi-x-circle-fill fs-6"></i>
          </div>
          <div class="timeline-content-card border-danger-subtle bg-danger-subtle bg-opacity-10">
            <div class="d-flex align-items-center justify-content-between flex-wrap gap-2 mb-1">
              <span class="badge bg-danger-subtle text-danger border border-danger-subtle rounded-pill px-2.5 py-0.5 small fw-semibold">
                Validation Error
              </span>
              <span class="text-muted small" style="font-size: 0.75rem;"><i class="bi bi-clock me-1"></i>${this.escapeHtml(time)}</span>
            </div>
            <div class="text-danger fw-medium small">${this.escapeHtml(message)}</div>
          </div>
        </div>
      `
    } else if (level === "warn") {
      return `
        <div class="timeline-step">
          <div class="timeline-node bg-warning-subtle text-warning-emphasis border border-warning border-opacity-25">
            <i class="bi bi-exclamation-triangle-fill fs-6"></i>
          </div>
          <div class="timeline-content-card border-warning-subtle bg-warning-subtle bg-opacity-10">
            <div class="d-flex align-items-center justify-content-between flex-wrap gap-2 mb-1">
              <span class="badge bg-warning-subtle text-warning-emphasis border border-warning-subtle rounded-pill px-2.5 py-0.5 small fw-semibold">
                Warning
              </span>
              <span class="text-muted small" style="font-size: 0.75rem;"><i class="bi bi-clock me-1"></i>${this.escapeHtml(time)}</span>
            </div>
            <div class="text-dark small">${this.escapeHtml(message)}</div>
          </div>
        </div>
      `
    } else {
      return `
        <div class="timeline-step">
          <div class="timeline-node bg-primary-subtle text-primary border border-primary border-opacity-25">
            <i class="bi bi-info-circle-fill fs-6"></i>
          </div>
          <div class="timeline-content-card">
            <div class="d-flex align-items-center justify-content-between flex-wrap gap-2 mb-1">
              <span class="badge bg-primary-subtle text-primary border border-primary-subtle rounded-pill px-2.5 py-0.5 small fw-semibold">
                System Step
              </span>
              <span class="text-muted small" style="font-size: 0.75rem;"><i class="bi bi-clock me-1"></i>${this.escapeHtml(time)}</span>
            </div>
            <div class="text-dark small">${this.escapeHtml(message)}</div>
          </div>
        </div>
      `
    }
  }

  formatBytes(bytes) {
    if (bytes === 0) return "0 Bytes"
    const k = 1024
    const sizes = ["Bytes", "KB", "MB", "GB"]
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + " " + sizes[i]
  }

  escapeHtml(str) {
    if (!str) return ""
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;")
  }
}
