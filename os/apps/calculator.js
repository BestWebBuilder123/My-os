// Calculator app module.
export function render(api) { return `<div class="calc"><div class="calc-display" id="calc-display">0</div><div class="calc-keys">${['AC','±','%','÷','7','8','9','×','4','5','6','−','1','2','3','+','0','.','⌫','='].map(k=>`<button class="${['÷','×','−','+','='].includes(k)?'op':''}" data-calc="${k}">${k}</button>`).join('')}</div></div>`; }
export function mount(root, api) { api.mountLegacy('calculator', root); }
