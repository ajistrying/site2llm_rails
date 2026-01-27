import { Controller } from "@hotwired/stimulus"

const SURVEY_STORAGE_KEY = "site2llm-survey"

export default class extends Controller {
  static values = {
    runId: String,
    paid: Boolean,
    content: String
  }

  static targets = [
    "pendingHeader", "failedHeader", "pendingIcon",
    "pollingArea", "statusMessage", "progressBar", "progressFill",
    "retryArea", "paidContent", "contentDisplay",
    "copyBtn", "copyBtn2", "copyStatus", "copyStatus2",
    "llmsUrl", "llmsUrl2"
  ]

  connect() {
    this.maxAttempts = 20
    this.pollInterval = 3000
    this.pollAttempt = 0
    this.pollFailed = false
    this.content = this.contentValue

    this.loadSiteOrigin()

    if (!this.paidValue) {
      this.pollPaymentStatus()
    }
  }

  loadSiteOrigin() {
    try {
      const raw = localStorage.getItem(SURVEY_STORAGE_KEY)
      if (!raw) return
      const stored = JSON.parse(raw)
      if (stored.site_url && stored.site_url.trim()) {
        let normalized = stored.site_url.trim()
        if (!/^https?:\/\//i.test(normalized)) {
          normalized = `https://${normalized}`
        }
        const origin = new URL(normalized).origin
        const llmsUrl = `${origin}/llms.txt`

        if (this.hasLlmsUrlTarget) {
          this.llmsUrlTarget.textContent = llmsUrl
        }
        if (this.hasLlmsUrl2Target) {
          this.llmsUrl2Target.textContent = llmsUrl
        }
      }
    } catch (e) {
      // Ignore errors
    }
  }

  async pollPaymentStatus() {
    for (let attempt = 0; attempt < this.maxAttempts; attempt++) {
      this.pollAttempt = attempt + 1

      try {
        const response = await fetch(`/api/run?runId=${this.runIdValue}`)
        if (!response.ok) {
          this.showFailed("Error checking payment status.")
          return
        }

        const result = await response.json()

        if (result.paid) {
          // Payment confirmed - fetch the content
          const downloadResponse = await fetch(`/api/download?runId=${this.runIdValue}`)
          if (downloadResponse.ok) {
            this.content = await downloadResponse.text()
            this.showPaid()
            return
          }
        }

        // Not paid yet, update progress
        this.updateProgress(attempt + 1)
        await this.sleep(this.pollInterval)
      } catch (e) {
        await this.sleep(this.pollInterval)
      }
    }

    // Polling exhausted
    this.showFailed("Payment confirmation timed out. Please refresh the page.")
  }

  updateProgress(attempt) {
    if (this.hasStatusMessageTarget) {
      this.statusMessageTarget.textContent = `Confirming payment... (${attempt}/${this.maxAttempts})`
    }
    if (this.hasProgressFillTarget) {
      const percent = (attempt / this.maxAttempts) * 100
      this.progressFillTarget.style.width = `${percent}%`
    }
  }

  showFailed(message) {
    this.pollFailed = true

    if (this.hasPendingHeaderTarget) {
      this.pendingHeaderTarget.classList.add("hidden")
    }
    if (this.hasFailedHeaderTarget) {
      this.failedHeaderTarget.classList.remove("hidden")
    }
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.classList.add("hidden")
    }
    if (this.hasStatusMessageTarget) {
      this.statusMessageTarget.textContent = message
    }
    if (this.hasRetryAreaTarget) {
      this.retryAreaTarget.classList.remove("hidden")
    }
  }

  showPaid() {
    if (this.hasPollingAreaTarget) {
      this.pollingAreaTarget.classList.add("hidden")
    }
    if (this.hasPendingHeaderTarget) {
      this.pendingHeaderTarget.classList.add("hidden")
    }
    if (this.hasPaidContentTarget) {
      this.paidContentTarget.classList.remove("hidden")
    }
    if (this.hasContentDisplayTarget) {
      this.contentDisplayTarget.textContent = this.content
    }
  }

  refreshStatus() {
    this.pollFailed = false
    this.pollAttempt = 0

    if (this.hasRetryAreaTarget) {
      this.retryAreaTarget.classList.add("hidden")
    }
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.classList.remove("hidden")
    }
    if (this.hasProgressFillTarget) {
      this.progressFillTarget.style.width = "0%"
    }
    if (this.hasStatusMessageTarget) {
      this.statusMessageTarget.textContent = "Checking payment status..."
    }
    if (this.hasPendingHeaderTarget) {
      this.pendingHeaderTarget.classList.remove("hidden")
    }
    if (this.hasFailedHeaderTarget) {
      this.failedHeaderTarget.classList.add("hidden")
    }

    this.pollPaymentStatus()
  }

  downloadFile() {
    if (!this.content) return

    const blob = new Blob([this.content], { type: "text/plain" })
    const url = URL.createObjectURL(blob)
    const link = document.createElement("a")
    link.href = url
    link.download = "llms.txt"
    link.click()
    setTimeout(() => URL.revokeObjectURL(url), 1000)
  }

  async copyToClipboard() {
    if (!this.content) return

    try {
      await navigator.clipboard.writeText(this.content)
      this.setCopyState("copied")
    } catch (e) {
      this.setCopyState("error")
    }
  }

  setCopyState(state) {
    const btnTargets = [this.hasCopyBtnTarget ? this.copyBtnTarget : null, this.hasCopyBtn2Target ? this.copyBtn2Target : null].filter(Boolean)
    const statusTargets = [this.hasCopyStatusTarget ? this.copyStatusTarget : null, this.hasCopyStatus2Target ? this.copyStatus2Target : null].filter(Boolean)

    btnTargets.forEach(btn => {
      btn.classList.toggle("is-copied", state === "copied")
      btn.classList.toggle("is-error", state === "error")
      btn.textContent = state === "copied" ? "Copied!" : state === "error" ? "Copy failed" : "Copy to clipboard"
    })

    statusTargets.forEach(status => {
      status.textContent = state === "copied"
        ? "Copied to clipboard."
        : state === "error"
          ? "Copy failed. Please download instead."
          : "Tap copy to keep the file in your clipboard."
    })

    if (state !== "idle") {
      setTimeout(() => this.setCopyState("idle"), 2000)
    }
  }

  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms))
  }
}
