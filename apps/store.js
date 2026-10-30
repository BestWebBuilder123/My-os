// App Store module.
export function render(api) { return `<h2>App Store</h2><p class="muted">Your built-in apps are ready to use.</p><div class="file-grid">${api.apps.map(a=>`<button class="file-item" data-store-open="${a[0]}"><span class="symbol">${a[1]}</span>${a[2]}<small class="muted">Installed</small></button>`).join('')}</div>`; }
export function mount(root, api) { api.mountLegacy('store', root); }
