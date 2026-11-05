import { LightningElement, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";

/**
 * Utility bar item: one "button" available on every page of an app.
 * Follows navigation through CurrentPageReference — on a record page it
 * analyses that record; elsewhere it falls back to the record-Id input.
 */
export default class WhoHasAccessUtility extends LightningElement {
  pageRecordId;
  pageObjectApiName;

  @wire(CurrentPageReference)
  handlePageReference(pageRef) {
    const attributes = (pageRef && pageRef.attributes) || {};
    if (
      pageRef &&
      pageRef.type === "standard__recordPage" &&
      attributes.recordId
    ) {
      this.pageRecordId = attributes.recordId;
      this.pageObjectApiName = attributes.objectApiName;
    } else {
      this.pageRecordId = undefined;
      this.pageObjectApiName = undefined;
    }
  }

  get contextLabel() {
    if (!this.pageRecordId) {
      return "Not on a record page — paste a record Id below";
    }
    const object = this.pageObjectApiName ? `${this.pageObjectApiName} ` : "";
    return `Following this page: ${object}${this.pageRecordId}`;
  }

  get contextIcon() {
    return this.pageRecordId ? "utility:location" : "utility:search";
  }

  get canvasHeight() {
    const viewport = window.innerHeight || 800;
    return Math.max(320, viewport - 300);
  }
}
