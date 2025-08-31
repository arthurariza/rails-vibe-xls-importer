// frozen_string_literal: true

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["columnsContainer", "columnTemplate", "preview"]
  static values = { templateId: Number }
  
  connect() {
    this.updatePreview()
  }
  
  addColumn() {
    const template = this.columnTemplateTarget.content.cloneNode(true)
    const columnDiv = template.querySelector('.column-field')
    
    // Generate unique IDs for the new column fields
    const uniqueId = 'new_' + Math.random().toString(36).substr(2, 9)
    const inputs = columnDiv.querySelectorAll('input, select')
    
    inputs.forEach(input => {
      if (input.name) {
        input.name = input.name.replace(/new_\w+/, uniqueId)
      }
    })
    
    // Update the data attribute
    columnDiv.dataset.columnId = uniqueId
    
    // Add remove functionality
    const removeButton = columnDiv.querySelector('.remove-column')
    removeButton.addEventListener('click', (e) => this.removeColumn(e))
    
    // Add change listeners for preview updates
    const nameInput = columnDiv.querySelector('.column-name')
    nameInput.addEventListener('input', () => this.updatePreview())
    
    this.columnsContainerTarget.appendChild(columnDiv)
    
    // Focus on the name field of the new column
    nameInput.focus()
    
    this.updatePreview()
  }
  
  removeColumn(event) {
    const columnDiv = event.target.closest('.column-field')
    const columnId = columnDiv.dataset.columnId
    
    if (!confirm('Are you sure? This will permanently delete the column and all its data.')) {
      return
    }
    
    // If it's an existing column (has numeric ID), make API call
    if (columnId && !columnId.startsWith('new_')) {
      this.deleteColumnFromServer(columnId, columnDiv)
    } else {
      // Just remove from DOM for new columns
      columnDiv.remove()
      this.updatePreview()
    }
  }
  
  async deleteColumnFromServer(columnId, columnDiv) {
    try {
      const response = await fetch(`/import_templates/${this.templateIdValue}/template_columns/${columnId}`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })
      
      const data = await response.json()
      
      if (data.status === 'success') {
        columnDiv.remove()
        this.updatePreview()
        this.showMessage('Column deleted successfully', 'success')
      } else {
        this.showMessage('Error deleting column: ' + data.errors.join(', '), 'error')
      }
    } catch (error) {
      console.error('Error deleting column:', error)
      this.showMessage('Network error deleting column', 'error')
    }
  }
  
  updatePreview() {
    const nameInputs = this.columnsContainerTarget.querySelectorAll('.column-name')
    const previewContainer = this.previewTarget
    
    if (nameInputs.length === 0) {
      previewContainer.innerHTML = '<span class="text-gray-500">Add columns to see preview</span>'
      return
    }
    
    const columnNames = Array.from(nameInputs)
      .map(input => input.value.trim())
      .filter(name => name.length > 0)
    
    if (columnNames.length === 0) {
      previewContainer.innerHTML = '<span class="text-gray-500">Enter column names to see preview</span>'
      return
    }
    
    previewContainer.innerHTML = columnNames
      .map(name => `<span class="bg-blue-200 text-blue-800 px-2 py-1 rounded">${this.escapeHtml(name)}</span>`)
      .join('')
  }
  
  showMessage(message, type) {
    // Create a simple toast notification
    const toast = document.createElement('div')
    toast.className = `fixed top-4 right-4 px-6 py-3 rounded-lg shadow-lg z-50 ${
      type === 'success' ? 'bg-green-600 text-white' : 'bg-red-600 text-white'
    }`
    toast.textContent = message
    
    document.body.appendChild(toast)
    
    setTimeout(() => {
      toast.remove()
    }, 3000)
  }
  
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
  
  // Add event listeners for preview updates when columns are modified
  columnsContainerTargetConnected(element) {
    const nameInputs = element.querySelectorAll('.column-name')
    nameInputs.forEach(input => {
      input.addEventListener('input', () => this.updatePreview())
    })
    
    const removeButtons = element.querySelectorAll('.remove-column')
    removeButtons.forEach(button => {
      button.addEventListener('click', (e) => this.removeColumn(e))
    })
  }
}