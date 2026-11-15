import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import vm from 'node:vm';

const component = readFileSync(new URL('../src/components/MusicPlayer.astro', import.meta.url), 'utf8');
const script = component.match(/<script is:inline>([\s\S]*?)<\/script>/)[1];

// Exercise the real inline controller with a delayed YouTube API, without network/audio.
function fixture() {
  const nodes = new Map();
  const node = () => ({
    handlers: {}, dataset: {}, open: false, value: '', textContent: '',
    addEventListener(type, handler) { this.handlers[type] = handler; },
    setAttribute() {}, classList: { toggle() {} },
  });
  const root = node();
  root.querySelector = (selector) => {
    if (!nodes.has(selector)) nodes.set(selector, node());
    return nodes.get(selector);
  };
  const playback = [];
  const calls = { play: 0, pause: 0, api: 0 };
  let events;
  const player = {
    setVolume() {},
    playVideo() { calls.play++; },
    pauseVideo() { calls.pause++; },
    getPlayerState() { return -1; },
  };
  const window = { dispatchEvent(event) { playback.push(event.detail.playing); } };
  const document = {
    querySelector(selector) { return selector === '[data-ambient-player]' ? root : null; },
    createElement() { return {}; }, head: { append() { calls.api++; } },
  };
  vm.runInNewContext(script, {
    window, document,
    localStorage: { getItem() { return null; }, setItem() {} },
    CustomEvent: class { constructor(_type, options) { this.detail = options.detail; } },
  });
  return {
    root, calls, playback,
    toggle(open) { root.open = open; root.handlers.toggle(); },
    play() { nodes.get('[data-ambient-play]').handlers.click(); },
    loadApi() {
      window.location = { origin: 'http://localhost' };
      window.YT = {
        PlayerState: { PLAYING: 1, PAUSED: 2, ENDED: 0 },
        Player: function (_id, options) { events = options.events; return player; },
      };
      window.onYouTubeIframeAPIReady();
      events.onReady({ target: player });
    },
    playing() { events.onStateChange({ data: 1 }); },
  };
}

test('opening the default-closed disclosure does not load YouTube or autoplay', () => {
  assert.doesNotMatch(component.match(/<details[^>]*>/)[0], /\bopen(?:\s|=|>)/);
  const f = fixture();
  f.toggle(true);
  assert.equal(f.calls.api, 0);
  assert.equal(f.calls.play, 0);
});

test('closing while the API loads cancels pending autoplay', () => {
  const f = fixture();
  f.toggle(true); f.play(); f.toggle(false); f.loadApi();
  assert.equal(f.calls.api, 1);
  assert.equal(f.calls.play, 0);
  assert.equal(f.root.dataset.state, 'paused');
});

test('closing pauses playback and rejects a late playing callback', () => {
  const f = fixture();
  f.toggle(true); f.play(); f.loadApi(); f.playing();
  assert.equal(f.calls.play, 1);
  assert.equal(f.root.dataset.state, 'playing');
  f.toggle(false);
  assert.equal(f.calls.pause, 1);
  assert.equal(f.playback.at(-1), false);
  f.playing();
  assert.equal(f.calls.pause, 2);
  assert.equal(f.root.dataset.state, 'paused');
});
