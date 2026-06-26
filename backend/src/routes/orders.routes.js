const router = require('express').Router();
const ordersController = require('../controllers/orders.controller');
const { authenticate } = require('../middleware/auth.middleware');

router.use(authenticate);

router.post('/', ordersController.createOrder);
router.get('/', ordersController.getMyOrders);
router.get('/:id', ordersController.getOrder);

module.exports = router;
