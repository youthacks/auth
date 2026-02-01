// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';

// https://astro.build/config
export default defineConfig({
  vite: {
    envDir: '../',
    envPrefix: ['PUBLIC_', 'BACKEND_URL', 'FRONTEND_URL'],
    plugins: [tailwindcss()],
  },
});
