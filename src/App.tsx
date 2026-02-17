import React, { useEffect, useRef } from 'react';
import Editor from '@monaco-editor/react';

export default function App() {
  const videoRef = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    (async () => {
      const stream = await (window as any).electronAPI.requestCamera();
      if (videoRef.current && stream) {
        videoRef.current.srcObject = stream;
      }
    })();
  }, []);

  return (
    <div style={{ position: 'relative', width: '100vw', height: '100vh', overflow: 'hidden' }}>
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
      <div
        style={{
          position: 'relative',
      width: '100%',
      height: '100%', // make sure this is 100%
      overflow: 'hidden',
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
