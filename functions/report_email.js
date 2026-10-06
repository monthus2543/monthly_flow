const {createHash} = require('node:crypto');

class ReportEmailError extends Error {
  constructor(code, key) { super(key); this.code = code; this.key = key; }
}

function validateReport(data) {
  if (!data || typeof data.filename !== 'string' ||
      !/^[A-Za-z0-9_-]{1,160}\.xlsx$/.test(data.filename) ||
      typeof data.contentBase64 !== 'string' ||
      data.contentBase64.length > Math.ceil(5 * 1024 * 1024 / 3) * 4) {
    throw new ReportEmailError('invalid-argument', 'export_email_too_large');
  }
  const bytes = Buffer.from(data.contentBase64, 'base64');
  if (bytes.length > 5 * 1024 * 1024 || bytes.length < 4 ||
      bytes.toString('base64') !== data.contentBase64 ||
      !bytes.subarray(0, 4).equals(Buffer.from([0x50, 0x4b, 0x03, 0x04]))) {
    throw new ReportEmailError('invalid-argument', 'export_email_failed');
  }
  const id = createHash('sha256').update(data.filename).update(bytes).digest('hex');
  if (data.requestId !== id) throw new ReportEmailError('invalid-argument', 'export_email_failed');
  return {id, bytes, filename: data.filename};
}

async function sendReportEmail(request, services) {
  if (!request.auth?.uid) throw new ReportEmailError('unauthenticated', 'export_account_changed');
  const report = validateReport(request.data);
  // The recipient always comes from Firebase Auth, never from request.data.
  const user = await services.getUser(request.auth.uid);
  if (user.disabled || !user.email || !user.emailVerified) {
    throw new ReportEmailError('failed-precondition', 'export_email_verified_required');
  }
  const status = await services.claim(user.uid, report.id);
  if (status === 'sent') return {status: 'sent'};
  if (status !== 'claimed') throw new ReportEmailError('aborted', 'export_email_pending');
  try {
    const accepted = await services.send({to: user.email, report});
    if (!accepted) throw new ReportEmailError('unavailable', 'export_email_failed');
    await services.mark(user.uid, report.id, 'sent');
    return {status: 'sent'};
  } catch (error) {
    // A broken socket after SMTP DATA can mean the email was accepted.
    // Do not automatically resend an ambiguous outcome.
    const definiteFailure = error instanceof ReportEmailError ||
      ['EAUTH', 'EDNS', 'EENVELOPE', 'ETLS'].includes(error.code) || error.responseCode >= 400;
    try { await services.mark(user.uid, report.id, definiteFailure ? 'failed' : 'uncertain'); }
    catch (_) { /* The pre-send job remains locked when the status write fails. */ }
    throw new ReportEmailError('unavailable', definiteFailure ? 'export_email_failed' : 'export_email_pending');
  }
}

module.exports = {ReportEmailError, validateReport, sendReportEmail};
