const nodemailer = require('nodemailer');

async function verifySmtp(config) {
  if (!config.host || !config.user || !config.password || !config.from ||
      ![465, 587].includes(config.port)) throw new Error('Invalid SMTP settings');
  const client = nodemailer.createTransport({host: config.host, port: config.port,
    secure: config.port === 465, requireTLS: true,
    auth: {user: config.user, pass: config.password},
    connectionTimeout: 10000, greetingTimeout: 10000, socketTimeout: 30000});
  try { await client.verify(); } finally { client.close(); }
}

if (require.main === module) {
  let input = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', (chunk) => { input += chunk; });
  process.stdin.on('end', async () => {
    try {
      const config = JSON.parse(input.trim());
      input = '';
      await verifySmtp(config);
      console.log('SMTP connection and authentication verified. No email was sent.');
    } catch (_) {
      // Never print SMTP responses: they can contain server credentials or identifiers.
      console.error('SMTP verification failed. Check host, port, username and password.');
      process.exitCode = 1;
    }
  });
}

module.exports = {verifySmtp};
