// Shared by the Astro layouts and the standalone experiment headers.
(() => {
  const themes = {
    cyberpunk: { name: "Cyberpunk", color: "#070913", lead: "Where network operations meet", emphasis: "techno-sorcery." },
    aftertone: { name: "Aftertone", color: "#f1efe6", lead: "Field notes from the", emphasis: "shortwave end of the network." },
    "aftertone-dark": { name: "Aftertone Dark", color: "#2b2c2e", lead: "The rack hums.", emphasis: "One link stays dark." },
    polar: { name: "Polar Night", color: "#0d1924", lead: "Notes from the", emphasis: "overnight shift." },
    moss: { name: "Moss & Brass", color: "#141b16", lead: "A field guide to", emphasis: "the networks we tend." },
    darkroom: { name: "Darkroom", color: "#191419", lead: "A closer look at", emphasis: "what the traces reveal." },
    carbon: { name: "Carbon Violet", color: "#171422", lead: "Dispatches from", emphasis: "the infrastructure lab." },
  };
  const preference = "noc-thoughts.theme";
  const root = document.documentElement;

  function updateHeadline() {
    const heading = document.getElementById("theme-headline");
    if (!heading) return;
    const theme = themes[root.dataset.theme];
    const emphasis = document.createElement("em");
    emphasis.textContent = theme.emphasis;
    heading.replaceChildren(theme.lead + " ", emphasis);
  }

  function apply(value) {
    const key = Object.hasOwn(themes, value) ? value : "aftertone-dark";
    const changed = root.dataset.theme !== key;
    root.dataset.theme = key;
    const icon = document.querySelector("link[data-site-icon]");
    if (icon) icon.href = key === "aftertone-dark" ? "/favicon.svg?v=3" : "/assets/trace-relay/" + key + ".svg";
    document.querySelector('meta[name="theme-color"]')?.setAttribute("content", themes[key].color);
    const picker = document.getElementById("site-theme");
    if (picker) picker.value = key;
    updateHeadline();
    if (changed) document.dispatchEvent(new Event("noc-theme-change"));
  }

  function restore() {
    try { apply(localStorage.getItem(preference)); }
    catch { apply(root.dataset.theme); }
  }

  restore();
  window.nocThoughtsTheme = { updateHeadline };
  document.addEventListener("DOMContentLoaded", () => {
    const header = document.querySelector(".noc-bar");
    if (header) {
      const menu = header.querySelector(".noc-menu");
      menu.hidden = false;
      menu.addEventListener("click", () => {
        menu.setAttribute("aria-expanded", String(menu.getAttribute("aria-expanded") !== "true"));
      });
      header.addEventListener("keydown", event => {
        if (event.key === "Escape" && menu.offsetWidth && menu.getAttribute("aria-expanded") === "true") {
          menu.setAttribute("aria-expanded", "false");
          menu.focus();
        }
      });
      for (const link of header.querySelectorAll("nav a")) {
        if (link.pathname === location.pathname) link.setAttribute("aria-current", "page");
        else if (link.pathname === "/experiments.html" && location.pathname.startsWith("/experiments/")) {
          link.setAttribute("aria-current", "location");
        }
      }
    }
    const picker = document.getElementById("site-theme");
    if (!picker) return;
    for (const [key, theme] of Object.entries(themes)) picker.add(new Option(theme.name, key));
    picker.value = root.dataset.theme;
    picker.addEventListener("change", () => {
      apply(picker.value);
      try { localStorage.setItem(preference, picker.value); } catch {}
    });
    picker.closest("label").hidden = false;
  }, { once: true });
  window.addEventListener("pageshow", event => { if (event.persisted) restore(); });
  window.addEventListener("storage", event => {
    if (event.key === preference || event.key === null) restore();
  });
})();
