import { Controller } from "@hotwired/stimulus"
// Connects to data-controller="instacart"
export default class extends Controller {
  connect() {
    // const storeId = this.element.getAttribute("storeId") || 'default'
    const userId = this.element.getAttribute("user_id");
    const recipeSourceUrl = `${window.location.origin}/shopping_list?user_id=${userId}&&cache-buster=${Date.now()}`;
    const i = new URL("https://www.instacart.com/widgets/standard-widget-button");
    i.searchParams.append("recipeSourceUrl", recipeSourceUrl);
    // i.searchParams.append('affiliate_id','1783');
    i.searchParams.append('affiliate_platform','recipe_widget');
    i.searchParams.append('utm_source','instacart_growth_partnerships');
    i.searchParams.append('utm_medium','affiliate_recipe_unknown');
    i.searchParams.append('offer_id','1');
    // i.searchParams.append("recipeSourceOrigin", 'goodmeasures');
    this.element.innerHTML = `<iframe src="${i.href}" scrolling="no" frameborder="0" style="width: 298px; height: 57px">`;
  }
}
