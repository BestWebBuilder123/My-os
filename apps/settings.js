// Settings app module.
export function render(api) { return `<div class="settings-layout"><nav class="settings-nav">${['Appearance','Desktop','Dock','Animations','System','About'].map((s,i)=>`<button data-settings-tab="${s.toLowerCase()}" class="${i===0?'current':''}">${['◐','▦','▤','✧','⚙','ⓘ'][i]} ${s}</button>`).join('')}</nav><div id="settings-page" class="settings-page"></div></div>`; }
export function mount(root, api) { api.mountLegacy('settings', root); }
