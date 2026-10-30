// Notes app module.
export function render(api) { return `<div class="app-toolbar"><button data-notes="new">＋ New note</button><button data-notes="export">Export notes</button></div><div id="notes-list"></div>`; }
export function mount(root, api) { api.mountLegacy('notes', root); }
