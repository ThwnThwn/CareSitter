import { readFileSync } from 'node:fs';
import { before, after, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { ref, uploadBytes, getBytes, deleteObject, listAll, updateMetadata } from 'firebase/storage';

let env;
const path = 'reports/owner/0123456789abcdef0123456789abcdef.pdf';
const pdf = new TextEncoder().encode('%PDF-1.7\nsynthetic fixture\n%%EOF\n');
const checksum = 'a'.repeat(64);
const metadata = { contentType: 'application/pdf', customMetadata: { sha256: checksum } };
const auth = (uid = 'owner', overrides = {}) => env.authenticatedContext(uid, {
  careSessionExpiresAtMs: Date.now() + 60_000, careReportPath: path,
  careReportSize: pdf.length, careReportChecksum: checksum, ...overrides,
}).storage();

before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-caresitter-reports', storage: {
    host: '127.0.0.1', port: 9199, rules: readFileSync(new URL('./storage.rules', import.meta.url), 'utf8'),
  }});
});
after(async () => env?.cleanup());
beforeEach(async () => env.clearStorage());
const seed = () => env.withSecurityRulesDisabled(ctx => uploadBytes(ref(ctx.storage(), path), pdf, metadata));

test('owner uploads the exact intent and can read its PDF', async () => {
  const object = ref(auth(), path);
  await assertSucceeds(uploadBytes(object, pdf, metadata));
  await assertSucceeds(getBytes(object));
});
test('anonymous and foreign account cannot read or upload', async () => {
  await seed();
  for (const storage of [env.unauthenticatedContext().storage(), auth('other')]) {
    await assertFails(getBytes(ref(storage, path)));
    await assertFails(uploadBytes(ref(storage, path.replace('0123', 'abcd')), pdf, metadata));
  }
});
test('expired session and unscoped Google or chat token cannot access reports', async () => {
  await seed();
  for (const storage of [auth('owner', { careSessionExpiresAtMs: Date.now() - 1 }),
    env.authenticatedContext('owner').storage(),
    env.authenticatedContext('owner', { careSessionExpiresAtMs: Date.now() + 60_000 }).storage()]) {
    await assertFails(getBytes(ref(storage, path)));
  }
});
test('wrong path, checksum, MIME, registered size and over-limit PDF are rejected', async () => {
  await assertFails(uploadBytes(ref(auth(), path.replace('0123', 'abcd')), pdf, metadata));
  await assertFails(uploadBytes(ref(auth(), path), pdf, { ...metadata, contentType: 'image/png' }));
  await assertFails(uploadBytes(ref(auth(), path), pdf, { ...metadata, customMetadata: { sha256: 'b'.repeat(64) } }));
  await assertFails(uploadBytes(ref(auth('owner', { careReportSize: pdf.length + 1 }), path), pdf, metadata));
  const huge = new Uint8Array(10 * 1024 * 1024 + 1);
  await assertFails(uploadBytes(ref(auth('owner', { careReportSize: huge.length }), path), huge, metadata));
});
test('owner cannot overwrite, alter metadata, delete or list files', async () => {
  await seed();
  const storage = auth();
  await assertFails(uploadBytes(ref(storage, path), pdf, metadata));
  await assertFails(updateMetadata(ref(storage, path), { contentType: 'image/png' }));
  await assertFails(deleteObject(ref(storage, path)));
  await assertFails(listAll(ref(storage, 'reports/owner')));
});
test('every path outside reports is denied', async () => {
  await assertFails(uploadBytes(ref(auth(), 'public/file.pdf'), pdf, metadata));
});
