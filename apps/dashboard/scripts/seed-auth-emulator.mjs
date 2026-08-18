const host = process.env.FIREBASE_AUTH_EMULATOR_HOST ?? '127.0.0.1:9099';
const apiKey = process.env.FIREBASE_API_KEY ?? 'AIzaSyAzLUHa-EHLUJS4dQIaEPnn5g6XdnHY';
const endpoint = `http://${host}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`;
const email = process.env.SCAN_SERVE_STAFF_EMAIL ?? 'staff@scanserve.com';
const password = process.env.SCAN_SERVE_STAFF_PASSWORD ?? 'password124';

const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

async function seedStaffAccount() {
  for (let attempt = 1; attempt <= 10; attempt += 1) {
    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, returnSecureToken: false }),
      });
      const body = await response.json();
      if (response.ok || body.error?.message === 'EMAIL_EXISTS') {
        console.log(`[auth-emulator] Staff account ready: ${email}`);
        return;
      }
      throw new Error(body.error?.message ?? `HTTP ${response.status}`);
    } catch (error) {
      if (attempt === 10) {
        console.warn(`[auth-emulator] Emulator unavailable; skipped local staff seed: ${error.message}`);
        return;
      }
      await sleep(500);
    }
  }
}

await seedStaffAccount();
