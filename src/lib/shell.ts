import { site } from "../config/site";

export const NAV_LINKS = [
  { href: "/posts.html", label: "Field Notes" },
  { href: "/tools.html", label: "Toolbox" },
  { href: "/experiments.html", label: "Lab" },
  { href: "/about.html", label: "Operator" }
] as const;

export function renderSiteHeaderHtml(): string {
  const navItems = NAV_LINKS.map(
    ({ href, label }) => `<a href="${href}">${label}</a>`
  ).join("");

  return `<header class="noc-bar" data-pagefind-ignore>
  <div class="noc-bar-inner">
    <a class="noc-home" href="/" aria-label="NOC Thoughts home">
      <span class="noc-status-dot" aria-hidden="true"></span>
      <span class="noc-brand-text">NOC THOUGHTS</span>
    </a>
    <nav id="noc-nav" class="noc-nav" aria-label="Primary navigation">${navItems}</nav>
    <div class="noc-actions">
      <button class="noc-search-btn" type="button" data-command-trigger aria-label="Search site (Command+K or Control+K)">
        <svg viewBox="0 0 16 16" width="14" height="14" aria-hidden="true"><circle cx="6.75" cy="6.75" r="4.75" /><path d="M10.25 10.25L14 14" /></svg>
        <span class="noc-search-label">Search</span>
        <kbd class="noc-kbd">⌘K</kbd>
      </button>
      <button class="noc-theme-btn" type="button" data-theme-cycle aria-label="Cycle color theme">
        <span class="noc-theme-swatch" aria-hidden="true"></span>
        <span class="noc-theme-label" data-theme-label>Aftertone</span>
      </button>
      <button class="noc-menu" type="button" hidden aria-expanded="false" aria-controls="noc-nav" aria-label="Toggle navigation menu">Menu</button>
    </div>
  </div>
</header>`;
}

export function renderSiteFooterHtml(year = new Date().getFullYear()): string {
  return `<footer class="site-footer" data-pagefind-ignore>
  <p class="site-footer-signal">
    <span class="status-light" aria-hidden="true"></span>
    Signal maintained by ${site.author.name}
  </p>
  <p class="footer-code">NOCTHOUGHTS // SYRACUSE, NY // ${year}</p>
  <nav class="footer-links" aria-label="Footer links">
    <a href="/categories.html">Pillars</a>
    <a href="/tags.html">Tags</a>
    <a href="/feed.xml">RSS</a>
    <a href="/privacypolicy.html">Privacy</a>
    <a href="${site.social.github}">GitHub</a>
  </nav>
</footer>`;
}
