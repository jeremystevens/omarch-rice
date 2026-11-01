const { contextBridge, ipcRenderer } = require('electron');

function subscribe(channel, fn) {
  const handler = (_e, payload) => fn(payload);
  ipcRenderer.on(channel, handler);
  return () => ipcRenderer.removeListener(channel, handler);
}

contextBridge.exposeInMainWorld('companion', {
  sizeWindow: (size) => ipcRenderer.invoke('window:size-to', size),
  panel: {
    hotkey: () => ipcRenderer.invoke('panel:hotkey'),
    onToggle: (fn) => subscribe('panel:toggle', fn),
  },
  pty: {
    start: (size) => ipcRenderer.invoke('pty:start', size),
    write: (data) => ipcRenderer.send('pty:write', data),
    resize: (size) => ipcRenderer.send('pty:resize', size),
    onData: (fn) => subscribe('pty:data', fn),
    onExit: (fn) => subscribe('pty:exit', fn),
  },
  ai: {
    ask: (id, messages) => ipcRenderer.send('ai:ask', { id, messages }),
    cancel: (id) => ipcRenderer.send('ai:cancel', id),
    reset: () => ipcRenderer.send('ai:reset'),
    health: () => ipcRenderer.invoke('ai:health'),
    onChunk: (fn) => subscribe('ai:chunk', fn),
    onDone: (fn) => subscribe('ai:done', fn),
    onError: (fn) => subscribe('ai:error', fn),
  },
  clipboard: {
    read: () => ipcRenderer.invoke('clipboard:read'),
    write: (text) => ipcRenderer.send('clipboard:write', text),
  },
});
