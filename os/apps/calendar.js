// Calendar app module.
export function render(api) { return `<div class="app-toolbar"><button data-cal="prev">‹</button><strong id="cal-title"></strong><button data-cal="next">›</button><button data-cal="today">Today</button></div><div class="calendar-grid" id="calendar-grid"></div>`; }
export function mount(root, api) { api.mountLegacy('calendar', root); }
