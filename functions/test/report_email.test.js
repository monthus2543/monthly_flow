const {test} = require('node:test');
const assert = require('node:assert/strict');
const {createHash} = require('node:crypto');
const {sendReportEmail, validateReport} = require('../report_email');

function request() {
  const bytes = Buffer.from([0x50, 0x4b, 0x03, 0x04, 1, 2, 3]);
  const filename = 'MonthlyFlow_2026.xlsx';
  return {auth: {uid: 'first'}, data: {filename, contentBase64: bytes.toString('base64'),
    requestId: createHash('sha256').update(filename).update(bytes).digest('hex'),
    to: 'attacker@example.com'}};
}
function services() {
  const states = new Map();
  const messages = [];
  return {states, messages,
    getUser: async (uid) => ({uid, email: `${uid}@example.com`, emailVerified: true}),
    claim: async (uid, id) => {
      const key = `${uid}/${id}`, status = states.get(key);
      if (status && status !== 'failed') return status;
      states.set(key, 'sending'); return 'claimed';
    },
    mark: async (uid, id, state) => states.set(`${uid}/${id}`, state),
    send: async (message) => { messages.push(message); return true; },
  };
}

test('recipient is taken from verified Firebase account and file is attached', async () => {
  const s = services();
  assert.deepEqual(await sendReportEmail(request(), s), {status: 'sent'});
  assert.equal(s.messages[0].to, 'first@example.com');
  assert.equal(s.messages[0].report.filename, 'MonthlyFlow_2026.xlsx');
  assert.equal(s.messages[0].report.bytes.length, 7);
});
test('unauthenticated and unverified accounts cannot send', async () => {
  const s = services();
  const r = request(); delete r.auth;
  await assert.rejects(sendReportEmail(r, s), {code: 'unauthenticated'});
  s.getUser = async () => ({uid: 'first', email: 'first@example.com', emailVerified: false});
  await assert.rejects(sendReportEmail(request(), s), {key: 'export_email_verified_required'});
  assert.equal(s.messages.length, 0);
});
test('retries and concurrent calls do not send duplicates', async () => {
  const s = services();
  const results = await Promise.allSettled([sendReportEmail(request(), s), sendReportEmail(request(), s)]);
  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  assert.equal(s.messages.length, 1);
  assert.deepEqual(await sendReportEmail(request(), s), {status: 'sent'});
  assert.equal(s.messages.length, 1);
});
test('ambiguous SMTP timeout is locked instead of automatically resent', async () => {
  const s = services();
  s.send = async () => { throw Object.assign(new Error('Timeout'), {code: 'ETIMEDOUT'}); };
  await assert.rejects(sendReportEmail(request(), s), {key: 'export_email_pending'});
  s.send = async () => { throw new Error('Must not send'); };
  await assert.rejects(sendReportEmail(request(), s), {key: 'export_email_pending'});
  assert.equal([...s.states.values()][0], 'uncertain');
});
test('SMTP rejection can safely be retried and jobs are separated by account', async () => {
  const s = services();
  s.send = async () => { throw Object.assign(new Error('Rejected'), {responseCode: 450}); };
  await assert.rejects(sendReportEmail(request(), s), {key: 'export_email_failed'});
  s.send = async (m) => { s.messages.push(m); return true; };
  await sendReportEmail(request(), s);
  const second = request(); second.auth.uid = 'second';
  await sendReportEmail(second, s);
  assert.equal(s.messages.length, 2);
  assert.equal(s.messages[1].to, 'second@example.com');
});
test('invalid attachment, unsafe filename and oversized content are rejected', () => {
  const r = request();
  assert.throws(() => validateReport({...r.data, filename: '../report.xlsx'}));
  assert.throws(() => validateReport({...r.data, contentBase64: 'not a file'}));
  assert.throws(() => validateReport({...r.data, contentBase64: 'A'.repeat(7 * 1024 * 1024)}));
});
