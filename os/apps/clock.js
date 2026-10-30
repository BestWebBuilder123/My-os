// Clock app module.
export function render(api) { return `<div class="clock-app"><div id="big-clock" class="big-clock"></div><div id="big-date" class="muted"></div><div class="app-toolbar clock-actions"><button data-clock="timer">Start 1-minute timer</button><button data-clock="stopwatch">Stopwatch</button></div><div id="clock-extra" class="muted"></div></div>`; }
export function mount(root, api) { api.mountLegacy('clock', root); }
