const { User } = require('../models');
const { createError } = require('../middleware/errorHandler');

exports.updateProfile = async (req, res, next) => {
  try {
    const {
      name, phone,
      addressLine1, addressLine2,
      city, state, country, postalCode,
    } = req.body;

    await req.user.update({
      name: name || req.user.name,
      phone,
      address_line1: addressLine1,
      address_line2: addressLine2,
      city,
      state,
      country,
      postal_code: postalCode,
    });

    res.json({ success: true, user: req.user.toJSON() });
  } catch (error) {
    next(error);
  }
};

exports.changePassword = async (req, res, next) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!req.user.password) return next(createError('Password change not available for Google accounts', 400));

    const isValid = await req.user.comparePassword(currentPassword);
    if (!isValid) return next(createError('Current password is incorrect', 401));

    await req.user.update({ password: newPassword });
    res.json({ success: true, message: 'Password updated successfully' });
  } catch (error) {
    next(error);
  }
};
