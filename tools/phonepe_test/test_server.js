const http = require('http');
const crypto = require('crypto');
const { exec } = require('child_process');

const PORT = 3050;
const MERCHANT_ID = 'PGTESTPAYUAT86';
const SALT_KEY = '96434309-7796-489d-8924-ab56988a6076';
const SALT_INDEX = '1';
const HOST_URL = 'https://api-preprod.phonepe.com/apis/pg-sandbox';

let activeTransactionId = null;

// Helper: Calculate PhonePe Checksum Header
function getChecksum(payloadBase64, endpoint) {
  const data = payloadBase64 + endpoint + SALT_KEY;
  const hash = crypto.createHash('sha256').update(data).digest('hex');
  return `${hash}###${SALT_INDEX}`;
}

// 1. Create a local HTTP server to handle initiate & callback
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);

  if (url.pathname === '/') {
    // Landing test page
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>PhonePe Payment Gateway Sandbox Test</title>
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f0f4f9; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
          .card { background: white; padding: 32px; border-radius: 16px; box-shadow: 0 10px 25px rgba(0,0,0,0.08); max-width: 420px; width: 100%; text-align: center; }
          .logo { color: #5f259f; font-size: 28px; font-weight: 800; margin-bottom: 8px; }
          .badge { background: #e0d4fc; color: #5f259f; padding: 4px 12px; border-radius: 99px; font-size: 12px; font-weight: bold; display: inline-block; margin-bottom: 20px; }
          .price { font-size: 36px; font-weight: 800; color: #111; margin: 16px 0; }
          .desc { color: #666; font-size: 14px; margin-bottom: 24px; line-height: 1.5; }
          button { background: #5f259f; color: white; border: none; padding: 14px 28px; border-radius: 10px; font-size: 16px; font-weight: bold; cursor: pointer; width: 100%; transition: 0.2s; }
          button:hover { background: #4b1c7f; }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="logo">PhonePe PG Test</div>
          <span class="badge">SANDBOX ENVIRONMENT</span>
          <div class="desc">Testing Room Rental Payment Flow before app integration.</div>
          <div class="price">₹100.00</div>
          <form action="/pay" method="POST">
            <button type="submit">Pay Now with PhonePe Simulator &rarr;</button>
          </form>
        </div>
      </body>
      </html>
    `);
    return;
  }

  if (url.pathname === '/pay' && req.method === 'POST') {
    // Initiate transaction with PhonePe Sandbox
    activeTransactionId = 'RENT_' + Date.now();
    const amountInPaise = 10000; // Rs 100

    const payload = {
      merchantId: MERCHANT_ID,
      merchantTransactionId: activeTransactionId,
      merchantUserId: 'GUEST_USER_001',
      amount: amountInPaise,
      redirectUrl: `http://localhost:${PORT}/callback`,
      redirectMode: 'REDIRECT',
      callbackUrl: `http://localhost:${PORT}/webhook`,
      mobileNumber: '9876543210',
      paymentInstrument: {
        type: 'PAY_PAGE'
      }
    };

    const base64Payload = Buffer.from(JSON.stringify(payload)).toString('base64');
    const checksum = getChecksum(base64Payload, '/pg/v1/pay');

    try {
      const response = await fetch(`${HOST_URL}/pg/v1/pay`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-VERIFY': checksum,
          'accept': 'application/json'
        },
        body: JSON.stringify({ request: base64Payload })
      });

      const data = await response.json();

      if (data.success && data.data && data.data.instrumentResponse && data.data.instrumentResponse.redirectInfo) {
        const checkoutUrl = data.data.instrumentResponse.redirectInfo.url;
        res.writeHead(302, { Location: checkoutUrl });
        res.end();
      } else {
        res.writeHead(500, { 'Content-Type': 'text/plain' });
        res.end(`Failed to initiate PhonePe payment:\n${JSON.stringify(data, null, 2)}`);
      }
    } catch (err) {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end(`Error contacting PhonePe: ${err.message}`);
    }
    return;
  }

  if (url.pathname === '/callback') {
    // PhonePe redirects back here after user simulates payment
    const checkString = `/pg/v1/status/${MERCHANT_ID}/${activeTransactionId}` + SALT_KEY;
    const checkHash = crypto.createHash('sha256').update(checkString).digest('hex');
    const checkSignature = `${checkHash}###${SALT_INDEX}`;

    try {
      const statusRes = await fetch(`${HOST_URL}/pg/v1/status/${MERCHANT_ID}/${activeTransactionId}`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
          'X-VERIFY': checkSignature,
          'X-MERCHANT-ID': MERCHANT_ID,
          'accept': 'application/json'
        }
      });

      const statusData = await statusRes.json();
      const isSuccess = statusData.code === 'PAYMENT_SUCCESS';

      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(`
        <!DOCTYPE html>
        <html>
        <head>
          <title>PhonePe Verification Result</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f0f4f9; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
            .card { background: white; padding: 32px; border-radius: 16px; box-shadow: 0 10px 25px rgba(0,0,0,0.08); max-width: 480px; width: 100%; }
            .status-icon { font-size: 54px; margin-bottom: 12px; }
            .status-title { font-size: 24px; font-weight: bold; margin-bottom: 8px; color: ${isSuccess ? '#16a34a' : '#dc2626'}; }
            .detail-row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #f1f5f9; font-size: 14px; }
            .detail-label { color: #64748b; }
            .detail-val { font-weight: 600; color: #0f172a; word-break: break-all; }
            .json-box { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 12px; font-size: 11px; text-align: left; overflow: auto; max-height: 180px; margin-top: 16px; font-family: monospace; }
            a.btn { display: inline-block; margin-top: 20px; background: #5f259f; color: white; text-decoration: none; padding: 10px 20px; border-radius: 8px; font-weight: 600; font-size: 14px; }
          </style>
        </head>
        <body>
          <div class="card">
            <div style="text-align: center;">
              <div class="status-icon">${isSuccess ? '✅' : '⚠️'}</div>
              <div class="status-title">${statusData.code}</div>
              <p style="color: #64748b; margin-top: 0;">${statusData.message}</p>
            </div>

            <div class="detail-row">
              <span class="detail-label">Transaction ID:</span>
              <span class="detail-val">${activeTransactionId}</span>
            </div>
            <div class="detail-row">
              <span class="detail-label">Amount:</span>
              <span class="detail-val">₹${(statusData.data?.amount || 0) / 100}</span>
            </div>
            <div class="detail-row">
              <span class="detail-label">Gateway Bank Ref:</span>
              <span class="detail-val">${statusData.data?.transactionId || 'N/A'}</span>
            </div>

            <div class="json-box">${JSON.stringify(statusData, null, 2)}</div>
            <div style="text-align: center;">
              <a href="/" class="btn">Test Another Payment &rarr;</a>
            </div>
          </div>
        </body>
        </html>
      `);
    } catch (err) {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end(`Status verification failed: ${err.message}`);
    }
    return;
  }

  res.writeHead(404, { 'Content-Type': 'text/plain' });
  res.end('Not Found');
});

server.listen(PORT, () => {
  console.log(`\n======================================================`);
  console.log(`🚀 PhonePe Sandbox Test Server Running!`);
  console.log(`🔗 Open in your browser: http://localhost:${PORT}`);
  console.log(`======================================================\n`);
  
  // Auto-open browser on macOS
  exec(`open http://localhost:${PORT}`);
});
