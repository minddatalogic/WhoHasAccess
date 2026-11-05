import { createElement } from "lwc";
import WhoHasAccess, { reduceError } from "c/whoHasAccess";
import getAccessTree from "@salesforce/apex/WhoHasAccessController.getAccessTree";
import expandNode from "@salesforce/apex/WhoHasAccessController.expandNode";
import getUserAccess from "@salesforce/apex/WhoHasAccessController.getUserAccess";

// jsdom has no canvas; the renderer falls back to estimated text widths
HTMLCanvasElement.prototype.getContext = () => null;

jest.mock(
  "@salesforce/apex/WhoHasAccessController.getAccessTree",
  () => ({ default: jest.fn() }),
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

// The real UMD bundle that ships as the static resource
window.d3 = require("../../../staticresources/d3.js");

const RECORD_ID = "001000000000001AAA";
const TREE = {
  type: "RECORD",
  id: RECORD_ID,
  name: "Acme Corp",
  subtitle: "Account · Internal OWD: Private",
  children: [
    {
      type: "CATEGORY",
      name: "Record Sharing (AccountShare)",
      children: [
        {
          type: "ROWCAUSE",
          name: "Sharing Rule",
          count: 1,
          children: [
            {
              type: "GROUP",
              id: "00G000000000001AAA",
              name: "Public Group: US East",
              accessLevel: "Read Only",
              lazy: true,
              expandType: "GROUP",
              expandId: "00G000000000001AAA"
            }
          ]
        }
      ]
    }
  ]
};

const flush = async () => {
  for (let i = 0; i < 5; i++) {
    // eslint-disable-next-line no-await-in-loop
    await Promise.resolve();
  }
};

function textsIn(element) {
  return Array.from(element.shadowRoot.querySelectorAll("text.wha-name")).map(
    (t) => t.textContent
  );
}

describe("c-who-has-access", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders the access tree returned by Apex", async () => {
    getAccessTree.mockResolvedValue(TREE);
    const element = createElement("c-who-has-access", { is: WhoHasAccess });
    element.recordId = RECORD_ID;
    document.body.appendChild(element);
    await flush();

    expect(getAccessTree).toHaveBeenCalledWith({ recordId: RECORD_ID });
    const names = textsIn(element);
    expect(names).toContain("Acme Corp");
    expect(names).toContain("Sharing Rule");
    // count is rendered in its own pill
    expect(element.shadowRoot.querySelector("g.wha-count text")).not.toBeNull();
    // depth >= 2 children start collapsed
    expect(names).not.toContain("Public Group: US East");
    expect(element.shadowRoot.querySelector(".root-name").textContent).toBe(
      "Acme Corp"
    );
  });

  it("lazily expands a group when its dot is clicked", async () => {
    getAccessTree.mockResolvedValue(TREE);
    expandNode.mockResolvedValue([
      { type: "USER", id: "005000000000001AAA", name: "Bob Jones" }
    ]);
    const element = createElement("c-who-has-access", { is: WhoHasAccess });
    element.recordId = RECORD_ID;
    document.body.appendChild(element);
    await flush();

    const nodeFor = (label) =>
      Array.from(element.shadowRoot.querySelectorAll("g.wha-node")).find((g) =>
        g.querySelector("text.wha-name").textContent.startsWith(label)
      );

    nodeFor("Sharing Rule")
      .querySelector("g.wha-toggle")
      .dispatchEvent(new MouseEvent("click", { bubbles: true }));
    await flush();
    expect(textsIn(element)).toContain("Public Group: US East");

    nodeFor("Public Group")
      .querySelector("g.wha-toggle")
      .dispatchEvent(new MouseEvent("click", { bubbles: true }));
    await flush();

    expect(expandNode).toHaveBeenCalledWith({
      expandType: "GROUP",
      expandId: "00G000000000001AAA",
      recordId: RECORD_ID
    });
    expect(textsIn(element)).toContain("Bob Jones");
  });

  it("shows details and effective access for a selected user", async () => {
    getAccessTree.mockResolvedValue({
      ...TREE,
      children: [
        {
          type: "USER",
          id: "005000000000001AAA",
          name: "Bob Jones",
          subtitle: "Standard User"
        }
      ]
    });
    getUserAccess.mockResolvedValue({
      userName: "Bob Jones",
      isActive: true,
      maxAccess: "Read Only",
      recordRead: true,
      objRead: true
    });
    const element = createElement("c-who-has-access", { is: WhoHasAccess });
    element.recordId = RECORD_ID;
    document.body.appendChild(element);
    await flush();

    const label = Array.from(
      element.shadowRoot.querySelectorAll("g.wha-label")
    ).find((g) => g.textContent.includes("Bob Jones"));
    label.dispatchEvent(new MouseEvent("click", { bubbles: true }));
    await flush();

    const details = element.shadowRoot.querySelector("aside.details");
    expect(details).not.toBeNull();
    expect(details.querySelector(".details-name").textContent).toBe(
      "Bob Jones"
    );

    const checkBtn = Array.from(
      details.querySelectorAll("lightning-button")
    ).find((b) => b.label === "Check effective access");
    checkBtn.click();
    await flush();

    expect(getUserAccess).toHaveBeenCalledWith({
      userId: "005000000000001AAA",
      recordId: RECORD_ID
    });
    expect(details.textContent).toContain("Read Only");
  });

  it("shows the Apex error message", async () => {
    getAccessTree.mockRejectedValue({
      body: { message: "You need the Who Has Access permission set" }
    });
    const element = createElement("c-who-has-access", { is: WhoHasAccess });
    element.recordId = RECORD_ID;
    document.body.appendChild(element);
    await flush();

    const alert = element.shadowRoot.querySelector('[role="alert"]');
    expect(alert.textContent).toContain("Who Has Access permission set");
  });

  it("offers a record Id input when not on a record page", async () => {
    const element = createElement("c-who-has-access", { is: WhoHasAccess });
    document.body.appendChild(element);
    await flush();
    expect(element.shadowRoot.querySelector(".manual-input")).not.toBeNull();
    expect(getAccessTree).not.toHaveBeenCalled();
  });

  it("switches node style without losing the tree", async () => {
    getAccessTree.mockResolvedValue(TREE);
    const element = createElement("c-who-has-access", { is: WhoHasAccess });
    element.recordId = RECORD_ID;
    document.body.appendChild(element);
    await flush();

    const badges = () =>
      Array.from(element.shadowRoot.querySelectorAll("rect.wha-badge")).filter(
        (r) => r.getAttribute("display") !== "none"
      ).length;
    expect(badges()).toBeGreaterThan(0); // cards show icon badges

    const group = element.shadowRoot.querySelector("lightning-radio-group");
    expect(group.options.map((o) => o.value)).toEqual([
      "cards",
      "tonal",
      "minimal"
    ]);
    group.dispatchEvent(
      new CustomEvent("change", { detail: { value: "minimal" } })
    );
    await flush();

    expect(badges()).toBe(0); // minimal: dot + title only
    expect(textsIn(element)).toContain("Acme Corp");
    expect(textsIn(element)).toContain("Sharing Rule (1)"); // count inline
  });

  it("loads the next page as siblings when 'Load more' is expanded", async () => {
    getAccessTree.mockResolvedValue({
      type: "RECORD",
      id: RECORD_ID,
      name: "Acme Corp",
      children: [
        {
          type: "CATEGORY",
          name: "Record Sharing",
          children: [
            { type: "USER", id: "005000000000001AAA", name: "User 1" },
            {
              type: "MORE",
              name: "Load next 200",
              lazy: true,
              expandType: "SHARE_ROWS",
              expandId: "Manual>0Sh000000000001AAA"
            }
          ]
        }
      ]
    });
    expandNode.mockResolvedValue([
      { type: "USER", id: "005000000000002AAA", name: "User 2" }
    ]);
    const element = createElement("c-who-has-access", { is: WhoHasAccess });
    element.recordId = RECORD_ID;
    document.body.appendChild(element);
    await flush();

    const more = Array.from(
      element.shadowRoot.querySelectorAll("g.wha-node")
    ).find((g) => g.textContent.includes("Load next"));
    more
      .querySelector("g.wha-toggle")
      .dispatchEvent(new MouseEvent("click", { bubbles: true }));
    await flush();

    expect(expandNode).toHaveBeenCalledWith({
      expandType: "SHARE_ROWS",
      expandId: "Manual>0Sh000000000001AAA",
      recordId: RECORD_ID
    });
    const names = textsIn(element);
    expect(names).toContain("User 2");
    expect(names).not.toContain("Load next 200");
  });

  it("searches loaded nodes and steps through matches with Enter", async () => {
    getAccessTree.mockResolvedValue(TREE);
    const element = createElement("c-who-has-access", { is: WhoHasAccess });
    element.recordId = RECORD_ID;
    document.body.appendChild(element);
    await flush();

    const search = element.shadowRoot.querySelector(".search lightning-input");
    search.value = "e"; // matches several loaded nodes, incl. collapsed ones
    search.dispatchEvent(new CustomEvent("change"));
    await flush();
    const label = () =>
      element.shadowRoot.querySelector(".match-count").textContent;
    expect(label()).toMatch(/^1 of \d+ · Enter for next$/);
    // the collapsed group was opened so the match is visible
    expect(textsIn(element)).toContain("Public Group: US East");

    search.dispatchEvent(new KeyboardEvent("keyup", { key: "Enter" }));
    await flush();
    expect(label()).toMatch(/^2 of \d+/);
  });

  it("reduces error shapes", () => {
    expect(reduceError({ body: [{ message: "a" }, { message: "b" }] })).toBe(
      "a, b"
    );
    expect(reduceError(new Error("boom"))).toBe("boom");
    expect(reduceError(undefined)).toBe("Unknown error");
  });
});
