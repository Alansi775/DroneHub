const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { Op } = require('sequelize');
const { OAuth2Client } = require('google-auth-library');
const { User } = require('../models');
const { createError } = require('../middleware/errorHandler');
const { sendVerificationEmail } = require('../services/email.service');

const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

const signToken = (userId) =>
  jwt.sign({ id: userId }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN || '7d' });

const authResponse = (user, res, statusCode = 200) => {
  const token = signToken(user.id);
  res.status(statusCode).json({
    success: true,
    token,
    user: user.toJSON(),
  });
};

exports.register = async (req, res, next) => {
  try {
    const { name, email, password } = req.body;

    // Remove expired unverified accounts with same email so user can re-register
    await User.destroy({
      where: {
        email,
        email_verified: false,
        email_verification_expires: { [Op.lt]: new Date() },
      },
    });

    const existing = await User.findOne({ where: { email } });
    if (existing) {
      const msg = existing.email_verified
        ? 'Email already registered'
        : 'A verification email was already sent. Please check your inbox.';
      return next(createError(msg, 409));
    }

    const token = crypto.randomBytes(32).toString('hex');
    const expires = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 h

    await User.create({
      name,
      email,
      password,
      email_verified: false,
      email_verification_token: token,
      email_verification_expires: expires,
    });

    await sendVerificationEmail(email, name, token);

    res.status(201).json({
      success: true,
      message: 'Registration successful. Please check your email to verify your account.',
    });
  } catch (error) {
    next(error);
  }
};

exports.verifyEmail = async (req, res, next) => {
  try {
    const { token } = req.params;

    const user = await User.findOne({
      where: { email_verification_token: token, email_verified: false },
    });

    if (!user) return next(createError('Invalid or already used verification link.', 400));

    if (user.email_verification_expires < new Date()) {
      await user.destroy();
      return next(createError('Verification link expired. Please register again.', 400));
    }

    await user.update({
      email_verified: true,
      email_verification_token: null,
      email_verification_expires: null,
    });

    res.json({ success: true, message: 'Email verified! You can now sign in.' });
  } catch (error) {
    next(error);
  }
};

exports.login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ where: { email } });
    if (!user || !user.password) return next(createError('Invalid credentials', 401));

    const isValid = await user.comparePassword(password);
    if (!isValid) return next(createError('Invalid credentials', 401));

    if (!user.is_active) return next(createError('Account deactivated', 403));

    if (!user.email_verified) {
      return next(createError('Please verify your email before signing in. Check your inbox for the verification link.', 403));
    }

    authResponse(user, res);
  } catch (error) {
    next(error);
  }
};

exports.googleLogin = async (req, res, next) => {
  try {
    const { idToken, accessToken } = req.body;
    console.log('[Google Auth] idToken:', idToken ? 'present' : 'null', '| accessToken:', accessToken ? 'present' : 'null');

    if (!idToken && !accessToken) return next(createError('Google token required', 400));

    let googleId, email, name, picture;

    if (idToken) {
      // Mobile / idToken flow
      const ticket = await client.verifyIdToken({
        idToken,
        audience: process.env.GOOGLE_CLIENT_ID,
      });
      const payload = ticket.getPayload();
      ({ sub: googleId, email, name, picture } = payload);
    } else {
      // Flutter Web flow — verify accessToken via Google userinfo endpoint
      console.log('[Google Auth] Verifying accessToken via userinfo endpoint...');
      const resp = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
      const info = await resp.json();
      console.log('[Google Auth] userinfo response status:', resp.status, '| sub:', info.sub, '| email:', info.email);
      if (!resp.ok || !info.sub) return next(createError('Invalid Google access token', 401));
      googleId = info.sub;
      email = info.email;
      name = info.name || email.split('@')[0]; // fallback if name missing
      picture = info.picture;
    }

    let user = await User.findOne({ where: { google_id: googleId } });

    if (!user) {
      user = await User.findOne({ where: { email } });
      if (user) {
        await user.update({ google_id: googleId, avatar: picture });
      } else {
        user = await User.create({ name, email, google_id: googleId, avatar: picture, email_verified: true });
      }
    }

    if (!user.is_active) return next(createError('Account deactivated', 403));

    authResponse(user, res);
  } catch (error) {
    next(error);
  }
};

exports.getMe = async (req, res) => {
  res.json({ success: true, user: req.user.toJSON() });
};
