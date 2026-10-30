// Files app module.
export function render(api) { return `<div class="app-toolbar"><button data-file-action="new">＋ New folder</button><button data-file-action="upload">↑ Import</button><button data-file-action="export">↓ Export</button><input placeholder="Search files" id="file-search"></div><div class="file-grid" id="file-grid"></div>`; }
export function mount(root, api) { api.mountLegacy('files', root); }
