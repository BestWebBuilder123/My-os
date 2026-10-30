// Text Editor app module.
export function render(api) { return `<div class="app-toolbar"><button data-editor="open">Open</button><button data-editor="save">Save as</button><button data-editor="download">Download .txt</button><span class="muted" id="editor-status">Untitled</span></div><textarea class="editor" id="editor-text" spellcheck="false" placeholder="Start writing…"></textarea>`; }
export function mount(root, api) { api.mountLegacy('editor', root); }
