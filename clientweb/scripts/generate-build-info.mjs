// Génère src/environments/build-info.ts avec l'horodatage du build.
// Lancé automatiquement via les hooks npm `prebuild` / `prestart`.
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, '..', 'src', 'environments', 'build-info.ts');
const timestamp = new Date().toISOString();

const content = `// Généré automatiquement au build (scripts/generate-build-info.mjs).
// Ne pas modifier à la main.
export const buildInfo = {
  timestamp: '${timestamp}',
} as const;
`;

writeFileSync(out, content);
console.log(`build-info.ts généré: ${timestamp}`);
