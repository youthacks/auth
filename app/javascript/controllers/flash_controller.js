import { Controller } from "@hotwired/stimulus"

// Lets a flash message be dismissed.
export default class extends Controller {
  dismiss() {
    this.element.remove()
  }
}
