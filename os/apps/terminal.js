// Terminal app module.
export function render(api) { return `<div class="terminal" id="terminal"><div>My OS Terminal · type <b>help</b> to see commands</div><div class="terminal-input"><span>guest@myos:~$</span><input id="terminal-input" autofocus></div></div>`; }
export function mount(root, api) { api.mountLegacy('terminal', root); }
