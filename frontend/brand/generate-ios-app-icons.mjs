import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const brandDir = dirname(fileURLToPath(import.meta.url));
const requireFromLanding = createRequire(join(brandDir, '../landing-page/package.json'));
const sharp = requireFromLanding('sharp');
const source = await readFile(join(brandDir, 'caresitter-app-icon.svg'));

for (const app of ['customer-app', 'caregiver-app']) {
  const iconDir = join(brandDir, '..', app, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset');
  const contents = JSON.parse(await readFile(join(iconDir, 'Contents.json'), 'utf8'));
  for (const image of contents.images) {
    if (!image.filename) continue;
    const points = Number.parseFloat(image.size.split('x')[0]);
    const scale = Number.parseFloat(image.scale);
    const pixels = Math.round(points * scale);
    await sharp(source)
      .resize(pixels, pixels)
      .flatten({ background: '#006B5B' })
      .removeAlpha()
      .png()
      .toFile(join(iconDir, image.filename));
  }
  process.stdout.write(`${app}: ${contents.images.length} iOS icons updated\n`);
}
