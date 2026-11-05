import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { loadScript } from "lightning/platformResourceLoader";
import D3 from "@salesforce/resourceUrl/d3";
import getAccessTree from "@salesforce/apex/WhoHasAccessController.getAccessTree";
import expandNode from "@salesforce/apex/WhoHasAccessController.expandNode";
import getUserAccess from "@salesforce/apex/WhoHasAccessController.getUserAccess";
import { AccessTreeRenderer, NODE_STYLES, typeColors } from "./treeRenderer";

const STYLE_KEY = "whoHasAccess.nodeStyle";
const STYLE_LABELS = { cards: "Cards", tonal: "Tonal", minimal: "Minimal" };

const NAVIGABLE_TYPES = new Set(["RECORD", "USER", "PARENT"]);
const LEGEND_TYPES = [
  "RECORD",
  "ROWCAUSE",
  "USER",
  "GROUP",
  "ROLE",
  "PROFILE",
  "PERMSET",
  "PSG",
  "PARENT"
];

export function reduceError(error) {
  if (!error) {
    return "Unknown error";
  }
  if (Array.isArray(error.body)) {
    return error.body.map((e) => e.message).join(", ");
  }
  if (error.body && typeof error.body.message === "string") {
    return error.body.message;
  }
  if (typeof error.message === "string") {
    return error.message;
  }
  return String(error);
}

export default class WhoHasAccess extends NavigationMixin(LightningElement) {
  /** Canvas height in px (App Builder property). */
  @api height = 620;
  /** Default node style: cards | tonal | minimal (App Builder property). */
  @api nodeStyle = "cards";

  currentStyle;

  _recordId;
  activeRecordId;
  manualRecordId = "";
  history = [];

  d3Requested = false;
  renderer;
  isLoading = false;
  error;
  rootInfo;
  searchTerm = "";
  matchCount;
  matchPosition;

  selected;
  selectedPath = [];
  userAccess;
  userAccessLoading = false;
  userAccessError;

  @api
  get recordId() {
    return this._recordId;
  }
  set recordId(value) {
    this._recordId = value;
    if (value && value !== this.activeRecordId) {
      this.activeRecordId = value;
      this.history = [];
      if (this.renderer) {
        this.loadTree();
      }
    }
  }

  // ------------------------------------------------------------ lifecycle
  renderedCallback() {
    if (this.d3Requested) {
      return;
    }
    this.d3Requested = true;
    loadScript(this, D3)
      .then(() => {
        const d3 = window.d3;
        this.renderer = new AccessTreeRenderer(d3, this.refs.canvas, {
          style: this.activeStyle,
          onExpand: (data) => this.fetchChildren(data),
          onSelect: (data, path) => this.handleNodeSelected(data, path),
          onError: (e) => {
            this.error = reduceError(e);
          }
        });
        if (this.activeRecordId) {
          this.loadTree();
        }
      })
      .catch((e) => {
        this.error = "Could not load D3: " + reduceError(e);
      });
  }

  // ----------------------------------------------------------------- data
  async loadTree() {
    if (!this.renderer || !this.activeRecordId) {
      return;
    }
    this.isLoading = true;
    this.error = undefined;
    this.clearSelection();
    try {
      const data = await getAccessTree({ recordId: this.activeRecordId });
      // Apex results can be read-only proxies; D3 mutates nodes, so clone.
      const tree = JSON.parse(JSON.stringify(data));
      this.rootInfo = { name: tree.name, subtitle: tree.subtitle };
      this.renderer.setData(tree);
      if (this.searchTerm) {
        this.matchCount = this.renderer.highlight(this.searchTerm);
      }
    } catch (e) {
      this.rootInfo = undefined;
      this.renderer.clear();
      this.error = reduceError(e);
    } finally {
      this.isLoading = false;
    }
  }

  async fetchChildren(data) {
    const kids = await expandNode({
      expandType: data.expandType,
      expandId: data.expandId,
      recordId: this.activeRecordId
    });
    return JSON.parse(JSON.stringify(kids || []));
  }

  handleNodeSelected(data, path) {
    this.selected = {
      id: data.id,
      name: data.name,
      type: data.type,
      subtitle: data.subtitle,
      accessLevel: data.accessLevel,
      count: data.count
    };
    this.selectedPath = path.map((label, i) => ({ key: `${i}`, label }));
    this.userAccess = undefined;
    this.userAccessError = undefined;
  }

  clearSelection() {
    this.selected = undefined;
    this.selectedPath = [];
    this.userAccess = undefined;
    this.userAccessError = undefined;
  }

  // -------------------------------------------------------------- toolbar
  handleRefresh() {
    this.loadTree();
  }

  handleFit() {
    this.renderer?.fit();
  }

  handleCollapse() {
    this.renderer?.collapseAll();
  }

  handleExpand() {
    this.renderer?.expandLoaded();
  }

  handleSearch(event) {
    this.searchTerm = event.target.value;
    this.matchPosition = this.searchTerm ? 1 : undefined;
    if (this.renderer) {
      const n = this.renderer.highlight(this.searchTerm);
      this.matchCount = this.searchTerm ? n : undefined;
    }
  }

  /** Enter in the search box jumps to the next match. */
  handleSearchKeyUp(event) {
    if (event.key === "Enter" && this.renderer && this.matchCount) {
      this.matchPosition = this.renderer.nextMatch();
    }
  }

  handleManualIdChange(event) {
    this.manualRecordId = (event.target.value || "").trim();
  }

  handleManualAnalyse() {
    if (!this.manualRecordId) {
      return;
    }
    this.history = [];
    this.activeRecordId = this.manualRecordId;
    this.loadTree();
  }

  handleManualKeyUp(event) {
    if (event.key === "Enter") {
      this.handleManualAnalyse();
    }
  }

  handleBack() {
    if (!this.history.length) {
      return;
    }
    const previous = this.history[this.history.length - 1];
    this.history = this.history.slice(0, -1);
    this.activeRecordId = previous;
    this.loadTree();
  }

  // -------------------------------------------------------- details panel
  handleCloseDetails() {
    this.clearSelection();
  }

  handleOpenRecord() {
    if (!this.selected?.id) {
      return;
    }
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: { recordId: this.selected.id, actionName: "view" }
    });
  }

  handleAnalyseParent() {
    if (!this.selected?.id) {
      return;
    }
    this.history = [...this.history, this.activeRecordId];
    this.activeRecordId = this.selected.id;
    this.loadTree();
  }

  async handleCheckAccess() {
    if (!this.selected?.id) {
      return;
    }
    this.userAccessLoading = true;
    this.userAccessError = undefined;
    try {
      this.userAccess = await getUserAccess({
        userId: this.selected.id,
        recordId: this.activeRecordId
      });
    } catch (e) {
      this.userAccessError = reduceError(e);
    } finally {
      this.userAccessLoading = false;
    }
  }

  // -------------------------------------------------------------- getters
  get canvasStyle() {
    const h = parseInt(this.height, 10) || 620;
    return `height:${h}px`;
  }

  get showRecordInput() {
    return !this._recordId;
  }

  get showEmptyState() {
    return !this.activeRecordId && !this.isLoading;
  }

  get canGoBack() {
    return this.history.length > 0;
  }

  get backDisabled() {
    return !this.canGoBack;
  }

  get hasMatchCount() {
    return this.matchCount !== undefined;
  }

  get matchLabel() {
    if (!this.matchCount) {
      return "No matches";
    }
    if (this.matchCount === 1) {
      return "1 match";
    }
    return `${this.matchPosition || 1} of ${this.matchCount} · Enter for next`;
  }

  get legend() {
    return LEGEND_TYPES.map((type) => {
      const c = typeColors(type);
      return {
        type,
        label: c.label,
        style: `background:${c.container};color:${c.accent}`,
        dotStyle: `background:${c.accent}`
      };
    });
  }

  get selectedTypeLabel() {
    return this.selected ? typeColors(this.selected.type).label : "";
  }

  get selectedBadgeStyle() {
    const c = typeColors(this.selected ? this.selected.type : "INFO");
    return `background:${c.container};color:${c.accent}`;
  }

  // ---------------------------------------------------------- node style
  get activeStyle() {
    if (this.currentStyle) {
      return this.currentStyle;
    }
    let saved;
    try {
      saved = window.localStorage.getItem(STYLE_KEY);
    } catch {
      saved = null;
    }
    const preferred = NODE_STYLES.includes(saved) ? saved : this.nodeStyle;
    return NODE_STYLES.includes(preferred) ? preferred : "cards";
  }

  get styleOptions() {
    return NODE_STYLES.map((value) => ({ label: STYLE_LABELS[value], value }));
  }

  handleStyleChange(event) {
    const style = event.detail.value;
    this.currentStyle = style;
    try {
      window.localStorage.setItem(STYLE_KEY, style);
    } catch {
      // storage unavailable — the choice just isn't remembered
    }
    this.renderer?.setStyle(style);
  }

  get isUserSelected() {
    return this.selected?.type === "USER" && Boolean(this.selected.id);
  }

  get isParentSelected() {
    return this.selected?.type === "PARENT" && Boolean(this.selected.id);
  }

  get canOpenSelected() {
    return Boolean(
      this.selected?.id && NAVIGABLE_TYPES.has(this.selected.type)
    );
  }

  get recordAccessRows() {
    const ua = this.userAccess;
    if (!ua) {
      return [];
    }
    return [
      ["Read", ua.recordRead],
      ["Edit", ua.recordEdit],
      ["Delete", ua.recordDelete],
      ["Transfer", ua.recordTransfer],
      ["Full Access", ua.recordAll]
    ].map(toRow);
  }

  get objectAccessRows() {
    const ua = this.userAccess;
    if (!ua) {
      return [];
    }
    return [
      ["Read", ua.objRead],
      ["Create", ua.objCreate],
      ["Edit", ua.objEdit],
      ["Delete", ua.objDelete],
      ["View All", ua.objViewAll],
      ["Modify All", ua.objModifyAll],
      ["View All Data", ua.viewAllData],
      ["Modify All Data", ua.modifyAllData]
    ].map(toRow);
  }

  get accessWarning() {
    const ua = this.userAccess;
    if (!ua) {
      return null;
    }
    if (!ua.isActive) {
      return "This user is inactive — they cannot log in, so no effective access.";
    }
    if (!ua.objRead) {
      return "No Read permission on this object — sharing alone cannot give this user access.";
    }
    return null;
  }
}

function toRow([label, value]) {
  return {
    key: label,
    label,
    icon: value ? "utility:success" : "utility:close",
    variant: value ? "success" : "error",
    alt: value ? "Yes" : "No"
  };
}
