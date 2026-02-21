import { contextBridge } from 'electron';

contextBridge.exposeInMainWorld('electronAPI', {
  requestCamera: async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: false });
      return stream;
    } catch (err) {
      console.error('Camera access error:', err);
      return null;
    }
  }
});
