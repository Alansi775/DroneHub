const router = require('express').Router();
const usersController = require('../controllers/users.controller');
const { authenticate } = require('../middleware/auth.middleware');

router.use(authenticate);

router.put('/profile', usersController.updateProfile);
router.put('/password', usersController.changePassword);

module.exports = router;
