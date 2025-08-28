import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="file-upload"
export default class extends Controller {
  static targets = ["fileInput", "fileName"]

  // Handle file input change event
  updateFileName(event) {
    const input = event.target
    
    if (input.files && input.files[0]) {
      const file = input.files[0]
      const fileSize = (file.size / (1024 * 1024)).toFixed(2) // MB
      
      this.fileNameTarget.innerHTML = `
        <div class="flex items-center gap-2">
          <svg class="h-5 w-5 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
          </svg>
          <span><strong>${file.name}</strong> (${fileSize} MB)</span>
        </div>
      `
      this.fileNameTarget.classList.remove("hidden")
      
      // Update upload area appearance to show file selected
      this.element.classList.add("border-green-300", "bg-green-50")
      this.element.classList.remove("border-gray-300", "hover:border-blue-400", "hover:bg-blue-50")
    } else {
      this.hideFileName()
    }
  }

  // Handle drag over event
  dragOver(event) {
    event.preventDefault()
    this.element.classList.add("border-blue-500", "bg-blue-100")
  }

  // Handle drag leave event
  dragLeave(event) {
    event.preventDefault()
    this.element.classList.remove("border-blue-500", "bg-blue-100")
  }

  // Handle drop event
  drop(event) {
    event.preventDefault()
    this.element.classList.remove("border-blue-500", "bg-blue-100")
    
    const files = event.dataTransfer.files
    if (files.length > 0) {
      this.fileInputTarget.files = files
      // Trigger the change event manually to update the filename display
      this.updateFileName({ target: this.fileInputTarget })
    }
  }

  // Handle click to upload
  clickToUpload(event) {
    // Only trigger file input if user didn't click on a button or other interactive element
    if (event.target.tagName !== "BUTTON" && event.target.tagName !== "INPUT") {
      this.fileInputTarget.click()
    }
  }

  // Private method to reset filename display
  hideFileName() {
    this.fileNameTarget.classList.add("hidden")
    this.element.classList.remove("border-green-300", "bg-green-50")
    this.element.classList.add("border-gray-300", "hover:border-blue-400", "hover:bg-blue-50")
  }
}