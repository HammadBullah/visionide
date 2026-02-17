import React, { useEffect, useRef } from 'react';
import { createRoot } from 'react-dom/client';
import Editor from '@monaco-editor/react';

function App() {
  const videoRef = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    (async () => {
      // Use the preload exposed API
      const stream = await (window as any).electronAPI.requestCamera();
      if (videoRef.current && stream) {
        videoRef.current.srcObject = stream;
      }
    })();
  }, []);

  return (
    <div style={{ position: 'relative', width: '100vw', height: '100vh', overflow: 'hidden' }}>
      {/* Webcam as background */}
      <video
        ref={videoRef}
        autoPlay
        muted
        playsInline
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          width: '100%',
          height: '100%',
          objectFit: 'cover',
          zIndex: 0,
        }}
      />

      {/* Overlay editor */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: 'rgba(30,30,46,0.7)',
          backdropFilter: 'blur(2px)',
          zIndex: 1,
        }}
      >
        <Editor
          height="100%"
          width="100%"
          defaultLanguage="python"
          defaultValue={`# Hello World\nprint("Webcam background test")`}
          theme="vs-dark"
          options={{ minimap: { enabled: false }, fontSize: 15, lineNumbers: 'on' }}
        />
      </div>
    </div>
  );
}

// Mount to DOM
const container = document.getElementById('root');
const root = createRoot(container!);
root.render(
  <div style={{ width: '100%', height: '100%' }}>
    <App />
  </div>
);