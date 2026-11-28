import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const component = readFileSync(
  new URL("../src/components/AmbientPlayer.astro", import.meta.url),
  "utf8"
);

test("AmbientPlayer mounts with transition:persist and default-collapsed popover", () => {
  assert.match(component, /transition:persist="ambient-player"/);
  assert.match(component, /data-expanded="false"/);
  assert.match(component, /id="af-ambient-popover"[^>]*\bhidden\b/);
});

test("AmbientPlayer preserves all 9 Soul Slash Synthesis tracks and lazy YouTube API loader", () => {
  const videoIds = [
    "un7jfZsbDRE",
    "ZFA6t2PAqyI",
    "Mkx_2QRyKcI",
    "q35PDSyTwA0",
    "9J2zrAoTfB4",
    "BNN0D39P4Ic",
    "-ilV0X9-PR8",
    "xV-XJT78tn0",
    "863-KXJRfyA"
  ];
  for (const id of videoIds) {
    assert.ok(component.includes(id), `Missing track videoId ${id}`);
  }
  assert.match(component, /root\.dataset\.initialized === "true"/);
  assert.match(component, /document\.addEventListener\("astro:page-load", initAmbientPlayer\)/);
  assert.match(component, /https:\/\/www\.youtube\.com\/iframe_api/);
});
