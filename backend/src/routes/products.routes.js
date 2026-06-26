const router = require('express').Router();
const productsController = require('../controllers/products.controller');

router.get('/', productsController.getProducts);
router.get('/categories', productsController.getCategories);
router.get('/slug/:slug', productsController.getProductBySlug);
router.get('/:id', productsController.getProduct);

module.exports = router;
