const jwt = require('jsonwebtoken');
const { OAuth2Client } = require('google-auth-library');
const { User } = require('../models');
const { createError } = require('../middleware/errorHandler');

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

    const existing = await User.findOne({ where: { email } });
    if (existing) return next(createError('Email already registered', 409));

    const user = await User.create({ name, email, password });
    authResponse(user, res, 201);
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

    authResponse(user, res);
  } catch (error) {
    next(error);
  }
};

exports.googleLogin = async (req, res, next) => {
  try {
    const { idToken } = req.body;
    if (!idToken) return next(createError('Google token required', 400));

    const ticket = await client.verifyIdToken({
      idToken,
      audience: process.env.GOOGLE_CLIENT_ID,
    });
    const payload = ticket.getPayload();
    const { sub: googleId, email, name, picture } = payload;

    let user = await User.findOne({ where: { google_id: googleId } });

    if (!user) {
      user = await User.findOne({ where: { email } });
      if (user) {
        await user.update({ google_id: googleId, avatar: picture });
      } else {
        user = await User.create({ name, email, google_id: googleId, avatar: picture });
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
