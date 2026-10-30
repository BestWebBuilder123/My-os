// Music app module.
export function render(api) { return `<div class="app-hero"><div class="app-hero-icon">♫</div><h2>Your music</h2><p class="muted">Bring your own audio files and play them here.</p></div><div class="app-toolbar"><button data-music="add">＋ Add audio</button></div><div id="music-list"></div><audio id="audio-player" controls style="width:100%;margin-top:18px"></audio>`; }
export function mount(root, api) { api.mountLegacy('music', root); }
