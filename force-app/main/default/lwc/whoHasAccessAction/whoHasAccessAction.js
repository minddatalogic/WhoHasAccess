import { LightningElement, api } from "lwc";
import { loadStyle } from "lightning/platformResourceLoader";
import MODAL_CSS from "@salesforce/resourceUrl/whoHasAccessModal";

/**
 * Screen quick action wrapper. Add it to any object as a
 * "Lightning Web Component" quick action — it widens the action modal
 * (scoped with :has(), so other modals are untouched) and passes recordId on.
 */
export default class WhoHasAccessAction extends LightningElement {
  @api recordId;
  @api objectApiName;

  stylesRequested = false;

  connectedCallback() {
    // The tag name changes with the package namespace (c-… vs ns-…),
    // so the modal CSS targets this host class instead.
    this.classList.add("wha-action-host");    
    if (!this.stylesRequested) {
      this.stylesRequested = true;
      loadStyle(this, MODAL_CSS).catch(() => {
        // the modal still works at the default width
      });
    }
  }

  get canvasHeight() {
    const viewport = window.innerHeight || 800;
    return Math.max(380, Math.round(viewport * 0.62));
  }
}
