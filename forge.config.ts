import type { ForgeConfig } from '@electron-forge/shared-types';
import { MakerSquirrel } from '@electron-forge/maker-squirrel';
import { MakerZIP } from '@electron-forge/maker-zip';
import { MakerDeb } from '@electron-forge/maker-deb';
import { MakerRpm } from '@electron-forge/maker-rpm';
import { VitePlugin } from '@electron-forge/plugin-vite';
import { FusesPlugin } from '@electron-forge/plugin-fuses';
import { FuseV1Options, FuseVersion } from '@electron/fuses';
import path from 'path';

const config: ForgeConfig = {
  packagerConfig: {
    asar: true,
  },
  rebuildConfig: {},
  makers: [
    new MakerSquirrel({}),
    new MakerZIP({}, ['darwin']),
    new MakerRpm({}),
    new MakerDeb({}),
  ],
  plugins: [
    new VitePlugin({
      // ──────────────────────────────────────────────
      // Main process, preload, workers go in "build"
      build: [
        {
          // Main process
          entry: 'src/main.mts',                     // your main entry file
          config: path.resolve(__dirname, 'vite.main.config.mts'),
        },
        {
          // Preload script (if you have one)
          entry: 'src/preload.mts',
          config: path.resolve(__dirname, 'vite.preload.config.mts'),
        },
        // Add more entries here if you have workers or other builds
      ],

      // Renderer processes (can have multiple windows)
      renderer: [
        {
          name: 'main_window',                        // must match the name you use in BrowserWindow
          config: path.resolve(__dirname, 'vite.renderer.config.mts'),
        },
        // You can add more renderers here if needed (e.g. secondary windows)
      ],
    }),

    // Uncomment this only when you are ready to package
    // new FusesPlugin({
    //   version: FuseVersion.V1,
    //   [FuseV1Options.RunAsNode]: false,
    //   [FuseV1Options.EnableCookieEncryption]: true,
    //   [FuseV1Options.EnableNodeOptionsEnvironmentVariable]: false,
    //   [FuseV1Options.EnableNodeCliInspectArguments]: false,
    //   [FuseV1Options.EnableEmbeddedAsarIntegrityValidation]: true,
    //   [FuseV1Options.OnlyLoadAppFromAsar]: true,
    // }),
  ],
};

export default config;