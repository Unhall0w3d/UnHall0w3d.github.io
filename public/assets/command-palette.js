// Pagefind WASM + Direct Command Actions controller for CommandPalette.astro
(() => {
  const COMMANDS = [
    {
      id: "cmd-theme-aftertone",
      title: "> Theme: Aftertone",
      badge: "DEFAULT DARK",
      keywords: "theme aftertone dark phosphor",
      run: () => window.nocThoughtsTheme?.apply("aftertone", true)
    },
    {
      id: "cmd-theme-paper",
      title: "> Theme: Field Paper",
      badge: "DAYLIGHT",
      keywords: "theme field paper light daylight warm",
      run: () => window.nocThoughtsTheme?.apply("paper", true)
    },
    {
      id: "cmd-theme-polar",
      title: "> Theme: Polar Night",
      badge: "HIGH CONTRAST",
      keywords: "theme polar night blue contrast",
      run: () => window.nocThoughtsTheme?.apply("polar", true)
    },
    {
      id: "cmd-theme-cyberpunk",
      title: "> Theme: Cyberpunk [Legacy]",
      badge: "EASTER EGG",
      keywords: "theme cyberpunk legacy neon",
      run: () => window.nocThoughtsTheme?.apply("cyberpunk", true)
    },
    {
      id: "cmd-theme-moss",
      title: "> Theme: Moss & Brass [Legacy]",
      badge: "EASTER EGG",
      keywords: "theme moss brass legacy green",
      run: () => window.nocThoughtsTheme?.apply("moss-brass", true)
    },
    {
      id: "cmd-toggle-audio",
      title: "> Toggle Ambient Audio",
      badge: "SOUL SLASH",
      keywords: "toggle ambient audio music play pause soul",
      run: () => document.dispatchEvent(new CustomEvent("noc:toggle-ambient-audio"))
    }
  ];

  const QUICK_LINKS = [
    { title: "Field Notes — Signal Archive", url: "/posts.html", badge: "ARCHIVE" },
    { title: "Field Toolbox — Tools & Downloads", url: "/tools.html", badge: "TOOLBOX" },
    { title: "The Signal Lab — Interactive Experiments", url: "/experiments.html", badge: "LAB" },
    { title: "Operator Profile — Kenneth Perry", url: "/about.html", badge: "OPERATOR" }
  ];

  let pagefindPromise = null;
  let searchSeq = 0;
  let activeIndex = 0;
  let lastTrigger = null;

  function loadPagefind() {
    if (!pagefindPromise) {
      const moduleUrl = "/pagefind/pagefind.js";
      pagefindPromise = import(moduleUrl)
        .then(async (pf) => {
          if (typeof pf.init === "function") await pf.init();
          return pf;
        })
        .catch(() => null);
    }
    return pagefindPromise;
  }

  function getElements() {
    const dialog = document.querySelector("[data-command-dialog]");
    if (!(dialog instanceof HTMLDialogElement)) return null;
    const input = dialog.querySelector("[data-command-input]");
    const results = dialog.querySelector("[data-command-results]");
    const closeBtn = dialog.querySelector("[data-command-close]");
    if (!(input instanceof HTMLInputElement) || !(results instanceof HTMLElement)) return null;
    return { dialog, input, results, closeBtn };
  }

  function setActiveIndex(resultsEl, nextIdx) {
    const items = [...resultsEl.querySelectorAll(".af-cmd__item")];
    if (items.length === 0) {
      activeIndex = -1;
      return;
    }
    activeIndex = ((nextIdx % items.length) + items.length) % items.length;
    items.forEach((el, idx) => {
      const selected = idx === activeIndex;
      el.classList.toggle("is-active", selected);
      el.setAttribute("aria-selected", String(selected));
      if (selected) el.scrollIntoView({ block: "nearest" });
    });
  }

  function closeDialog() {
    const els = getElements();
    if (!els || !els.dialog.open) return;
    els.dialog.close();
    if (lastTrigger instanceof HTMLElement && document.contains(lastTrigger)) {
      lastTrigger.focus();
    }
    lastTrigger = null;
  }

  function renderEntries(resultsEl, sections) {
    resultsEl.replaceChildren();
    let itemCounter = 0;

    for (const section of sections) {
      if (!section.items.length) continue;
      const heading = document.createElement("div");
      heading.className = "af-cmd__group-label";
      heading.textContent = section.label;
      resultsEl.append(heading);

      for (const entry of section.items) {
        const idx = itemCounter++;
        if (entry.type === "command") {
          const btn = document.createElement("button");
          btn.type = "button";
          btn.className = "af-cmd__item";
          btn.setAttribute("role", "option");
          btn.setAttribute("aria-selected", "false");
          btn.innerHTML = `<span class="af-cmd__item-top"><span class="af-cmd__item-title"></span><span class="af-cmd__item-badge"></span></span>`;
          btn.querySelector(".af-cmd__item-title").textContent = entry.title;
          btn.querySelector(".af-cmd__item-badge").textContent = entry.badge;
          btn.addEventListener("mouseenter", () => setActiveIndex(resultsEl, idx));
          btn.addEventListener("click", () => {
            entry.run();
            closeDialog();
          });
          resultsEl.append(btn);
        } else {
          const link = document.createElement("a");
          link.className = "af-cmd__item";
          link.href = entry.url;
          link.setAttribute("role", "option");
          link.setAttribute("aria-selected", "false");

          const top = document.createElement("span");
          top.className = "af-cmd__item-top";
          const titleSpan = document.createElement("span");
          titleSpan.className = "af-cmd__item-title";
          titleSpan.textContent = entry.title;
          const badgeSpan = document.createElement("span");
          badgeSpan.className = "af-cmd__item-badge";
          badgeSpan.textContent = entry.badge || "SIGNAL";
          top.append(titleSpan, badgeSpan);
          link.append(top);

          if (entry.excerptHtml) {
            const excerpt = document.createElement("span");
            excerpt.className = "af-cmd__item-excerpt";
            excerpt.innerHTML = entry.excerptHtml;
            link.append(excerpt);
          }

          link.addEventListener("mouseenter", () => setActiveIndex(resultsEl, idx));
          link.addEventListener("click", () => {
            if (elsDialogOpen()) elsDialogCloseOnly();
          });
          resultsEl.append(link);
        }
      }
    }

    if (itemCounter === 0) {
      const empty = document.createElement("div");
      empty.className = "af-cmd__empty";
      empty.textContent = "No matching signals or commands found.";
      resultsEl.append(empty);
      activeIndex = -1;
      return;
    }

    setActiveIndex(resultsEl, 0);
  }

  function elsDialogOpen() {
    const els = getElements();
    return Boolean(els?.dialog.open);
  }

  function elsDialogCloseOnly() {
    const els = getElements();
    if (els?.dialog.open) els.dialog.close();
    lastTrigger = null;
  }

  async function updateResults() {
    const els = getElements();
    if (!els) return;
    const raw = els.input.value.trim();
    const seq = ++searchSeq;

    if (!raw) {
      renderEntries(els.results, [
        {
          label: "Quick Navigation",
          items: QUICK_LINKS.map((l) => ({ type: "link", ...l }))
        },
        {
          label: "Direct Commands",
          items: COMMANDS.map((c) => ({ type: "command", ...c }))
        }
      ]);
      return;
    }

    const isCommandPrefix = raw.startsWith(">");
    const cmdNeedle = (isCommandPrefix ? raw.slice(1) : raw).trim().toLowerCase();
    const matchedCommands = COMMANDS.filter(
      (c) =>
        !cmdNeedle ||
        c.title.toLowerCase().includes(cmdNeedle) ||
        c.keywords.includes(cmdNeedle)
    ).map((c) => ({ type: "command", ...c }));

    if (isCommandPrefix) {
      renderEntries(els.results, [{ label: "Direct Commands", items: matchedCommands }]);
      return;
    }

    const pf = await loadPagefind();
    if (seq !== searchSeq) return;

    let searchItems = [];
    if (pf) {
      const res = await pf.search(raw);
      if (seq !== searchSeq) return;
      const top = res.results.slice(0, 8);
      const dataList = await Promise.all(top.map((r) => r.data()));
      if (seq !== searchSeq) return;
      searchItems = dataList.map((d) => ({
        type: "link",
        title: d.meta?.title?.replace(/\s*\|\s*NOC Thoughts$/i, "") || d.url,
        url: d.url,
        badge: d.url.startsWith("/experiments/")
          ? "LAB"
          : d.url === "/tools.html"
            ? "TOOLBOX"
            : "ARTICLE",
        excerptHtml: d.excerpt || ""
      }));
    }

    renderEntries(els.results, [
      ...(searchItems.length ? [{ label: "Matching Signals", items: searchItems }] : []),
      ...(matchedCommands.length ? [{ label: "Commands", items: matchedCommands }] : [])
    ]);
  }

  function openDialog() {
    const els = getElements();
    if (!els) return;
    if (!els.dialog.open) {
      lastTrigger = document.activeElement;
      els.dialog.showModal();
    }
    loadPagefind();
    els.input.value = "";
    updateResults();
    els.input.focus();
  }

  function bindPalette() {
    const els = getElements();
    if (!els || els.dialog.dataset.bound === "true") return;
    els.dialog.dataset.bound = "true";

    els.input.addEventListener("input", () => {
      updateResults();
    });

    els.closeBtn?.addEventListener("click", () => closeDialog());

    els.dialog.addEventListener("click", (event) => {
      if (event.target === els.dialog) closeDialog();
    });

    els.dialog.addEventListener("cancel", (event) => {
      event.preventDefault();
      closeDialog();
    });

    els.dialog.addEventListener("keydown", (event) => {
      if (event.key === "ArrowDown") {
        event.preventDefault();
        setActiveIndex(els.results, activeIndex + 1);
      } else if (event.key === "ArrowUp") {
        event.preventDefault();
        setActiveIndex(els.results, activeIndex - 1);
      } else if (event.key === "Enter") {
        const items = [...els.results.querySelectorAll(".af-cmd__item")];
        const current = items[activeIndex];
        if (current instanceof HTMLElement) {
          event.preventDefault();
          current.click();
        }
      }
    });
  }

  bindPalette();
  document.addEventListener("astro:page-load", bindPalette);
  document.addEventListener("astro:before-swap", () => {
    elsDialogCloseOnly();
  });

  if (!window.__nocCommandPaletteRegistered) {
    window.__nocCommandPaletteRegistered = true;
    document.addEventListener("noc:open-command-palette", (event) => {
      event.preventDefault();
      openDialog();
    });
  }
})();
