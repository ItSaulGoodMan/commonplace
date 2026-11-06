import { cloudflareTest, readD1Migrations } from '@cloudflare/vitest-plugin';
import { defineConfig } from 'vitest/config';

export default defineConfig(async () => {
  const migrations = await readD1Migrations('./migrations');
  return {
    plugins: [
      cloudflareTest({
        wrangler: { configPath: './wrangler.jsonc', environment: 'dev' },
        miniflare: {
          bindings: {
            TEST_MIGRATIONS: migrations,
            GEMINI_API_KEY: 'AIzaTESTFREEKEY',
            GEMINI_PAID_API_KEY: '',
            SESSION_SECRET: 'test-only-session-secret-0123456789abcdef',
            PLAY_SERVICE_ACCOUNT: '',
          },
        },
      }),
    ],
    test: { setupFiles: ['./test/setup.ts'] },
  };
});
