// @ts-check
import { defineConfig } from 'astro/config';
import node from '@astrojs/node';
import tailwindcss from '@tailwindcss/vite';

// https://astro.build/config
export default defineConfig({
  output: 'server',
  adapter: node({ mode: 'standalone' }),
  vite: {
    envPrefix: ['PUBLIC_', 'BACKEND_URL', 'FRONTEND_URL'],
    plugins: [tailwindcss()],
  },
});
