import { Controller } from "@hotwired/stimulus"

const SURVEY_STORAGE_KEY = "site2llm-survey"
const RUN_STORAGE_KEY = "site2llm-run"

export default class extends Controller {
  static targets = [
    "form", "step", "submitBtn", "formNote", "statusMessage",
    "siteName", "siteUrl", "summary", "priorityPages", "optionalPages",
    "questions", "categories", "excludes", "siteType",
    "siteNameError", "siteUrlError", "summaryError", "priorityPagesError",
    "optionalPagesError", "questionsError", "categoriesError", "excludesError",
    "step1Status", "step2Status", "step3Status",
    "step1Panel", "step2Panel", "step3Panel",
    "step1Next", "step2Next", "step2Header", "step3Header",
    "previewIdle", "previewGenerating", "previewError", "previewReady",
    "previewErrorMessage", "previewVisible", "previewLocked",
    "previewFade", "previewCta", "checkoutBtn", "downloadBtn",
    "paymentNote", "newRunBtn", "storedRunCard", "storedRunInfo",
    "runIdModal", "runIdInput", "runIdError"
  ]

  connect() {
    this.currentStep = 1
    this.status = "idle"
    this.runId = null
    this.paymentStatus = "locked"
    this.storedRun = null

    this.loadStoredSurvey()
    this.loadStoredRun()
    this.checkStepCompletion()
    this.handleUrlParams()
  }

  loadStoredSurvey() {
    try {
      const raw = localStorage.getItem(SURVEY_STORAGE_KEY)
      if (!raw) return
      const saved = JSON.parse(raw)
      if (saved.site_name && this.hasSiteNameTarget) this.siteNameTarget.value = saved.site_name
      if (saved.site_url && this.hasSiteUrlTarget) this.siteUrlTarget.value = saved.site_url
      if (saved.summary && this.hasSummaryTarget) this.summaryTarget.value = saved.summary
      if (saved.priority_pages && this.hasPriorityPagesTarget) this.priorityPagesTarget.value = saved.priority_pages
      if (saved.optional_pages && this.hasOptionalPagesTarget) this.optionalPagesTarget.value = saved.optional_pages
      if (saved.questions && this.hasQuestionsTarget) this.questionsTarget.value = saved.questions
      if (saved.categories && this.hasCategoriesTarget) this.categoriesTarget.value = saved.categories
      if (saved.excludes && this.hasExcludesTarget) this.excludesTarget.value = saved.excludes
      if (saved.site_type && this.hasSiteTypeTarget) {
        this.siteTypeTarget.value = saved.site_type
        this.element.querySelectorAll('.toggle').forEach(btn => {
          btn.classList.toggle('active', btn.dataset.siteType === saved.site_type)
        })
      }
    } catch (e) {
      // Ignore errors
    }
  }

  loadStoredRun() {
    try {
      const raw = localStorage.getItem(RUN_STORAGE_KEY)
      if (!raw) return
      const stored = JSON.parse(raw)
      if (stored.runId) {
        this.storedRun = stored
        if (this.hasStoredRunCardTarget) {
          this.storedRunCardTarget.classList.remove('hidden')
          if (this.hasStoredRunInfoTarget) {
            const date = new Date(stored.updatedAt).toLocaleString()
            this.storedRunInfoTarget.textContent = `Last saved ${date} · Run ID: ${stored.runId}`
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }
  }

  handleUrlParams() {
    const url = new URL(window.location.href)
    const checkout = url.searchParams.get("checkout")
    const runId = url.searchParams.get("runId")

    if (checkout === "cancel" && runId) {
      this.paymentStatus = "locked"
      if (this.storedRun && this.storedRun.runId === runId) {
        this.restoreStoredRun()
      }
      this.showStatusMessage("Checkout canceled. You can try again anytime.")
      url.searchParams.delete("checkout")
      url.searchParams.delete("runId")
      window.history.replaceState({}, "", `${url.pathname}${url.search}`)
    } else if (this.storedRun && this.status === "idle") {
      // Don't auto-restore, let user click restore button
    }
  }

  persistSurvey() {
    try {
      const data = this.buildPayload()
      localStorage.setItem(SURVEY_STORAGE_KEY, JSON.stringify(data))
    } catch (e) {
      // Ignore errors
    }
  }

  buildPayload() {
    return {
      site_name: this.hasSiteNameTarget ? this.siteNameTarget.value : "",
      site_url: this.hasSiteUrlTarget ? this.normalizeSiteUrl(this.siteUrlTarget.value) : "",
      summary: this.hasSummaryTarget ? this.summaryTarget.value : "",
      priority_pages: this.hasPriorityPagesTarget ? this.priorityPagesTarget.value : "",
      optional_pages: this.hasOptionalPagesTarget ? this.optionalPagesTarget.value : "",
      questions: this.hasQuestionsTarget ? this.questionsTarget.value : "",
      categories: this.hasCategoriesTarget ? this.categoriesTarget.value : "",
      excludes: this.hasExcludesTarget ? this.excludesTarget.value : "",
      site_type: this.hasSiteTypeTarget ? this.siteTypeTarget.value : "docs"
    }
  }

  normalizeSiteUrl(value) {
    const trimmed = value.trim()
    if (!trimmed) return ""
    if (/^https?:\/\//i.test(trimmed)) return trimmed
    if (/^[\w.-]+\.\w{2,}(\/.*)?$/i.test(trimmed)) return `https://${trimmed}`
    return trimmed
  }

  checkStepCompletion() {
    const step1Complete = this.isStep1Complete()
    const step2Complete = this.isStep2Complete()
    const step3Complete = this.isStep3Complete()

    // Update step 1 status
    if (this.hasStep1StatusTarget) {
      this.step1StatusTarget.textContent = step1Complete ? "Complete" : "In progress"
      this.step1StatusTarget.classList.toggle("done", step1Complete)
      this.step1StatusTarget.classList.toggle("pending", !step1Complete)
    }
    if (this.hasStep1NextTarget) {
      this.step1NextTarget.disabled = !step1Complete
    }

    // Update step 2 status and unlock
    if (this.hasStep2HeaderTarget) {
      this.step2HeaderTarget.disabled = !step1Complete
      this.step2HeaderTarget.setAttribute("aria-disabled", !step1Complete)
    }
    if (this.hasStep2StatusTarget) {
      if (!step1Complete) {
        this.step2StatusTarget.textContent = "Locked"
        this.step2StatusTarget.classList.add("locked")
        this.step2StatusTarget.classList.remove("done", "pending")
      } else {
        this.step2StatusTarget.textContent = step2Complete ? "Complete" : "In progress"
        this.step2StatusTarget.classList.toggle("done", step2Complete)
        this.step2StatusTarget.classList.toggle("pending", !step2Complete)
        this.step2StatusTarget.classList.remove("locked")
      }
    }
    if (this.hasStep2NextTarget) {
      this.step2NextTarget.disabled = !step2Complete
    }

    // Update step 3 status and unlock
    if (this.hasStep3HeaderTarget) {
      this.step3HeaderTarget.disabled = !step2Complete
      this.step3HeaderTarget.setAttribute("aria-disabled", !step2Complete)
    }
    if (this.hasStep3StatusTarget) {
      if (!step2Complete) {
        this.step3StatusTarget.textContent = "Locked"
        this.step3StatusTarget.classList.add("locked")
        this.step3StatusTarget.classList.remove("done", "pending")
      } else {
        this.step3StatusTarget.textContent = step3Complete ? "Complete" : "In progress"
        this.step3StatusTarget.classList.toggle("done", step3Complete)
        this.step3StatusTarget.classList.toggle("pending", !step3Complete)
        this.step3StatusTarget.classList.remove("locked")
      }
    }

    // Update submit button
    const formComplete = step1Complete && step2Complete && step3Complete
    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.disabled = !formComplete || this.status === "generating"
    }
    if (this.hasFormNoteTarget) {
      this.formNoteTarget.classList.toggle("hidden", formComplete)
    }
  }

  isStep1Complete() {
    const siteName = this.hasSiteNameTarget ? this.siteNameTarget.value.trim() : ""
    const siteUrl = this.hasSiteUrlTarget ? this.siteUrlTarget.value.trim() : ""
    const summary = this.hasSummaryTarget ? this.summaryTarget.value.trim() : ""
    return siteName.length > 0 && this.isValidUrl(siteUrl) && summary.length >= 20
  }

  isStep2Complete() {
    const priorityPages = this.splitList(this.hasPriorityPagesTarget ? this.priorityPagesTarget.value : "")
    const questions = this.splitList(this.hasQuestionsTarget ? this.questionsTarget.value : "")
    return priorityPages.length >= 3 && priorityPages.length <= 8 && questions.length > 0
  }

  isStep3Complete() {
    const categories = this.splitList(this.hasCategoriesTarget ? this.categoriesTarget.value : "")
    return categories.length > 0
  }

  isValidUrl(value) {
    const trimmed = this.normalizeSiteUrl(value)
    if (!trimmed) return false
    try {
      const parsed = new URL(trimmed)
      return ["http:", "https:"].includes(parsed.protocol)
    } catch {
      return false
    }
  }

  splitList(value) {
    return value.split(/[\n,]+/).map(item => item.trim()).filter(item => item && !this.isNoneValue(item))
  }

  isNoneValue(value) {
    return ["none", "n/a", "na"].includes(value.toLowerCase().trim())
  }

  goToStep(event) {
    const stepIndex = parseInt(event.currentTarget.dataset.stepIndex, 10)
    if (stepIndex === 2 && !this.isStep1Complete()) return
    if (stepIndex === 3 && !this.isStep2Complete()) return
    this.setCurrentStep(stepIndex)
  }

  nextStep() {
    if (this.currentStep < 3) {
      this.setCurrentStep(this.currentStep + 1)
    }
  }

  prevStep() {
    if (this.currentStep > 1) {
      this.setCurrentStep(this.currentStep - 1)
    }
  }

  setCurrentStep(step) {
    this.currentStep = step

    this.stepTargets.forEach(stepEl => {
      const stepNum = parseInt(stepEl.dataset.step, 10)
      stepEl.classList.toggle("active", stepNum === step)
    })

    if (this.hasStep1PanelTarget) {
      this.step1PanelTarget.classList.toggle("open", step === 1)
    }
    if (this.hasStep2PanelTarget) {
      this.step2PanelTarget.classList.toggle("open", step === 2)
    }
    if (this.hasStep3PanelTarget) {
      this.step3PanelTarget.classList.toggle("open", step === 3)
    }
  }

  selectSiteType(event) {
    const siteType = event.currentTarget.dataset.siteType
    this.element.querySelectorAll('.toggle').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.siteType === siteType)
    })
    if (this.hasSiteTypeTarget) {
      this.siteTypeTarget.value = siteType
    }
    this.persistSurvey()
  }

  scrollToSurvey() {
    const target = document.getElementById("survey")
    if (target) {
      target.scrollIntoView({ behavior: "smooth", block: "start" })
    }
  }

  async handleGenerate(event) {
    event.preventDefault()
    this.clearErrors()
    this.status = "generating"
    this.updatePreviewState()

    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.disabled = true
      this.submitBtnTarget.textContent = "Generating..."
    }

    try {
      const payload = this.buildPayload()
      const response = await fetch("/api/generate", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      })

      const data = await response.json().catch(() => null)

      if (!response.ok) {
        this.status = "error"
        if (data?.errors) {
          this.showErrors(data.errors)
          this.showStatusMessage("Fix the highlighted fields to generate your llms.txt.")
        } else {
          this.showStatusMessage(data?.error || "Generation failed. Try again in a moment.")
        }
        this.updatePreviewState()
        return
      }

      this.status = "ready"
      this.runId = data.runId
      this.paymentStatus = "locked"

      if (this.hasPreviewVisibleTarget) {
        this.previewVisibleTarget.textContent = data.preview || ""
      }
      if (this.hasPreviewLockedTarget) {
        this.previewLockedTarget.textContent = data.lockedPreview || ""
      }

      this.saveRun({
        runId: data.runId,
        preview: data.preview,
        lockedPreview: data.lockedPreview,
        mode: data.mode,
        updatedAt: Date.now(),
        paid: false
      })

      this.updatePreviewState()
      this.setCurrentStep(0) // Collapse form

      setTimeout(() => {
        const previewSection = document.getElementById("preview-section")
        if (previewSection) {
          previewSection.scrollIntoView({ behavior: "smooth", block: "start" })
        }
      }, 100)
    } catch (error) {
      this.status = "error"
      this.showStatusMessage("Generation failed. Try again in a moment.")
      this.updatePreviewState()
    } finally {
      if (this.hasSubmitBtnTarget) {
        this.submitBtnTarget.disabled = false
        this.submitBtnTarget.textContent = "Generate llms.txt file"
      }
    }
  }

  updatePreviewState() {
    const states = ["Idle", "Generating", "Error", "Ready"]
    states.forEach(state => {
      const target = this[`hasPreview${state}Target`] ? this[`preview${state}Target`] : null
      if (target) {
        const isActive = (this.status === "idle" && state === "Idle") ||
                        (this.status === "generating" && state === "Generating") ||
                        (this.status === "error" && state === "Error") ||
                        (this.status === "ready" && state === "Ready")
        target.classList.toggle("hidden", !isActive)
      }
    })

    // Show/hide payment overlay
    const showOverlay = this.status === "ready" && this.paymentStatus !== "paid" && this.hasPreviewLockedTarget && this.previewLockedTarget.textContent
    if (this.hasPreviewFadeTarget) {
      this.previewFadeTarget.classList.toggle("hidden", !showOverlay)
    }
    if (this.hasPreviewCtaTarget) {
      this.previewCtaTarget.classList.toggle("hidden", !showOverlay)
    }

    // Show download button if paid
    if (this.hasDownloadBtnTarget) {
      this.downloadBtnTarget.classList.toggle("hidden", this.paymentStatus !== "paid")
    }
    if (this.hasPaymentNoteTarget) {
      this.paymentNoteTarget.classList.toggle("hidden", this.paymentStatus === "paid")
    }
    if (this.hasNewRunBtnTarget) {
      this.newRunBtnTarget.classList.toggle("hidden", !this.storedRun)
    }
  }

  showErrors(errors) {
    Object.entries(errors).forEach(([field, message]) => {
      const errorTarget = this[`has${this.capitalize(field)}ErrorTarget`] ? this[`${this.camelize(field)}ErrorTarget`] : null
      const inputTarget = this[`has${this.capitalize(field)}Target`] ? this[`${this.camelize(field)}Target`] : null
      if (errorTarget) {
        errorTarget.textContent = message
        errorTarget.classList.remove("hidden")
      }
      if (inputTarget) {
        inputTarget.classList.add("invalid")
      }
    })
  }

  clearErrors() {
    const errorFields = ["siteName", "siteUrl", "summary", "priorityPages", "optionalPages", "questions", "categories", "excludes"]
    errorFields.forEach(field => {
      const errorTarget = this[`has${this.capitalize(field)}ErrorTarget`] ? this[`${field}ErrorTarget`] : null
      const inputTarget = this[`has${this.capitalize(field)}Target`] ? this[`${field}Target`] : null
      if (errorTarget) {
        errorTarget.textContent = ""
        errorTarget.classList.add("hidden")
      }
      if (inputTarget) {
        inputTarget.classList.remove("invalid")
      }
    })
    if (this.hasStatusMessageTarget) {
      this.statusMessageTarget.classList.add("hidden")
    }
  }

  showStatusMessage(message) {
    if (this.hasStatusMessageTarget) {
      this.statusMessageTarget.textContent = message
      this.statusMessageTarget.classList.remove("hidden")
    }
    if (this.hasPreviewErrorMessageTarget && this.status === "error") {
      this.previewErrorMessageTarget.textContent = message
    }
  }

  async handleCheckout() {
    if (this.paymentStatus === "processing" || !this.runId) return

    this.paymentStatus = "processing"
    if (this.hasCheckoutBtnTarget) {
      this.checkoutBtnTarget.disabled = true
      this.checkoutBtnTarget.textContent = "Opening checkout..."
    }

    try {
      const response = await fetch("/api/checkout", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ runId: this.runId })
      })
      const data = await response.json().catch(() => null)
      if (data?.url) {
        window.location.href = data.url
        return
      }
      this.paymentStatus = "error"
    } catch (error) {
      this.paymentStatus = "error"
    } finally {
      if (this.hasCheckoutBtnTarget) {
        this.checkoutBtnTarget.disabled = false
        this.checkoutBtnTarget.textContent = "Pay to unlock"
      }
    }
  }

  async downloadPreview() {
    if (!this.runId) return
    try {
      const response = await fetch(`/api/download?runId=${this.runId}`)
      if (!response.ok) {
        this.showStatusMessage("Download failed. Try again in a moment.")
        return
      }
      const content = await response.text()
      this.downloadBlob(content, "llms.txt")
    } catch (error) {
      this.showStatusMessage("Download failed. Try again in a moment.")
    }
  }

  downloadBlob(content, filename) {
    const blob = new Blob([content], { type: "text/plain" })
    const url = URL.createObjectURL(blob)
    const link = document.createElement("a")
    link.href = url
    link.download = filename
    link.click()
    setTimeout(() => URL.revokeObjectURL(url), 1000)
  }

  saveRun(run) {
    this.storedRun = run
    try {
      localStorage.setItem(RUN_STORAGE_KEY, JSON.stringify(run))
    } catch (e) {
      // Ignore errors
    }
  }

  restoreStoredRun() {
    if (!this.storedRun) return

    this.runId = this.storedRun.runId
    this.paymentStatus = this.storedRun.paid ? "paid" : "locked"
    this.status = "ready"

    if (this.hasPreviewVisibleTarget) {
      this.previewVisibleTarget.textContent = this.storedRun.preview || ""
    }
    if (this.hasPreviewLockedTarget) {
      this.previewLockedTarget.textContent = this.storedRun.lockedPreview || ""
    }

    this.updatePreviewState()
    this.showStatusMessage("Recovered your last run.")

    if (!this.storedRun.paid) {
      this.syncPaymentStatus()
    }
  }

  async syncPaymentStatus() {
    if (!this.runId) return
    try {
      const response = await fetch(`/api/run?runId=${this.runId}`)
      if (!response.ok) return
      const data = await response.json()
      if (data.paid) {
        this.paymentStatus = "paid"
        this.showStatusMessage("Payment received. Download your llms.txt below.")
        this.updatePreviewState()
        this.saveRun({ ...this.storedRun, paid: true, updatedAt: Date.now() })
      }
    } catch (e) {
      // Ignore errors
    }
  }

  startNewRun() {
    this.storedRun = null
    localStorage.removeItem(RUN_STORAGE_KEY)
    this.status = "idle"
    this.runId = null
    this.paymentStatus = "locked"
    this.updatePreviewState()
    this.setCurrentStep(1)
    this.scrollToSurvey()
  }

  openRunIdLookup() {
    if (this.hasRunIdModalTarget) {
      this.runIdModalTarget.classList.remove("hidden")
      if (this.hasRunIdInputTarget) {
        this.runIdInputTarget.value = ""
        this.runIdInputTarget.focus()
      }
    }
  }

  closeRunIdLookup() {
    if (this.hasRunIdModalTarget) {
      this.runIdModalTarget.classList.add("hidden")
    }
    this.clearRunIdError()
  }

  clearRunIdError() {
    if (this.hasRunIdErrorTarget) {
      this.runIdErrorTarget.textContent = ""
      this.runIdErrorTarget.classList.add("hidden")
    }
  }

  submitRunIdLookup(event) {
    event.preventDefault()
    const runId = this.hasRunIdInputTarget ? this.runIdInputTarget.value.trim() : ""
    if (!runId) {
      if (this.hasRunIdErrorTarget) {
        this.runIdErrorTarget.textContent = "Enter a Run ID to continue."
        this.runIdErrorTarget.classList.remove("hidden")
      }
      return
    }
    window.location.href = `/success?runId=${encodeURIComponent(runId)}`
  }

  handleLookupKeydown(event) {
    if (event.key === "Escape") {
      this.closeRunIdLookup()
    }
  }

  stopModalClick(event) {
    event.stopPropagation()
  }

  capitalize(str) {
    return str.charAt(0).toUpperCase() + str.slice(1)
  }

  camelize(str) {
    return str.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase())
  }
}
