import { Controller } from "@hotwired/stimulus"

// Copies the content of the `source` target to the clipboard.
export default class extends Controller {
  static targets = ["source", "button"]

  async copy() {
    try {
      await navigator.clipboard.writeText(this.sourceTarget.textContent.trim())
      this.flashButton("Copied!")
    } catch {
      this.flashButton("Copy failed")
    }
  }

  flashButton(text) {
    const original = this.buttonTarget.textContent
    this.buttonTarget.textContent = text
    setTimeout(() => (this.buttonTarget.textContent = original), 1500)
  }
}
