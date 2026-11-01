// Builds dist/aiterm-linux-<arch>/aiterm (a self-contained copy of the app). Run with `npm run package`.
const path = require('path');
const { packager } = require('@electron/packager');

const root = path.join(__dirname, '..');

packager({
  dir: root,
  out: path.join(root, 'dist'),
  name: 'aiterm',
  executableName: 'aiterm',
  platform: 'linux',
  arch: process.arch,
  overwrite: true,
  prune: true,
  // node-pty's native binary must stay a real file on disk.
  asar: false,
  ignore: [
    // Only the runtime packages: node-pty (+ its Linux binaries) and xterm.
    /^\/node_modules\/(?!@lydell($|\/node-pty($|\/)|\/node-pty-linux-[^/]+($|\/))|@xterm($|\/))/,
    /^\/package-lock\.json$/,
    /^\/dist($|\/)/,
    /^\/build\/(?!icon\.png$)/,
    /^\/(install|uninstall|rebuild)\.sh$/,
    /^\/CLAUDE\.md$/,
    /^\/\.gitignore$/,
  ],
})
  .then((dirs) => console.log('Packaged to', dirs.join(', ')))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
