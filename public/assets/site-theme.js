// Shared synchronous theme & navigation controller across BaseLayout and standalone experiments.
(() => {
  const CYCLE_ORDER = ["aftertone", "paper", "polar"];
  const themes = {
    aftertone: {
      name: "Aftertone",
      color: "#0E1013",
      icon: "/favicon.svg?v=3",
      lead: "The rack hums.",
      emphasis: "One link stays dark."
    },
    paper: {
      name: "Field Paper",
      color: "#F5F3EE",
      icon: "/assets/trace-relay/aftertone.svg",
      lead: "Field notes from the",
      emphasis: "shortwave end of the network."
    },
    polar: {
      name: "Polar Night",
      color: "#080C14",
      icon: "/assets/trace-relay/polar.svg",
      lead: "Notes from the",
      emphasis: "overnight shift."
    },
    cyberpunk: {
      name: "Cyberpunk",
      color: "#070913",
      icon: "/assets/trace-relay/cyberpunk.svg",
      lead: "Where network operations meet",
      emphasis: "techno-sorcery."
    },
    "moss-brass": {
      name: "Moss & Brass",
      color: "#141b16",
      icon: "/assets/trace-relay/moss.svg",
      lead: "A field guide to",
      emphasis: "the networks we tend."
    }
  };

  const legacyAliases = {
    "aftertone-dark": "aftertone",
    moss: "moss-brass"
  };

  const preference = "noc-thoughts.theme";

  function normalizeTheme(raw) {
    if (!raw) return "aftertone";
    const mapped = Object.hasOwn(legacyAliases, raw) ? legacyAliases[raw] : raw;
    return Object.hasOwn(themes, mapped) ? mapped : "aftertone";
  }

  function readSavedTheme() {
    try {
      const saved = localStorage.getItem(preference);
      if (!saved) return "aftertone";
      const normalized = normalizeTheme(saved);
      if (normalized !== saved) {
        try { localStorage.setItem(preference, normalized); } catch {}
      }
      return normalized;
    } catch {
      return normalizeTheme(document.documentElement.dataset.theme);
    }
  }

  function updateHeadline() {
    const heading = document.getElementById("theme-headline");
    if (!heading) return;
    const key = normalizeTheme(document.documentElement.dataset.theme);
    const theme = themes[key];
    const emphasis = document.createElement("em");
    emphasis.textContent = theme.emphasis;
    heading.replaceChildren(theme.lead + " ", emphasis);
  }

  function syncThemeButtons(key) {
    const current = themes[key] || themes.aftertone;
    const nextIndex = (CYCLE_ORDER.indexOf(key) + 1) % CYCLE_ORDER.length;
    const nextKey = CYCLE_ORDER[nextIndex];
    const nextTheme = themes[nextKey];
    for (const btn of document.querySelectorAll("[data-theme-cycle]")) {
      const label = btn.querySelector("[data-theme-label]");
      if (label) label.textContent = current.name;
      btn.setAttribute(
        "aria-label",
        `Theme: ${current.name}. Switch to ${nextTheme.name}`
      );
      btn.setAttribute("title", `Theme: ${current.name} (click for ${nextTheme.name})`);
    }
  }

  function apply(value, persist = false) {
    const root = document.documentElement;
    const key = normalizeTheme(value);
    const changed = root.dataset.theme !== key;
    root.dataset.theme = key;

    if (persist) {
      try { localStorage.setItem(preference, key); } catch {}
    }

    const icon = document.querySelector("link[data-site-icon]");
    if (icon) icon.href = themes[key].icon;
    document.querySelector('meta[name="theme-color"]')?.setAttribute("content", themes[key].color);

    syncThemeButtons(key);
    updateHeadline();
    if (changed) document.dispatchEvent(new CustomEvent("noc-theme-change", { detail: { theme: key } }));
    return key;
  }

  function cycle() {
    const current = normalizeTheme(document.documentElement.dataset.theme);
    const index = CYCLE_ORDER.indexOf(current);
    const next = CYCLE_ORDER[(index + 1) % CYCLE_ORDER.length];
    return apply(next, true);
  }

  function openSearchFallback() {
    const event = new CustomEvent("noc:open-command-palette", { cancelable: true });
    const unhandled = document.dispatchEvent(event);
    if (!unhandled) return;
    const archiveInput = document.getElementById("archive-filter");
    if (archiveInput instanceof HTMLElement) {
      archiveInput.focus();
      if (archiveInput instanceof HTMLInputElement) archiveInput.select();
      return;
    }
    window.location.href = "/posts.html#archive-filter";
  }

  function syncActiveNav(header) {
    const path = window.location.pathname;
    const normalizedPath = path === "/" ? "/" : path.endsWith("/") ? path.slice(0, -1) + ".html" : path;
    for (const link of header.querySelectorAll(".noc-nav a")) {
      link.removeAttribute("aria-current");
      if (link.pathname === normalizedPath) {
        link.setAttribute("aria-current", "page");
      } else if (
        (link.pathname === "/experiments.html" && path.startsWith("/experiments/")) ||
        (link.pathname === "/posts.html" && (/^\/\d{4}\/\d{2}\/\d{2}\//.test(path) || path.startsWith("/categories") || path.startsWith("/tags")))
      ) {
        link.setAttribute("aria-current", "true");
      }
    }
  }

  function initShell() {
    const currentKey = apply(readSavedTheme(), false);
    syncThemeButtons(currentKey);

    const header = document.querySelector(".noc-bar");
    if (header) {
      syncActiveNav(header);
      const menu = header.querySelector(".noc-menu");
      if (menu && !menu.dataset.bound) {
        menu.dataset.bound = "true";
        menu.hidden = false;
        menu.addEventListener("click", () => {
          const expanded = menu.getAttribute("aria-expanded") === "true";
          menu.setAttribute("aria-expanded", String(!expanded));
        });
        header.addEventListener("keydown", (event) => {
          if (event.key === "Escape" && menu.getAttribute("aria-expanded") === "true") {
            menu.setAttribute("aria-expanded", "false");
            menu.focus();
          }
        });
      }
    }

    for (const btn of document.querySelectorAll("[data-theme-cycle]")) {
      if (btn.dataset.bound) continue;
      btn.dataset.bound = "true";
      btn.addEventListener("click", () => cycle());
    }

    for (const trigger of document.querySelectorAll("[data-command-trigger]")) {
      if (trigger.dataset.bound) continue;
      trigger.dataset.bound = "true";
      trigger.addEventListener("click", () => openSearchFallback());
    }

    for (const copyBtn of document.querySelectorAll("[data-copy-sha]")) {
      if (copyBtn.dataset.bound) continue;
      copyBtn.dataset.bound = "true";
      const original = copyBtn.textContent || "Copy SHA-256";
      copyBtn.addEventListener("click", async () => {
        const value = copyBtn.dataset.copySha;
        if (!value) return;
        try {
          await navigator.clipboard.writeText(value);
          copyBtn.textContent = "Copied ✓";
        } catch {
          copyBtn.textContent = "Select hash below";
        }
        window.setTimeout(() => {
          copyBtn.textContent = original;
        }, 1800);
      });
    }

    if (window.location.hash === "#archive-filter") {
      const archiveInput = document.getElementById("archive-filter");
      if (archiveInput instanceof HTMLElement) archiveInput.focus();
    }
  }

  // Synchronous pre-paint initialization (Zero FOUC)
  apply(readSavedTheme(), false);
  window.nocThoughtsTheme = { apply, cycle, updateHeadline, themes };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initShell, { once: true });
  } else {
    initShell();
  }

  document.addEventListener("astro:after-swap", () => {
    apply(readSavedTheme(), false);
  });
  document.addEventListener("astro:page-load", initShell);

  if (!window.__nocShellHotkeysBound) {
    window.__nocShellHotkeysBound = true;
    document.addEventListener("keydown", (event) => {
      if ((event.metaKey || event.ctrlKey) && !event.altKey && !event.shiftKey && event.key.toLowerCase() === "k") {
        event.preventDefault();
        openSearchFallback();
      }
    });
    window.addEventListener("pageshow", (event) => {
      if (event.persisted) apply(readSavedTheme(), false);
    });
    window.addEventListener("storage", (event) => {
      if (event.key === preference || event.key === null) apply(readSavedTheme(), false);
    });
  }
})();
