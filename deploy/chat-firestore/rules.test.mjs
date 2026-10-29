import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, limit, query, setDoc } from 'firebase/firestore';

let environment;
const bookingId = 'booking-conversation';
const supportId = 'support-conversation';
const bookingEpoch = 'epoch-current';
const supportEpoch = supportId;
const auth = (uid, expiresAtMs = Date.now() + 60_000) =>
  environment.authenticatedContext(uid, { careSessionExpiresAtMs: expiresAtMs });

const message = (db, conversationId, epochId) =>
  doc(db, 'chatConversations', conversationId, 'epochs', epochId, 'messages', 'message-1');
const messages = (db, conversationId, epochId) =>
  collection(db, 'chatConversations', conversationId, 'epochs', epochId, 'messages');

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'demo-caresitter-chat',
    firestore: {
      host: '127.0.0.1', port: 8088,
      rules: readFileSync(new URL('./firestore.rules', import.meta.url), 'utf8'),
    },
  });
});
after(async () => environment?.cleanup());
beforeEach(async () => {
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const [uid, active, activeAdmin] of [
      ['customer', true, false], ['caregiver', true, false],
      ['other', true, false], ['old-caregiver', true, false],
      ['admin', true, true], ['old-admin', true, true], ['blocked', false, false],
    ]) {
      await setDoc(doc(db, 'chatUserAccess', uid), {
        active, activeAdmin, activeCaregiver: ['caregiver', 'old-caregiver'].includes(uid),
      });
    }
    await setDoc(doc(db, 'chatConversations', bookingId), {
      type: 'BOOKING', ownerUserId: 'customer', caregiverUserId: 'caregiver',
      activeEpochId: bookingEpoch, readEnabled: true, retainedUntil: null,
    });
    await setDoc(doc(db, 'chatConversations', bookingId, 'epochs', bookingEpoch), { number: 1 });
    for (const [uid, role] of [['customer', 'CUSTOMER'], ['caregiver', 'CAREGIVER']]) {
      await setDoc(doc(db, 'chatConversations', bookingId, 'epochs', bookingEpoch, 'members', uid), { role });
    }
    await setDoc(message(db, bookingId, bookingEpoch), { sequence: 1, body: 'Hi' });
    await setDoc(doc(db, 'chatConversations', supportId), {
      type: 'SUPPORT', ownerUserId: 'customer', assignedAdminId: 'admin',
      activeEpochId: supportEpoch, readEnabled: true,
    });
    await setDoc(doc(db, 'chatConversations', supportId, 'epochs', supportEpoch), { number: 1 });
    for (const [uid, role] of [['customer', 'OWNER'], ['admin', 'ADMIN'], ['old-admin', 'ADMIN']]) {
      await setDoc(doc(db, 'chatConversations', supportId, 'epochs', supportEpoch, 'members', uid), { role });
    }
    await setDoc(message(db, supportId, supportEpoch), { sequence: 1, body: 'Help' });
  });
});

test('booking owner and current caregiver can read only their scoped messages', async () => {
  for (const uid of ['customer', 'caregiver']) {
    const db = auth(uid).firestore();
    await assertSucceeds(getDoc(message(db, bookingId, bookingEpoch)));
    await assertSucceeds(getDocs(query(messages(db, bookingId, bookingEpoch), limit(50))));
  }
  const other = auth('other').firestore();
  await assertFails(getDoc(message(other, bookingId, bookingEpoch)));
  await assertFails(getDocs(query(messages(other, bookingId, bookingEpoch), limit(50))));
  await assertFails(getDoc(message(environment.unauthenticatedContext().firestore(),
    bookingId, bookingEpoch)));
});

test('former caregiver loses read access when the active epoch changes', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'chatConversations', bookingId, 'epochs', 'epoch-old'), { number: 0 });
    await setDoc(doc(db, 'chatConversations', bookingId, 'epochs', 'epoch-old', 'members', 'old-caregiver'),
      { role: 'CAREGIVER' });
    await setDoc(message(db, bookingId, 'epoch-old'), { sequence: 0, body: 'Old' });
  });
  const db = auth('old-caregiver').firestore();
  await assertFails(getDoc(message(db, bookingId, 'epoch-old')));
});

test('removing the caregiver role denies reads even while the assignment still exists', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'chatUserAccess', 'caregiver'),
      { active: true, activeAdmin: false, activeCaregiver: false });
  });
  const db = auth('caregiver').firestore();
  await assertFails(getDoc(doc(db, 'chatConversations', bookingId)));
  await assertFails(getDoc(message(db, bookingId, bookingEpoch)));
});

test('blocked accounts and client writes are denied', async () => {
  const blocked = auth('blocked').firestore();
  await assertFails(getDoc(message(blocked, supportId, supportEpoch)));
  const customer = auth('customer').firestore();
  await assertFails(setDoc(message(customer, bookingId, bookingEpoch), { body: 'overwrite' }));
  await assertFails(getDocs(messages(customer, bookingId, bookingEpoch)));
  await assertFails(getDocs(query(messages(customer, bookingId, bookingEpoch), limit(101))));
  await assertFails(getDocs(query(collection(customer, 'chatConversations'), limit(10))));
  await assertFails(getDoc(message(auth('customer', Date.now() - 1000).firestore(),
    bookingId, bookingEpoch)));
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'chatUserAccess', 'customer'),
      { active: false, activeAdmin: false });
  });
  await assertFails(getDoc(message(customer, bookingId, bookingEpoch)));
});

test('booking content is denied after its retention deadline', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'chatConversations', bookingId),
      { type: 'BOOKING', ownerUserId: 'customer', caregiverUserId: 'caregiver',
        activeEpochId: bookingEpoch, readEnabled: true,
        retainedUntil: new Date('2020-01-01T00:00:00Z') });
  });
  await assertFails(getDoc(message(auth('customer').firestore(),
    bookingId, bookingEpoch)));
});

test('support owner and assigned active admin can read; prior admin cannot', async () => {
  for (const uid of ['customer', 'admin']) {
    await assertSucceeds(getDoc(message(auth(uid).firestore(),
      supportId, supportEpoch)));
  }
  await assertFails(getDoc(message(auth('old-admin').firestore(),
    supportId, supportEpoch)));
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'chatUserAccess', 'admin'),
      { active: true, activeAdmin: false });
  });
  await assertFails(getDoc(message(auth('admin').firestore(),
    supportId, supportEpoch)));
});
