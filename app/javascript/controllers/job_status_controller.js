import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="job-status"
export default class extends Controller {
  static targets = ["status", "refreshButton"]
  static values = { 
    jobId: String,
    pollInterval: { type: Number, default: 5000 }, // 5 seconds
    maxPollAttempts: { type: Number, default: 120 } // 10 minutes max
  }

  connect() {
    this.pollAttempts = 0
    this.pollingActive = false
    
    // Only start polling if Turbo Streams are not supported or as fallback
    if (!this.supportsTurboStreams()) {
      this.startPolling()
    }
    
    // Add connection indicator
    this.showConnectionStatus("connected")
  }

  disconnect() {
    this.stopPolling()
  }

  // Manual refresh button action
  refresh() {
    if (this.hasRefreshButtonTarget) {
      this.showRefreshSpinner()
    }
    
    this.fetchStatus()
      .then(() => {
        this.showConnectionStatus("refreshed")
      })
      .catch((error) => {
        console.error("Manual refresh failed:", error)
        this.showConnectionStatus("error")
      })
      .finally(() => {
        if (this.hasRefreshButtonTarget) {
          this.hideRefreshSpinner()
        }
      })
  }

  // Start polling for browsers without Turbo Stream support
  startPolling() {
    if (this.pollingActive) return
    
    this.pollingActive = true
    this.poll()
  }

  stopPolling() {
    this.pollingActive = false
    if (this.pollTimeoutId) {
      clearTimeout(this.pollTimeoutId)
      this.pollTimeoutId = null
    }
  }

  // Internal polling mechanism
  poll() {
    if (!this.pollingActive || this.pollAttempts >= this.maxPollAttemptsValue) {
      this.stopPolling()
      return
    }

    this.fetchStatus()
      .then((data) => {
        this.pollAttempts++
        
        // Stop polling if job is in final state
        if (this.isJobComplete(data.status)) {
          this.stopPolling()
          this.showConnectionStatus("completed")
          return
        }
        
        // Continue polling
        this.scheduleNextPoll()
      })
      .catch((error) => {
        console.error("Polling failed:", error)
        this.pollAttempts++
        this.showConnectionStatus("error")
        
        // Retry with exponential backoff
        this.scheduleNextPoll(true)
      })
  }

  scheduleNextPoll(withBackoff = false) {
    if (!this.pollingActive) return
    
    let delay = this.pollIntervalValue
    
    if (withBackoff) {
      // Exponential backoff: 5s, 10s, 20s, 40s, max 60s
      const backoffFactor = Math.min(Math.pow(2, Math.floor(this.pollAttempts / 3)), 12)
      delay = this.pollIntervalValue * backoffFactor
    }
    
    this.pollTimeoutId = setTimeout(() => {
      this.poll()
    }, delay)
  }

  // Fetch job status from API endpoint
  async fetchStatus() {
    const response = await fetch(`/jobs/${this.jobIdValue}/status.json`, {
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`)
    }
    
    const data = await response.json()
    
    // Update the status display if we have a target (fallback for non-Turbo Stream browsers)
    if (this.hasStatusTarget && !this.supportsTurboStreams()) {
      this.updateStatusDisplay(data)
    }
    
    return data
  }

  // Update status display for fallback polling
  updateStatusDisplay(statusData) {
    // This would update the status display, but since we have Turbo Streams,
    // we mainly use this as a fallback. The actual UI updates happen via
    // Turbo Stream broadcasts in most cases.
    
    // Dispatch a custom event that other parts of the page can listen to
    this.dispatch("statusUpdated", { 
      detail: { 
        jobId: this.jobIdValue, 
        status: statusData.status,
        statusData: statusData
      } 
    })
  }

  // Check if browser supports Turbo Streams
  supportsTurboStreams() {
    return typeof window.Turbo !== "undefined" && 
           window.Turbo.StreamActions !== "undefined"
  }

  // Check if job is in a final state
  isJobComplete(status) {
    return ["completed", "failed", "not_found", "error"].includes(status)
  }

  // Visual feedback methods
  showRefreshSpinner() {
    if (this.hasRefreshButtonTarget) {
      const button = this.refreshButtonTarget
      const originalContent = button.innerHTML
      
      button.disabled = true
      button.innerHTML = `
        <svg class="animate-spin h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Refreshing...
      `
      
      // Store original content for restoration
      button.dataset.originalContent = originalContent
    }
  }

  hideRefreshSpinner() {
    if (this.hasRefreshButtonTarget) {
      const button = this.refreshButtonTarget
      button.disabled = false
      
      if (button.dataset.originalContent) {
        button.innerHTML = button.dataset.originalContent
        delete button.dataset.originalContent
      }
    }
  }

  showConnectionStatus(status) {
    // Dispatch event for status indicator updates
    this.dispatch("connectionStatus", { 
      detail: { 
        status: status,
        timestamp: new Date().toISOString()
      } 
    })
  }

  // Lifecycle hooks for debugging
  jobIdValueChanged() {
    console.log("Job ID changed to:", this.jobIdValue)
  }

  pollIntervalValueChanged() {
    // Restart polling with new interval if active
    if (this.pollingActive) {
      this.stopPolling()
      this.startPolling()
    }
  }
}