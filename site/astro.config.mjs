import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import tailwindcss from '@tailwindcss/vite';

// 公開先は https://tarabakz25.github.io/choco/（リポジトリ名 choco 前提。docs/release.md 参照）
export default defineConfig({
  site: 'https://tarabakz25.github.io',
  base: '/choco',
  trailingSlash: 'always',
  integrations: [react()],
  vite: { plugins: [tailwindcss()] },
});
