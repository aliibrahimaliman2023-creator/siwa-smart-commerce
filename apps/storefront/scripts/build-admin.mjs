import { cp, mkdir, rm } from 'node:fs/promises';
import { resolve } from 'node:path';
import { build } from 'vite';
import react from '@vitejs/plugin-react';

const cwd = process.cwd();
const source = resolve(cwd, '../admin');
const tempRoot = resolve(cwd, '.admin-build');
const output = resolve(cwd, 'dist/admin');

await rm(tempRoot, { recursive: true, force: true });
await mkdir(tempRoot, { recursive: true });
await cp(source, tempRoot, { recursive: true });

try {
  await build({
    root: tempRoot,
    base: '/admin/',
    plugins: [react()],
    build: {
      outDir: output,
      emptyOutDir: true
    }
  });
} finally {
  await rm(tempRoot, { recursive: true, force: true });
}
