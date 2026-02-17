// src/App.tsx
import React from 'react';
import { jsx as _jsx } from 'react/jsx-runtime';
import Webcam from 'react-webcam';
import Editor from '@monaco-editor/react';
import * as monaco from 'monaco-editor';
import EditorWorker from 'monaco-editor/esm/vs/editor/editor.worker?worker';
import TsWorker from 'monaco-editor/esm/vs/language/typescript/ts.worker?worker';

self.MonacoEnvironment = {
  getWorker(_: string, label: string) {
    if (label === 'typescript' || label === 'javascript') {
      return new TsWorker();
    }
    return new EditorWorker();
  },
};
export default function App() {
  return (
    <div style={{ 
      position: 'relative', 
      height: '100vh', 
      width: '100vw', 
      overflow: 'hidden',
      fontFamily: 'system-ui, sans-serif'
    }}>
      {/* Webcam as full background */}
      <Webcam
        audio={false}
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          width: '100%',
          height: '100%',
          objectFit: 'cover',
          zIndex: -1,
        }}
        videoConstraints={{ facingMode: 'user' }} // front camera
      />

      {/* Semi-transparent overlay for better code readability */}
      <div style={{
        position: 'absolute',
        inset: 0,
        background: 'rgba(30, 30, 46, 0.75)', // dark semi-transparent
        backdropFilter: 'blur(3px)',
      }}>
        <Editor
          height="100%"
          width="100%"
          defaultLanguage="python"
          defaultValue={`# VisionIDE - Gesture Coding Prototype
# Week 1: Webcam + Monaco overlay
def greet(name: str) -> str:
    return f"Hello, {name}! 👋"

print(greet("World"))`}
          theme="vs-dark"  // or "light"
          options={{
            minimap: { enabled: false },
            fontSize: 15,
            lineNumbers: 'on',
            scrollBeyondLastLine: false,
          }}
        />
      </div>
    </div>
  );
}