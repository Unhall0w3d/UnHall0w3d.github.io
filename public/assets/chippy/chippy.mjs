import {STATES, LABELS, INTERVAL, frameFor} from './animation.mjs';

// Purely presentational: the embedding application supplies state explicitly.
export class ChippyPet extends HTMLElement {
  static observedAttributes = ['state', 'paused', 'hide-label'];
  constructor() {
    super();
    this.tick = 0;
    this.timer = null;
    this.inView = true;
    this.ready = false;
    this.motion = matchMedia('(prefers-reduced-motion: reduce)');
    this.sync = this.sync.bind(this);
    const root = this.attachShadow({mode: 'open'});
    root.innerHTML = `<style>
      :host { display:inline-flex; flex-direction:column; align-items:center; vertical-align:middle; width:var(--chippy-size,128px); color:inherit; }
      canvas { display:block; width:100%; height:auto; image-rendering:pixelated; }
      span { font:inherit; font-size:.8em; line-height:1.5; text-align:center; }
      :host([hide-label]) span { display:none; }
    </style><canvas width="314" height="314" aria-hidden="true"></canvas><span></span>`;
    this.canvas = root.querySelector('canvas');
    this.label = root.querySelector('span');
    this.ctx = this.canvas.getContext('2d');
    this.image = new Image();
    this.image.onload = () => {
      this.ready = this.image.naturalWidth === 1254 && this.image.naturalHeight === 1254;
      this.dataset.asset = this.ready ? 'ready' : 'invalid';
      this.sync();
    };
    this.image.onerror = () => { this.ready = false; this.dataset.asset = 'error'; this.sync(); };
    this.image.src = new URL('./chippy-sprites.png', import.meta.url).href;
  }
  connectedCallback() {
    this.setAttribute('role', 'img');
    document.addEventListener('visibilitychange', this.sync);
    this.motion.addEventListener('change', this.sync);
    if ('IntersectionObserver' in window) {
      this.inView = false;
      this.observer = new IntersectionObserver(entries => {
        this.inView = entries.some(entry => entry.isIntersecting);
        this.sync();
      });
      this.observer.observe(this);
    }
    this.sync();
  }
  disconnectedCallback() {
    document.removeEventListener('visibilitychange', this.sync);
    this.motion.removeEventListener('change', this.sync);
    this.observer?.disconnect();
    this.observer = null;
    this.stop();
  }
  attributeChangedCallback(name, oldValue, newValue) {
    if (oldValue === newValue) return;
    if (name === 'state') this.tick = 0;
    if (this.label) this.sync();
  }
  get state() { return this.getAttribute('state') || 'idle'; }
  set state(value) {
    if (!STATES.includes(value)) throw new RangeError('Unknown Chippy state');
    this.setAttribute('state', value);
  }
  get paused() { return this.hasAttribute('paused'); }
  set paused(value) { this.toggleAttribute('paused', Boolean(value)); }
  stop() {
    if (this.timer !== null) clearInterval(this.timer);
    this.timer = null;
    this.dataset.running = 'false';
  }
  sync() {
    this.stop();
    const valid = STATES.includes(this.state);
    const label = !valid ? 'Unknown state' : this.dataset.asset === 'error' || this.dataset.asset === 'invalid' ? 'Artwork unavailable' : this.paused ? 'Paused' : LABELS[this.state];
    this.label.textContent = `Chippy · ${label}`;
    this.setAttribute('aria-label', `Chippy, ${label}`);
    this.draw();
    if (this.isConnected && this.ready && valid && !this.paused && !document.hidden && !this.motion.matches && this.inView) {
      this.dataset.running = 'true';
      this.timer = setInterval(() => {
        // Wrap beyond the one-shot celebration; never celebrate again on overflow.
        this.tick = this.tick >= 4095 ? 16 : this.tick + 1;
        this.draw();
      }, INTERVAL);
    }
  }
  draw() {
    if (!this.ctx) return;
    this.ctx.clearRect(0, 0, 314, 314);
    if (!this.ready || !STATES.includes(this.state)) return;
    const f = frameFor(this.state, this.motion.matches ? 0 : this.tick);
    this.ctx.imageSmoothingEnabled = false;
    this.ctx.drawImage(this.image, f.x, f.y, f.width, f.height, 0, 0, 314, 314);
    this.dataset.frame = `${f.row}:${f.column}`;
  }
}
if (!customElements.get('chippy-pet')) customElements.define('chippy-pet', ChippyPet);
