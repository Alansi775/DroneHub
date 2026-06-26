const { CartItem, Product, ProductImage } = require('../models');
const { createError } = require('../middleware/errorHandler');

const cartItemWithProduct = {
  include: [{
    model: Product,
    as: 'product',
    include: [{ model: ProductImage, as: 'images', where: { is_primary: true }, required: false, limit: 1 }],
  }],
};

exports.getCart = async (req, res, next) => {
  try {
    const items = await CartItem.findAll({
      where: { user_id: req.user.id },
      ...cartItemWithProduct,
    });

    const subtotal = items.reduce((sum, item) => {
      return sum + parseFloat(item.product.price) * item.quantity;
    }, 0);

    res.json({ success: true, data: { items, subtotal: subtotal.toFixed(2) } });
  } catch (error) {
    next(error);
  }
};

exports.addToCart = async (req, res, next) => {
  try {
    const { productId, quantity = 1 } = req.body;

    const product = await Product.findOne({ where: { id: productId, is_active: true } });
    if (!product) return next(createError('Product not found', 404));
    if (product.stock < quantity) return next(createError('Insufficient stock', 400));

    const [item, created] = await CartItem.findOrCreate({
      where: { user_id: req.user.id, product_id: productId },
      defaults: { quantity },
    });

    if (!created) {
      const newQty = item.quantity + quantity;
      if (product.stock < newQty) return next(createError('Insufficient stock', 400));
      await item.update({ quantity: newQty });
    }

    const updatedItem = await CartItem.findByPk(item.id, cartItemWithProduct);
    res.status(created ? 201 : 200).json({ success: true, data: updatedItem });
  } catch (error) {
    next(error);
  }
};

exports.updateCartItem = async (req, res, next) => {
  try {
    const { quantity } = req.body;
    const item = await CartItem.findOne({ where: { id: req.params.id, user_id: req.user.id } });
    if (!item) return next(createError('Cart item not found', 404));

    const product = await Product.findByPk(item.product_id);
    if (product.stock < quantity) return next(createError('Insufficient stock', 400));

    await item.update({ quantity });
    const updated = await CartItem.findByPk(item.id, cartItemWithProduct);
    res.json({ success: true, data: updated });
  } catch (error) {
    next(error);
  }
};

exports.removeFromCart = async (req, res, next) => {
  try {
    const item = await CartItem.findOne({ where: { id: req.params.id, user_id: req.user.id } });
    if (!item) return next(createError('Cart item not found', 404));
    await item.destroy();
    res.json({ success: true, message: 'Item removed from cart' });
  } catch (error) {
    next(error);
  }
};

exports.clearCart = async (req, res, next) => {
  try {
    await CartItem.destroy({ where: { user_id: req.user.id } });
    res.json({ success: true, message: 'Cart cleared' });
  } catch (error) {
    next(error);
  }
};
