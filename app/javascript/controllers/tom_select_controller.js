import { Controller } from "@hotwired/stimulus"
import TomSelect from 'tom-select'

// Connects to data-controller="tom-select"
export default class extends Controller {
  connect() {
    // documentation here: https://tom-select.js.org/docs/
    var settings = []
    new TomSelect(this.element,settings);
  }
}
