// src/main.mts (ESM version)

import { app, BrowserWindow } from 'electron';
import path from 'path';

const createWindow = async () => {
  const win = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      preload: path.join(__dirname, 'preload.mjs'), // adjust if needed
    },
  });
  win.show();                // force show
  win.focus();               // bring to front
  // ← Add the log here
  console.log('Electron window created successfully');

  // Load the renderer
  if (process.env.NODE_ENV === 'development') {
    await win.loadURL('http://localhost:5173');
    win.webContents.openDevTools({ mode: 'detach' }); // auto open dev tools
  } else {
    await win.loadFile(path.join(__dirname, '../renderer/dist/index.html'));
  }
};

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});