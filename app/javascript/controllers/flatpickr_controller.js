import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr";

// Connects to data-controller="tom-select"
export default class extends Controller {
  connect() {
    flatpickr(".date-field", {
        altInput: true,
        altFormat: "F j, Y",
        dateFormat: "Y-m-d",
    })
  }
}
