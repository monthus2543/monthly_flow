const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore} = require('firebase-admin/firestore');
const nodemailer = require('nodemailer');
const {ReportEmailError, sendReportEmail} = require('./report_email');

initializeApp();
const smtpConfig = defineSecret('REPORT_SMTP_CONFIG');
const firestore = getFirestore();

exports.emailExcelReport = onCall({region: 'us-central1', secrets: [smtpConfig],
  timeoutSeconds: 120, memory: '512MiB', maxInstances: 3}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first');
  let config;
  try {
    config = JSON.parse(smtpConfig.value());
    if (!config.host || !config.user || !config.password ||
        !/^[^\s<>@]+@[^\s<>@]+\.[^\s<>@]+$/.test(config.from) ||
        ![465, 587].includes(config.port)) throw new Error('Invalid SMTP config');
  } catch (_) {
    throw new HttpsError('failed-precondition', 'Configure report email', {key: 'export_email_setup'});
  }
  const transporter = nodemailer.createTransport({host: config.host, port: config.port,
    secure: config.port === 465, requireTLS: true,
    auth: {user: config.user, pass: config.password},
    connectionTimeout: 10000, greetingTimeout: 10000, socketTimeout: 30000,
    disableFileAccess: true, disableUrlAccess: true});
  const jobRef = (uid, id) => firestore.doc(`reportEmailJobs/${uid}/reports/${id}`);
  try {
    return await sendReportEmail(request, {
      getUser: (uid) => getAuth().getUser(uid),
      claim: (uid, id) => firestore.runTransaction(async (transaction) => {
        const job = jobRef(uid, id);
        const limit = firestore.doc(`reportEmailLimits/${uid}`);
        const [snapshot, limits] = await Promise.all([transaction.get(job), transaction.get(limit)]);
        if (snapshot.exists && snapshot.data().status !== 'failed') return snapshot.data().status;
        const now = Date.now();
        const day = new Date(now).toISOString().slice(0, 10);
        const data = limits.data() || {};
        const count = data.day === day ? data.count || 0 : 0;
        if (count >= 20 || now - (data.lastAttempt || 0) < 60000) {
          throw new ReportEmailError('resource-exhausted', 'export_email_limit');
        }
        transaction.set(limit, {day, count: count + 1, lastAttempt: now});
        transaction.set(job, {status: 'sending', updatedAt: now});
        return 'claimed';
      }),
      mark: (uid, id, status) => jobRef(uid, id).set({status, updatedAt: Date.now()}),
      send: async ({to, report}) => {
        const info = await transporter.sendMail({from: {name: 'Monthly Flow', address: config.from},
          to: {address: to}, subject: 'Monthly Flow · รายงาน Excel / Excel report',
          text: 'ไฟล์รายงาน Excel ที่คุณขอจาก Monthly Flow อยู่ในไฟล์แนบ\nYour requested Excel report is attached.',
          messageId: `<report-${report.id}@${config.from.split('@')[1]}>`,
          attachments: [{filename: report.filename, content: report.bytes,
            contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'}]});
        return info.accepted?.some((address) => String(address).toLowerCase() === to.toLowerCase());
      },
    });
  } catch (error) {
    if (error instanceof ReportEmailError) throw new HttpsError(error.code, error.key, {key: error.key});
    throw new HttpsError('internal', 'Report email failed', {key: 'export_email_failed'});
  } finally { transporter.close(); }
});
