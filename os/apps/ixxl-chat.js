window.mountIxxlChat = async function(root){
  root.style.padding = '0';
  root.style.overflow = 'hidden';
  root.innerHTML = '<div style="height:100%;display:flex;align-items:center;justify-content:center;background:#020617;color:#cbd5e1;font:14px Inter,system-ui,sans-serif">Loading latest Ixxl Chat…</div>';

  const frame = document.createElement('iframe');
  frame.title = 'Ixxl Chat';
  frame.setAttribute('allow', 'clipboard-read; clipboard-write');
  frame.style.cssText = 'display:block;width:100%;height:100%;border:0;background:#020617;border-radius:inherit;';
  root.replaceChildren(frame);

  try {
    const sourceUrl = 'https://raw.githubusercontent.com/weirdsimplegames/My-os/main/Ixxl%20chat/liquid_glass_discord_chat.html';
    const response = await fetch(sourceUrl, { cache: 'no-store' });
    if (!response.ok) throw new Error('GitHub returned HTTP ' + response.status);
    const html = await response.text();
    if (!html.trim().toLowerCase().includes('<!doctype html') && !html.trim().toLowerCase().includes('<html')) {
      throw new Error('GitHub did not return the chat HTML file.');
    }
    frame.srcdoc = html;
  } catch (error) {
    root.innerHTML = '<div style="height:100%;display:flex;flex-direction:column;gap:10px;align-items:center;justify-content:center;padding:24px;text-align:center;background:#020617;color:#e2e8f0;font:14px Inter,system-ui,sans-serif"><strong>Could not load the latest Ixxl Chat.</strong><span style="color:#94a3b8;max-width:420px">' +
      String(error && error.message || error).replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c])) +
      '</span><button onclick="window.mountIxxlChat(this.parentElement.parentElement)" style="padding:9px 14px;border-radius:10px;background:#10b981;color:white;border:0;cursor:pointer">Retry</button></div>';
  }
};
