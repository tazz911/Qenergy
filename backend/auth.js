// backend/src/routes/auth.js
// Node.js / Express backend — OTP + bcrypt password hashing

const express = require('express');
const bcrypt = require('bcrypt');
const crypto = require('crypto');
const nodemailer = require('nodemailer');
const admin = require('firebase-admin');
const axios = require('axios');

const router = express.Router();
const db = admin.firestore();

const SALT_ROUNDS = 12;
const OTP_EXPIRY_MINUTES = 10;

// ── Email transporter (configure with your SMTP)
const transporter = nodemailer.createTransporter({
  host: process.env.SMTP_HOST,
  port: 587,
  secure: false,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

//  generate 6-digit OTP
function generateOtp() {
  return crypto.randomInt(100000, 999999).toString();
}

// send OTP email 
async function sendOtpEmail(email, otp, fullName) {
  await transporter.sendMail({
    from: `"EnergyIQ" <${process.env.SMTP_USER}>`,
    to: email,
    subject: 'Your EnergyIQ verification code',
    html: `
      <div style="font-family:sans-serif;max-width:480px;margin:0 auto;">
        <h2 style="color:#00D4AA;">EnergyIQ — Email Verification</h2>
        <p>Hi ${fullName},</p>
        <p>Your verification code is:</p>
        <div style="font-size:36px;font-weight:bold;letter-spacing:12px;color:#0A0F1E;
                    background:#F0F4FF;padding:16px 24px;border-radius:8px;display:inline-block;margin:12px 0;">
          ${otp}
        </div>
        <p style="color:#8B9CC8;">This code expires in <strong>${OTP_EXPIRY_MINUTES} minutes</strong>.</p>
        <p style="color:#8B9CC8;font-size:12px;">If you didn't request this, please ignore this email.</p>
      </div>
    `,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// POST /api/auth/register
// Body: { fullName, email, password }
// 1. Hash password with bcrypt
// 2. Create Firebase Auth user
// 3. Generate OTP → store in Firestore (hashed)
// 4. Send OTP email
// ══════════════════════════════════════════════════════════════════════════════
router.post('/register', async (req, res) => {
  try {
    const { fullName, email, password } = req.body;

    if (!fullName || !email || !password) {
      return res.status(400).json({ error: 'All fields are required.' });
    }
    if (password.length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters.' });
    }

    // 1. Hash password with bcrypt (salt rounds: 12)
    const hashedPassword = await bcrypt.hash(password, SALT_ROUNDS);

    // 2. Create Firebase Auth user (password stored by Firebase — we also
    //    store the bcrypt hash in Firestore for your own records/migration)
    const userRecord = await admin.auth().createUser({
      email,
      password, // Firebase Auth handles its own hashing internally
      displayName: fullName,
      emailVerified: false,
    });

    // 3. Save user document to Firestore with bcrypt hash
    await db.collection('users').doc(userRecord.uid).set({
      user_id: userRecord.uid,
      full_name: fullName,
      email,
      password_hash: hashedPassword, // bcrypt hash — NEVER store plain text
      email_verified: false,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 4. Generate OTP
    const otp = generateOtp();
    const otpHash = await bcrypt.hash(otp, 10); // also hash the OTP itself
    const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);

    // Store OTP record in Firestore
    await db.collection('otp_verifications').doc(userRecord.uid).set({
      user_id: userRecord.uid,
      email,
      otp_hash: otpHash,
      expires_at: admin.firestore.Timestamp.fromDate(expiresAt),
      verified: false,
      attempts: 0,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 5. Send OTP via email
    await sendOtpEmail(email, otp, fullName);

    return res.status(201).json({
      message: 'Account created. Please verify your email.',
      uid: userRecord.uid,
    });

  } catch (err) {
    console.error('Register error:', err);
    if (err.code === 'auth/email-already-exists') {
      return res.status(409).json({ error: 'An account already exists for this email.' });
    }
    return res.status(500).json({ error: 'Registration failed. Please try again.' });
  }
});

// ══════════════════════════════════════════════════════════════════════════════
// POST /api/auth/verify-otp
// Body: { uid, otp }
// Validates OTP, marks email as verified
// ══════════════════════════════════════════════════════════════════════════════
router.post('/verify-otp', async (req, res) => {
  try {
    const { uid, otp } = req.body;
    if (!uid || !otp) return res.status(400).json({ error: 'uid and otp are required.' });

    const otpDoc = await db.collection('otp_verifications').doc(uid).get();
    if (!otpDoc.exists) return res.status(404).json({ error: 'OTP record not found.' });

    const data = otpDoc.data();

    // Check expiry
    if (data.expires_at.toDate() < new Date()) {
      return res.status(410).json({ error: 'OTP has expired. Please request a new one.' });
    }

    // Max attempts guard (prevent brute force)
    if (data.attempts >= 5) {
      return res.status(429).json({ error: 'Too many attempts. Please request a new code.' });
    }

    // Increment attempt counter
    await db.collection('otp_verifications').doc(uid).update({
      attempts: admin.firestore.FieldValue.increment(1),
    });

    // Verify OTP hash
    const match = await bcrypt.compare(otp, data.otp_hash);
    if (!match) {
      return res.status(401).json({ error: 'Incorrect code. Please try again.' });
    }

    // Mark verified in both OTP record and user doc
    await Promise.all([
      db.collection('otp_verifications').doc(uid).update({ verified: true }),
      db.collection('users').doc(uid).update({ email_verified: true }),
      admin.auth().updateUser(uid, { emailVerified: true }),
    ]);

    // Generate a custom token for the client to sign in
    const customToken = await admin.auth().createCustomToken(uid);

    return res.status(200).json({
      message: 'Email verified successfully.',
      customToken,
    });

  } catch (err) {
    console.error('Verify OTP error:', err);
    return res.status(500).json({ error: 'Verification failed. Please try again.' });
  }
});

// ══════════════════════════════════════════════════════════════════════════════
// POST /api/auth/resend-otp
// Body: { uid }
// ══════════════════════════════════════════════════════════════════════════════
router.post('/resend-otp', async (req, res) => {
  try {
    const { uid } = req.body;
    if (!uid) return res.status(400).json({ error: 'uid is required.' });

    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists) return res.status(404).json({ error: 'User not found.' });

    const { email, full_name } = userDoc.data();
    const otp = generateOtp();
    const otpHash = await bcrypt.hash(otp, 10);
    const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);

    await db.collection('otp_verifications').doc(uid).set({
      user_id: uid, email,
      otp_hash: otpHash,
      expires_at: admin.firestore.Timestamp.fromDate(expiresAt),
      verified: false, attempts: 0,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    await sendOtpEmail(email, otp, full_name);
    return res.status(200).json({ message: 'New OTP sent.' });

  } catch (err) {
    console.error('Resend OTP error:', err);
    return res.status(500).json({ error: 'Failed to resend OTP.' });
  }
});

// ══════════════════════════════════════════════════════════════════════════════
// POST /api/auth/login
// Body: { email, password }
// Firebase Auth handles login — bcrypt used to verify against stored hash
// ══════════════════════════════════════════════════════════════════════════════
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ error: 'Email and password required.' });

    // Fetch user record from Firestore to get bcrypt hash
    const snapshot = await db.collection('users').where('email', '==', email).limit(1).get();
    if (snapshot.empty) return res.status(401).json({ error: 'Invalid credentials.' });

    const userData = snapshot.docs[0].data();

    // Check email verified
    if (!userData.email_verified) {
      return res.status(403).json({ error: 'Email not verified. Please check your inbox.', uid: userData.user_id });
    }

    // Verify password against bcrypt hash
    const match = await bcrypt.compare(password, userData.password_hash);
    if (!match) return res.status(401).json({ error: 'Invalid credentials.' });

    // Issue custom token (client uses this to sign into Firebase)
    const customToken = await admin.auth().createCustomToken(userData.user_id);

    return res.status(200).json({ message: 'Login successful.', customToken, uid: userData.user_id });

  } catch (err) {
    console.error('Login error:', err);
    return res.status(500).json({ error: 'Login failed. Please try again.' });
  }
});

// ══════════════════════════════════════════════════════════════════════════════
// POST /api/auth/forgot-password
// Body: { email }
// 1. Check user exists in Firebase Auth
// 2. Generate OTP → store in Firestore
// 3. Send OTP via EmailJS (same service used by the Flutter app)
// ══════════════════════════════════════════════════════════════════════════════
router.post('/forgot-password', async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: 'Email is required.' });

    let userRecord;
    try {
      userRecord = await admin.auth().getUserByEmail(email);
    } catch (_) {
      // Don't reveal whether email exists — always return success
      return res.status(200).json({ message: 'If an account exists, a reset code was sent.' });
    }

    const otp = generateOtp();
    const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);

    await db.collection('password_reset_otps').doc(email).set({
      otp,
      uid: userRecord.uid,
      expires_at: admin.firestore.Timestamp.fromDate(expiresAt),
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send OTP via EmailJS (same credentials used by the Flutter app)
    await axios.post('https://api.emailjs.com/api/v1.0/email/send', {
      service_id:  'service_ezvt2r2',
      template_id: 'template_so1q2yf',
      user_id:     'C48yDMHg-ri1SjfYx',
      template_params: { to_email: email, otp_code: otp },
    }, { headers: { 'Content-Type': 'application/json', 'origin': 'http://localhost' } });

    return res.status(200).json({ message: 'Reset code sent.' });

  } catch (err) {
    console.error('Forgot password error:', err);
    return res.status(500).json({ error: 'Failed to send reset code. Please try again.' });
  }
});

// ══════════════════════════════════════════════════════════════════════════════
// POST /api/auth/verify-reset-otp
// Body: { email, otp }
// Validates the OTP is correct without changing the password yet.
// The client uses this to advance to the "set new password" step.
// ══════════════════════════════════════════════════════════════════════════════
router.post('/verify-reset-otp', async (req, res) => {
  try {
    const { email, otp } = req.body;
    if (!email || !otp) return res.status(400).json({ error: 'Email and code are required.' });

    const otpDoc = await db.collection('password_reset_otps').doc(email).get();
    if (!otpDoc.exists) {
      return res.status(404).json({ error: 'No reset request found. Please request a new code.' });
    }

    const data = otpDoc.data();

    if (data.expires_at.toDate() < new Date()) {
      await db.collection('password_reset_otps').doc(email).delete();
      return res.status(410).json({ error: 'Code has expired. Please request a new one.' });
    }

    if (data.otp !== otp) {
      return res.status(401).json({ error: 'Incorrect code. Please try again.' });
    }

    return res.status(200).json({ message: 'Code verified.' });

  } catch (err) {
    console.error('Verify reset OTP error:', err);
    return res.status(500).json({ error: 'Verification failed. Please try again.' });
  }
});

// ══════════════════════════════════════════════════════════════════════════════
// POST /api/auth/reset-password
// Body: { email, otp, newPassword }
// 1. Verify OTP from Firestore
// 2. Update password via Firebase Admin SDK (no email link needed)
// 3. Clean up OTP record
// ══════════════════════════════════════════════════════════════════════════════
router.post('/reset-password', async (req, res) => {
  try {
    const { email, otp, newPassword } = req.body;

    if (!email || !otp || !newPassword) {
      return res.status(400).json({ error: 'Email, code, and new password are required.' });
    }
    if (newPassword.length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters.' });
    }

    const otpDoc = await db.collection('password_reset_otps').doc(email).get();
    if (!otpDoc.exists) {
      return res.status(404).json({ error: 'No reset request found. Please request a new code.' });
    }

    const data = otpDoc.data();

    if (data.expires_at.toDate() < new Date()) {
      await db.collection('password_reset_otps').doc(email).delete();
      return res.status(410).json({ error: 'Code has expired. Please request a new one.' });
    }

    if (data.otp !== otp) {
      return res.status(401).json({ error: 'Incorrect code. Please try again.' });
    }

    // Update password directly via Firebase Admin — no email link required
    await admin.auth().updateUser(data.uid, { password: newPassword });

    await db.collection('password_reset_otps').doc(email).delete();

    return res.status(200).json({ message: 'Password reset successfully.' });

  } catch (err) {
    console.error('Reset password error:', err);
    return res.status(500).json({ error: 'Failed to reset password. Please try again.' });
  }
});

module.exports = router;
