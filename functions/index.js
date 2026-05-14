const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

// ── Send OTP to email for password reset ──────────────────────────────────────
exports.sendResetOtp = onCall(async (request) => {
  const { email } = request.data;
  if (!email) throw new HttpsError('invalid-argument', 'Email is required');

  // Check user exists in Firebase
  try {
    await admin.auth().getUserByEmail(email);
  } catch (_) {
    // Return success even if email not found (security best practice)
    return { success: true };
  }

  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = Date.now() + 10 * 60 * 1000; // 10 minutes

  // Store OTP in Firestore
  await admin.firestore().collection('_password_resets').doc(email).set({
    otp,
    expiresAt,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Send OTP via EmailJS (same service that works for registration)
  await axios.post('https://api.emailjs.com/api/v1.0/email/send', {
    service_id:  'service_ezvt2r2',
    template_id: 'template_so1q2yf',
    user_id:     'C48yDMHg-ri1SjfYx',
    template_params: { to_email: email, otp_code: otp },
  }, {
    headers: { 'Content-Type': 'application/json', 'origin': 'http://localhost' },
  });

  return { success: true };
});

// ── Verify OTP and update password directly ───────────────────────────────────
exports.resetPasswordWithOtp = onCall(async (request) => {
  const { email, otp, newPassword } = request.data;

  if (!email || !otp || !newPassword) {
    throw new HttpsError('invalid-argument', 'All fields are required');
  }
  if (newPassword.length < 8) {
    throw new HttpsError('invalid-argument', 'Password must be at least 8 characters');
  }

  const doc = await admin.firestore().collection('_password_resets').doc(email).get();

  if (!doc.exists) {
    throw new HttpsError('not-found', 'No reset request found. Please request a new code.');
  }

  const { otp: storedOtp, expiresAt } = doc.data();

  if (Date.now() > expiresAt) {
    await doc.ref.delete();
    throw new HttpsError('deadline-exceeded', 'Code expired. Please request a new one.');
  }

  if (otp !== storedOtp) {
    throw new HttpsError('invalid-argument', 'Incorrect code. Please try again.');
  }

  // Update password directly using Firebase Admin — no email link needed
  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().updateUser(user.uid, { password: newPassword });

  await doc.ref.delete();

  return { success: true };
});
