// Inline style and script of the HTML report; the file must load nothing from the network.

/// Light colours by default, dark under `prefers-color-scheme: dark`. Box colours stay the same in both, as they sit
/// on the app's screenshot, not on the page.
const htmlReportCss = r'''
:root {
  color-scheme: light dark;
  --bg: #ffffff; --fg: #1b1c1f; --muted: #5d6169; --line: #d9dce1; --panel: #f4f5f7; --hl: #fff2bf;
  --text-error: #b3261e; --text-warning: #8a5300; --text-info: #0b57d0;
  --box-error: #d32f2f; --box-warning: #f59e0b; --box-info: #1565c0;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #141518; --fg: #e6e7ea; --muted: #a3a8b0; --line: #34373d; --panel: #1d1f23; --hl: #3d3517;
    --text-error: #ff8a80; --text-warning: #ffcc66; --text-info: #8ab4f8;
  }
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--fg); font: 15px/1.5 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
header, main { max-width: 1200px; margin: 0 auto; padding: 16px; }
header { border-bottom: 1px solid var(--line); }
h1 { font-size: 1.4rem; margin: 0 0 8px; }
h2 { font-size: 1.15rem; margin: 0 0 12px; }
h3 { font-size: 1rem; margin: 0 0 6px; display: flex; gap: 8px; align-items: baseline; }
.meta { display: flex; flex-wrap: wrap; gap: 4px 24px; margin: 0 0 10px; }
.meta div { display: flex; gap: 6px; }
.meta dt { color: var(--muted); }
.meta dd { margin: 0; font-weight: 600; overflow-wrap: anywhere; }
.counts { display: flex; flex-wrap: wrap; gap: 8px; margin: 0; }
.counts .sev { padding: 1px 10px; border: 1px solid currentColor; border-radius: 999px; }
main { display: grid; gap: 24px; }
@media (min-width: 900px) {
  main { grid-template-columns: minmax(280px, 400px) minmax(0, 1fr); align-items: start; }
  .screen { grid-row: span 2; position: sticky; top: 16px; }
}
.error { --c: var(--box-error); --on: #ffffff; --t: var(--text-error); }
.warning { --c: var(--box-warning); --on: #1b1c1f; --t: var(--text-warning); }
.info { --c: var(--box-info); --on: #ffffff; --t: var(--text-info); }
.sev { color: var(--t); font-weight: 600; }
.frame { position: relative; max-width: 400px; margin: 0 auto; border: 1px solid var(--line); }
.frame img { display: block; width: 100%; height: auto; }
.frame.empty { background: var(--panel); }
.box { position: absolute; min-width: 6px; min-height: 6px; border: 2px solid var(--c); border-radius: 3px;
  box-shadow: 0 0 0 1px rgba(255, 255, 255, 0.85); }
.box.hl, .box:focus-visible { border-width: 3px; background: color-mix(in srgb, var(--c) 30%, transparent); z-index: 2; }
.box:focus-visible { outline: 2px solid var(--fg); outline-offset: 2px; }
.badge { display: inline-flex; align-items: center; justify-content: center; min-width: 1.6em; height: 1.6em;
  padding: 0 4px; border-radius: 999px; background: var(--c); color: var(--on); font: 700 12px/1 system-ui, sans-serif; }
/* Outside the corner, so a badge never hides a small target like a 16 pt icon. */
.box .badge { position: absolute; right: calc(100% - 4px); bottom: calc(100% - 4px);
  box-shadow: 0 0 0 1px rgba(255, 255, 255, 0.85); }
.groups { margin: 0; padding: 0; list-style: none; }
.group { margin: 0 0 12px; padding: 10px 12px; border: 1px solid var(--line); border-left: 4px solid var(--c);
  border-radius: 6px; }
.group.hl, .group:target { background: var(--hl); }
.group:focus-visible { outline: 2px solid var(--fg); outline-offset: 2px; }
.target { overflow-wrap: anywhere; }
.items { margin: 0; padding: 0; list-style: none; }
.items li + li { margin-top: 8px; padding-top: 8px; border-top: 1px solid var(--line); }
.rule { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-weight: 600; overflow-wrap: anywhere; }
.source, .wcag { color: var(--muted); font-size: 0.9em; }
.message { margin: 2px 0 0; white-space: pre-line; overflow-wrap: anywhere; }
.transcript li { white-space: pre-line; overflow-wrap: anywhere; }
.none { color: var(--muted); }
''';

/// Hovering or focusing a box or a list entry highlights both; without it the boxes link to their entries.
const htmlReportScript = r'''
for (const el of document.querySelectorAll('[data-group]')) {
  const peers = document.querySelectorAll('[data-group="' + el.dataset.group + '"]');
  const set = (on) => peers.forEach((peer) => peer.classList.toggle('hl', on));
  el.addEventListener('mouseenter', () => set(true));
  el.addEventListener('mouseleave', () => set(false));
  el.addEventListener('focusin', () => set(true));
  el.addEventListener('focusout', () => set(false));
}
''';
