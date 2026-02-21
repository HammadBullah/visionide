// vite-env.d.ts (or src/vite-env.d.ts)
/// <reference types="vite/client" />

declare module '*.worker?worker' {
  class Worker extends Worker {
    constructor();
  }
  export default Worker;
}