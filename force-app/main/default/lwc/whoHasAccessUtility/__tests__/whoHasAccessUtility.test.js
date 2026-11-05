import { createElement } from "lwc";
import WhoHasAccessUtility from "c/whoHasAccessUtility";
import { CurrentPageReference } from "lightning/navigation";

// jsdom has no canvas; the renderer falls back to estimated text widths
HTMLCanvasElement.prototype.getContext = () => null;

jest.mock(
  "@salesforce/apex/WhoHasAccessController.getAccessTree",
  () => ({
    default: jest.fn(() => Promise.resolve({ type: "RECORD", name: "X" }))
  }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/WhoHasAccessController.expandNode",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/WhoHasAccessController.getUserAccess",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flush = () => Promise.resolve();

describe("c-who-has-access-utility", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("follows the current record page", async () => {
    const element = createElement("c-who-has-access-utility", {
      is: WhoHasAccessUtility
    });
    document.body.appendChild(element);

    CurrentPageReference.emit({
      type: "standard__recordPage",
      attributes: {
        recordId: "a00000000000001AAA",
        objectApiName: "Project__c"
      }
    });
    await flush();

    const child = element.shadowRoot.querySelector("c-who-has-access");
    expect(child.recordId).toBe("a00000000000001AAA");
    expect(element.shadowRoot.querySelector(".context").textContent).toContain(
      "Project__c"
    );
  });

  it("clears the record when leaving a record page", async () => {
    const element = createElement("c-who-has-access-utility", {
      is: WhoHasAccessUtility
    });
    document.body.appendChild(element);

    CurrentPageReference.emit({
      type: "standard__recordPage",
      attributes: { recordId: "a00000000000001AAA" }
    });
    await flush();
    CurrentPageReference.emit({
      type: "standard__objectPage",
      attributes: { objectApiName: "Project__c" }
    });
    await flush();

    const child = element.shadowRoot.querySelector("c-who-has-access");
    expect(child.recordId).toBeUndefined();
    expect(element.shadowRoot.querySelector(".context").textContent).toContain(
      "Not on a record page"
    );
  });
});
