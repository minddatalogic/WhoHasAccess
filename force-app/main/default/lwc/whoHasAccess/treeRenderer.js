/**
 * D3 collapsible, lazily-expanding horizontal tree, styled with SLDS 2 (Cosmos)
 * global styling hooks so it follows the org theme and dark mode.
 * Kept free of LWC APIs so it can be unit tested and reused.
 *
 * Three node styles (switchable at runtime):
 *   cards   — white SLDS-card nodes with a tonal icon badge and count pill
 *   tonal   — filled pill per type (palette-*-90 container, *-50 accent)
 *   minimal — dot + title, the lightest option for very large trees
 */

const hook = (name, fallback) => `var(--slds-g-${name}, ${fallback})`;

/** SLDS 2 palette hue -> [accent (50), container (90)] with light-mode fallbacks. */
const HUES = {
  blue: ["#0176d3", "#d8e6fe"],
  cloud: ["#107cad", "#cfe9fe"],
  teal: ["#0b827c", "#acf3e4"],
  green: ["#2e844a", "#cdefc4"],
  orange: ["#a96404", "#fedfd0"],
  indigo: ["#5867e8", "#e0e5f8"],
  purple: ["#9050e9", "#ece1f9"],
  violet: ["#ba01ff", "#f2defe"],
  pink: ["#e3066a", "#fddde3"],
  neutral: ["#757575", "#e5e5e5"]
};
const HOOK_HUE = { cloud: "cloud-blue" };

function hueColor(hue, shade) {
  const [base, container] = HUES[hue] || HUES.neutral;
  const name = HOOK_HUE[hue] || hue;
  return hook(
    `color-palette-${name}-${shade}`,
    shade === 50 ? base : container
  );
}

export const TYPE_STYLES = {
  RECORD: { hue: "blue", icon: "record", label: "Record" },
  CATEGORY: { hue: "neutral", icon: "layers", label: "Branch" },
  ROWCAUSE: { hue: "cloud", icon: "share", label: "Row Cause" },
  USER: { hue: "indigo", icon: "user", label: "User" },
  GROUP: { hue: "orange", icon: "groups", label: "Group / Queue" },
  ROLE: { hue: "teal", icon: "hierarchy", label: "Role" },
  PROFILE: { hue: "pink", icon: "identity", label: "Profile" },
  PERMSET: { hue: "violet", icon: "lock", label: "Permission Set" },
  PSG: { hue: "purple", icon: "package", label: "Permission Set Group" },
  PARENT: { hue: "green", icon: "level_up", label: "Parent Record" },
  INFO: { hue: "neutral", icon: "info", label: "Info" },
  MORE: { hue: "neutral", icon: "info", label: "More" }
};

/** Theme tokens used by the canvas (SLDS 2 hooks + SLDS 1 fallbacks). */
export const TOKENS = {
  surface: hook("color-surface-container-1", "#ffffff"),
  surfaceAlt: hook("color-surface-container-3", "#e5e5e5"),
  onSurface: hook("color-on-surface-2", "#2e2e2e"),
  onSurfaceWeak: hook("color-on-surface-1", "#5c5c5c"),
  border: hook("color-border-1", "#c9c9c9"),
  accent: hook("color-accent-1", "#066afe"),
  accentContainer: hook("color-brand-base-95", "#edf4ff"),
  warning: hook("color-warning-base-60", "#ca8501"),
  link: hook("color-border-1", "#c9c9c9")
};

/** Colours for a node type, as CSS values (hooks with fallbacks). */
export function typeColors(type) {
  const s = TYPE_STYLES[type] || TYPE_STYLES.INFO;
  return {
    accent: hueColor(s.hue, 50),
    container: hueColor(s.hue, 90),
    icon: s.icon,
    label: s.label
  };
}

export const NODE_STYLES = ["cards", "tonal", "minimal"];

const LAYOUT = {
  cards: { dx: 40, dy: 320, height: 30 },
  tonal: { dx: 38, dy: 320, height: 28 },
  minimal: { dx: 26, dy: 290, height: 0 }
};

const NAME_MAX = 36;
const ICON_SPRITE = "/_slds/icons/utility-sprite/svg/symbols.svg#";

function truncate(text, max) {
  if (!text) {
    return "";
  }
  return text.length > max ? `${text.slice(0, max - 1)}…` : text;
}

/** Walks every node, including collapsed (_children) ones. */
function walk(node, fn) {
  fn(node);
  const kids = node.children || node._children;
  if (kids) {
    kids.forEach((k) => walk(k, fn));
  }
}

export class AccessTreeRenderer {
  constructor(d3, container, { onExpand, onSelect, onError, style } = {}) {
    this.d3 = d3;
    this.container = container;
    this.onExpand = onExpand;
    this.onSelect = onSelect;
    this.onError = onError;
    this.uid = 0;
    this.duration = 250;
    this.term = "";
    this.selectedId = null;
    this.style = NODE_STYLES.includes(style) ? style : "cards";

    this.svg = d3
      .select(container)
      .append("svg")
      .attr("width", "100%")
      .attr("height", "100%")
      .attr("role", "tree")
      .style("display", "block")
      .style("font-family", hook("font-family", "inherit"))
      .style("cursor", "grab");
    this.viewport = this.svg.append("g");
    this.linkLayer = this.viewport
      .append("g")
      .attr("fill", "none")
      .style("stroke", TOKENS.link)
      .attr("stroke-width", 1.25);
    this.nodeLayer = this.viewport.append("g");

    this.zoom = d3
      .zoom()
      .scaleExtent([0.15, 2.5])
      .on("zoom", (event) => this.viewport.attr("transform", event.transform));
    this.svg.call(this.zoom).on("dblclick.zoom", null);

    this.applyLayout();
  }

  applyLayout() {
    const l = LAYOUT[this.style];
    this.dx = l.dx;
    this.dy = l.dy;
    this.nodeHeight = l.height;
    this.layout = this.d3
      .tree()
      .nodeSize([this.dx, this.dy])
      .separation((a, b) => (a.parent === b.parent ? 1 : 1.25));
  }

  /** Switch node style; rebuilds the drawing but keeps expansion state. */
  setStyle(style) {
    if (!NODE_STYLES.includes(style) || style === this.style) {
      return;
    }
    this.style = style;
    this.applyLayout();
    this.nodeLayer.selectAll("*").remove();
    this.linkLayer.selectAll("*").remove();
    if (this.root) {
      this.root.each((d) => {
        d.x0 = d.x;
        d.y0 = d.y;
      });
      this.update(this.root, true);
      this.fit(false);
    }
  }

  // ------------------------------------------------------------------ data
  setData(data) {
    this.clear();
    this.root = this.d3.hierarchy(data);
    this.root.descendants().forEach((n) => {
      n.id = ++this.uid;
      // show record -> branches -> first grouping; collapse the rest
      if (n.depth >= 2 && n.children) {
        n._children = n.children;
        n.children = null;
      }
    });
    this.root.x0 = 0;
    this.root.y0 = 0;
    this.update(this.root, true);
    this.fit(false);
  }

  clear() {
    this.nodeLayer.selectAll("*").remove();
    this.linkLayer.selectAll("*").remove();
    this.root = null;
    this.selectedId = null;
  }

  attachChildren(parent, list) {
    const items =
      list && list.length ? list : [{ type: "INFO", name: "Nothing found" }];
    parent.data.children = items;
    parent.children = items.map((item) => {
      const h = this.d3.hierarchy(item);
      h.descendants().forEach((n) => {
        n.depth += parent.depth + 1;
        n.id = ++this.uid;
      });
      h.parent = parent;
      return h;
    });
    parent._children = null;
  }

  /** Swaps a "Load more" node for the next page of siblings; returns the parent. */
  appendPage(moreNode, list) {
    const parent = moreNode.parent;
    const siblings = parent.children || parent._children || [];
    const at = siblings.indexOf(moreNode);
    const fresh = (list || []).map((item) => {
      const h = this.d3.hierarchy(item);
      h.descendants().forEach((n) => {
        n.depth += parent.depth + 1;
        n.id = ++this.uid;
      });
      h.parent = parent;
      return h;
    });
    siblings.splice(at < 0 ? siblings.length : at, at < 0 ? 0 : 1, ...fresh);
    const dataKids = parent.data.children || [];
    const dataAt = dataKids.indexOf(moreNode.data);
    dataKids.splice(
      dataAt < 0 ? dataKids.length : dataAt,
      dataAt < 0 ? 0 : 1,
      ...(list || [])
    );
    parent.data.children = dataKids;
    if (parent.children) {
      parent.children = siblings;
    } else {
      parent._children = siblings;
    }
    return parent;
  }

  isExpandable(d) {
    return Boolean(
      d.children || d._children || (d.data.lazy && !d.data.loaded)
    );
  }

  // --------------------------------------------------------------- actions
  async toggle(d) {
    if (d.children) {
      d._children = d.children;
      d.children = null;
      this.update(d);
      return;
    }
    if (d._children) {
      d.children = d._children;
      d._children = null;
      this.update(d);
      this.reveal(d);
      return;
    }
    if (d.data.lazy && !d.data.loaded && !d.data.loading && this.onExpand) {
      d.data.loading = true;
      this.update(d);
      try {
        const kids = await this.onExpand(d.data);
        if (d.data.type === "MORE" && d.parent) {
          // next page: replace the "Load more" node with the new siblings
          const parent = this.appendPage(d, kids);
          this.update(parent);
          return;
        }
        this.attachChildren(d, kids);
        d.data.loaded = true;
      } catch (e) {
        if (this.onError) {
          this.onError(e);
        }
      } finally {
        d.data.loading = false;
        this.update(d);
        this.reveal(d);
      }
    }
  }

  select(d) {
    this.selectedId = d.id;
    this.update(d);
    if (this.onSelect) {
      const path = d
        .ancestors()
        .reverse()
        .map((a) => a.data.name);
      this.onSelect(d.data, path);
    }
  }

  collapseAll() {
    if (!this.root) {
      return;
    }
    walk(this.root, (n) => {
      if (n.depth >= 1 && n.children) {
        n._children = n.children;
        n.children = null;
      }
    });
    this.update(this.root);
    this.fit();
  }

  /** Expands everything already loaded (never triggers server calls). */
  expandLoaded() {
    if (!this.root) {
      return;
    }
    walk(this.root, (n) => {
      if (n._children) {
        n.children = n._children;
        n._children = null;
      }
    });
    this.update(this.root);
    this.fit();
  }

  /**
   * Highlights loaded nodes whose name matches, opens their ancestors and
   * centres the first match. Call nextMatch() to step through the rest.
   */
  highlight(term) {
    this.term = (term || "").trim().toLowerCase();
    this.matches = [];
    this.matchIndex = 0;
    if (!this.root) {
      return 0;
    }
    if (this.term) {
      walk(this.root, (n) => {
        if ((n.data.name || "").toLowerCase().includes(this.term)) {
          this.matches.push(n);
          let p = n.parent;
          while (p) {
            if (p._children) {
              p.children = p._children;
              p._children = null;
            }
            p = p.parent;
          }
        }
      });
    }
    this.update(this.root, true);
    if (this.matches.length) {
      this.centerOn(this.matches[0]);
    }
    return this.matches.length;
  }

  /** Centres the next match (wraps around); returns its 1-based position. */
  nextMatch() {
    if (!this.matches || !this.matches.length) {
      return 0;
    }
    this.matchIndex = (this.matchIndex + 1) % this.matches.length;
    this.centerOn(this.matches[this.matchIndex]);
    return this.matchIndex + 1;
  }

  /** Pans (keeping the zoom level) so node d sits in the middle of the canvas. */
  centerOn(d) {
    const w = this.container.clientWidth;
    const h = this.container.clientHeight;
    if (!w || !h || !this.svg.node() || d.x === undefined) {
      return;
    }
    const t = this.d3.zoomTransform(this.svg.node());
    const k = Math.max(t.k, 0.75); // zoom in enough to read the match
    const cx = d.y + (d.w || 0) / 2;
    const transform = this.d3.zoomIdentity
      .translate(w / 2 - cx * k, h / 2 - d.x * k)
      .scale(k);
    this.svg.transition().duration(450).call(this.zoom.transform, transform);
  }

  /** Pans so a just-expanded node and its children's labels are on screen. */
  reveal(d) {
    const w = this.container.clientWidth;
    const h = this.container.clientHeight;
    if (!w || !h || !this.svg.node()) {
      return;
    }
    const t = this.d3.zoomTransform(this.svg.node());
    const nodeX = t.applyX(d.y);
    const nodeY = t.applyY(d.x);
    const next = d.depth + 1;
    const childRightX =
      this.colX && this.colX[next] !== undefined
        ? this.colX[next] + this.colW[next] + 24
        : d.y + (d.w || 0) + 300;
    const childrenRight = t.applyX(childRightX);
    let shiftX = 0;
    let shiftY = 0;
    if (childrenRight > w || nodeX < 0) {
      // keep the expanded node visible, but bring its children fully on screen
      const wanted = w - 16 - childrenRight;
      shiftX = Math.max(wanted, 16 - nodeX) / t.k;
    }
    if (nodeY < 40 || nodeY > h - 40) {
      shiftY = (h / 2 - nodeY) / t.k;
    }
    if (shiftX || shiftY) {
      this.svg
        .transition()
        .duration(400)
        .call(this.zoom.translateBy, shiftX, shiftY);
    }
  }

  fit(animate = true) {
    if (!this.root) {
      return;
    }
    const w = this.container.clientWidth;
    const h = this.container.clientHeight;
    if (!w || !h) {
      return;
    }
    let minX = Infinity;
    let maxX = -Infinity;
    let maxRight = 0;
    this.root.each((n) => {
      minX = Math.min(minX, n.x);
      maxX = Math.max(maxX, n.x);
      maxRight = Math.max(maxRight, n.y + (n.w || 0) + 12);
    });
    const pad = 24;
    const contentW = maxRight + pad * 2;
    const contentH = maxX - minX + this.dx * 2 + pad * 2;
    const scale = Math.max(
      0.15,
      Math.min(1.1, Math.min(w / contentW, h / contentH))
    );
    const tx = pad + 16 * scale;
    const ty = h / 2 - ((minX + maxX) / 2) * scale;
    const transform = this.d3.zoomIdentity.translate(tx, ty).scale(scale);
    if (animate) {
      this.svg.transition().duration(400).call(this.zoom.transform, transform);
    } else {
      this.svg.call(this.zoom.transform, transform);
    }
  }

  // ---------------------------------------------------------------- render
  titleFor(d) {
    let text = truncate(d.data.name, NAME_MAX);
    if (d.data.loading) {
      text += " …";
    }
    if (this.style === "minimal" && d.data.count != null) {
      text += ` (${d.data.count})`;
    }
    return text;
  }

  hasCount(d) {
    return this.style !== "minimal" && d.data.count != null;
  }

  isMatch(d) {
    return Boolean(
      this.term && (d.data.name || "").toLowerCase().includes(this.term)
    );
  }

  /** Text width via canvas metrics (no DOM layout needed); estimate as fallback. */
  textWidth(text, weight) {
    if (this.ctx === undefined) {
      try {
        this.ctx = document.createElement("canvas").getContext("2d");
      } catch {
        this.ctx = null;
      }
      this.font = window.getComputedStyle
        ? window.getComputedStyle(this.container).fontFamily || "sans-serif"
        : "sans-serif";
    }
    if (this.ctx) {
      this.ctx.font = `${weight} 13px ${this.font}`;
      const w = this.ctx.measureText(text).width;
      if (w) {
        return w;
      }
    }
    return text.length * 7.2;
  }

  /** Width of a node body (badge + title + count pill + padding). */
  nodeWidth(d) {
    const weight = d.depth === 0 ? 700 : this.style === "minimal" ? 400 : 500;
    const textW = this.textWidth(this.titleFor(d), weight);
    if (this.style === "minimal") {
      return { textW, countW: 0, w: 12 + textW + 6 };
    }
    const countText = this.hasCount(d) ? String(d.data.count) : "";
    const countW = countText ? Math.max(20, countText.length * 7 + 12) : 0;
    return { textW, countW, w: 34 + textW + (countW ? countW + 8 : 0) + 12 };
  }

  /** Columns sized to their widest node, so nothing overlaps. */
  assignColumns(nodes) {
    const gap = this.style === "minimal" ? 44 : 64;
    const colW = [];
    nodes.forEach((d) => {
      const m = this.nodeWidth(d);
      d.textW = m.textW;
      d.countW = m.countW;
      d.w = m.w;
      colW[d.depth] = Math.max(colW[d.depth] || 0, d.w);
    });
    const colX = [0];
    for (let i = 1; i < colW.length; i++) {
      colX[i] = colX[i - 1] + colW[i - 1] + gap;
    }
    nodes.forEach((d) => {
      d.y = colX[d.depth];
    });
    this.colX = colX;
    this.colW = colW;
    this.gap = gap;
  }

  /** Where links leave a node (its right edge, past the toggle). */
  anchorX(d) {
    if (this.style === "minimal") {
      return d.y + (d.w || 0);
    }
    return d.y + (d.w || 0) + (this.isExpandable(d) ? 9 : 0);
  }

  update(source, instant = false) {
    if (!this.root) {
      return;
    }
    const d3 = this.d3;
    const style = this.style;
    const h = this.nodeHeight;
    const self = this;
    this.layout(this.root);
    const nodes = this.root.descendants();
    const links = this.root.links();
    this.assignColumns(nodes);
    const reduceMotion =
      typeof window !== "undefined" &&
      window.matchMedia &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const animate = !instant && !reduceMotion;
    const t = animate ? this.svg.transition().duration(this.duration) : null;
    const tr = (sel) => (t ? sel.transition(t) : sel);

    // ---- nodes
    const node = this.nodeLayer
      .selectAll("g.wha-node")
      .data(nodes, (d) => d.id);

    const enter = node
      .enter()
      .append("g")
      .attr("class", "wha-node")
      .attr("role", "treeitem")
      .attr(
        "transform",
        animate
          ? `translate(${source.y0},${source.x0})`
          : (d) => `translate(${d.y},${d.x})`
      )
      .attr("opacity", animate ? 0 : 1);

    // selectable body (card / pill / label)
    const body = enter
      .append("g")
      .attr("class", "wha-label")
      .style("cursor", "pointer")
      .on("click", (event, d) => {
        event.stopPropagation();
        this.select(d);
      })
      .on("dblclick", (event, d) => {
        event.stopPropagation();
        this.toggle(d);
      });

    body
      .append("rect")
      .attr("class", "wha-shape")
      .attr("y", -h / 2)
      .attr("height", h);
    body
      .append("rect")
      .attr("class", "wha-badge")
      .attr("width", 20)
      .attr("height", 20)
      .attr("y", -10)
      .attr("rx", 6);
    body
      .append("use")
      .attr("class", "wha-icon")
      .attr("width", 12)
      .attr("height", 12)
      .attr("y", -6);
    body
      .append("text")
      .attr("class", "wha-name")
      .attr("dy", "0.35em")
      .attr("font-size", 13);
    const pill = body.append("g").attr("class", "wha-count");
    pill.append("rect").attr("height", 18).attr("y", -9).attr("rx", 4);
    pill
      .append("text")
      .attr("dy", "0.35em")
      .attr("font-size", 11)
      .attr("text-anchor", "middle");

    // expand / collapse control
    const toggle = enter
      .append("g")
      .attr("class", "wha-toggle")
      .style("cursor", "pointer")
      .on("click", (event, d) => {
        event.stopPropagation();
        this.toggle(d);
      });
    toggle.append("circle").attr("r", style === "minimal" ? 6 : 8);
    toggle
      .append("text")
      .attr("text-anchor", "middle")
      .attr("dy", "0.35em")
      .attr("font-size", 12)
      .attr("font-weight", 700);

    enter.append("title");

    const merged = enter.merge(node);
    tr(merged)
      .attr("transform", (d) => `translate(${d.y},${d.x})`)
      .attr("opacity", 1);

    // text first, so widths can be measured
    merged
      .select("text.wha-name")
      .text((d) => this.titleFor(d))
      .style("fill", (d) => {
        return this.isMatch(d) ? TOKENS.warning : TOKENS.onSurface;
      })
      .attr("font-weight", (d) => {
        if (d.depth === 0) {
          return 700;
        }
        if (style !== "minimal") {
          return 500; // boxes are sized for this weight; outline marks state
        }
        return d.id === this.selectedId || this.isMatch(d) ? 700 : 400;
      });

    merged.each(function (d) {
      const g = d3.select(this);
      const colors = typeColors(d.data.type);
      const textW = d.textW;
      const iconSpace = style === "minimal" ? 12 : 34;
      const countText = self.hasCount(d) ? String(d.data.count) : "";
      const countW = d.countW;
      const selected = d.id === self.selectedId;
      const match = self.isMatch(d);

      // body shape
      const shape = g.select("rect.wha-shape");
      if (style === "minimal") {
        shape
          .attr("x", 8)
          .attr("y", -11)
          .attr("height", 22)
          .attr("rx", 4)
          .attr("width", textW + 10)
          .style("fill", selected ? TOKENS.accentContainer : "transparent")
          .style("stroke", "none");
      } else {
        shape
          .attr("x", 0)
          .attr("width", d.w)
          .attr("rx", 6)
          .style("fill", style === "tonal" ? colors.container : TOKENS.surface)
          .style(
            "stroke",
            selected
              ? TOKENS.accent
              : match
                ? TOKENS.warning
                : style === "tonal"
                  ? "transparent"
                  : TOKENS.border
          )
          .attr("stroke-width", selected || match ? 2 : 1);
      }

      // icon badge
      g.select("rect.wha-badge")
        .attr("x", 6)
        .attr("display", style === "cards" ? null : "none")
        .style("fill", colors.container);
      g.select("use.wha-icon")
        .attr("href", ICON_SPRITE + colors.icon)
        .attr("x", style === "minimal" ? -6 : 10)
        .attr("display", style === "minimal" ? "none" : null)
        .style("fill", colors.accent);

      g.select("text.wha-name").attr("x", iconSpace);

      // count pill
      const countG = g
        .select("g.wha-count")
        .attr("display", countW ? null : "none")
        .attr("transform", `translate(${iconSpace + textW + 8},0)`);
      countG
        .select("rect")
        .attr("width", countW)
        .style("fill", style === "tonal" ? TOKENS.surface : TOKENS.surfaceAlt);
      countG
        .select("text")
        .attr("x", countW / 2)
        .text(countText)
        .style("fill", TOKENS.onSurfaceWeak);

      // toggle
      const expandable = self.isExpandable(d);
      const open = Boolean(d.children);
      const tg = g
        .select("g.wha-toggle")
        .attr("display", expandable || style === "minimal" ? null : "none")
        .attr("transform", `translate(${style === "minimal" ? 0 : d.w},0)`);
      tg.select("circle")
        .style(
          "fill",
          style === "minimal"
            ? expandable && !open
              ? colors.accent
              : TOKENS.surface
            : TOKENS.surface
        )
        .style("stroke", style === "minimal" ? colors.accent : TOKENS.border)
        .attr("stroke-width", style === "minimal" ? 2 : 1);
      tg.select("text")
        .text(style === "minimal" ? "" : open ? "−" : "+")
        .style("fill", TOKENS.accent);
      g.attr("aria-expanded", expandable ? String(open) : null);
    });

    merged
      .select("title")
      .text((d) =>
        [
          d.data.name,
          d.data.accessLevel,
          d.data.subtitle,
          this.isExpandable(d) ? "Click + to expand" : null
        ]
          .filter(Boolean)
          .join("\n")
      );

    if (t) {
      node
        .exit()
        .transition(t)
        .attr("transform", `translate(${source.y},${source.x})`)
        .attr("opacity", 0)
        .remove();
    } else {
      node.exit().remove();
    }

    // ---- links (from the parent's right edge to the child's left edge)
    const diagonal = d3
      .linkHorizontal()
      .x((p) => p.y)
      .y((p) => p.x);
    const path = (l) =>
      diagonal({
        source: { x: l.source.x, y: this.anchorX(l.source) },
        target: { x: l.target.x, y: l.target.y }
      });
    const link = this.linkLayer
      .selectAll("path")
      .data(links, (l) => l.target.id);

    const linkEnter = link
      .enter()
      .append("path")
      .attr("d", (l) => {
        if (!animate) {
          return path(l);
        }
        const o = { x: source.x0, y: source.y0 };
        return diagonal({ source: o, target: o });
      });

    tr(link.merge(linkEnter)).attr("d", path);

    if (t) {
      link
        .exit()
        .transition(t)
        .attr("d", () => {
          const o = { x: source.x, y: this.anchorX(source) };
          return diagonal({ source: o, target: o });
        })
        .remove();
    } else {
      link.exit().remove();
    }

    this.root.eachBefore((d) => {
      d.x0 = d.x;
      d.y0 = d.y;
    });
  }
}
