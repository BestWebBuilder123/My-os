// Images app module.
export function render(api) { return `<div class="app-toolbar"><button data-images="add">＋ Import images</button></div><div id="image-list" class="file-grid"></div><div id="image-view" class="image-view"></div>`; }
export function mount(root, api) { api.mountLegacy('images', root); }
