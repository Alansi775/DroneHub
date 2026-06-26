const { sequelize, Order, OrderItem, CartItem, Product, ProductImage, User } = require('../models');
const { createError } = require('../middleware/errorHandler');
const emailService = require('../services/email.service');
const paymentService = require('../services/payment.service');

const orderWithItems = {
  include: [{
    model: OrderItem,
    as: 'items',
    include: [{ model: Product, as: 'product', required: false }],
  }],
};

exports.createOrder = async (req, res, next) => {
  const transaction = await sequelize.transaction();
  try {
    const { shippingAddress, paymentMethod = 'mock', notes } = req.body;

    const cartItems = await CartItem.findAll({
      where: { user_id: req.user.id },
      include: [{ model: Product, as: 'product' }],
      transaction,
    });

    if (!cartItems.length) return next(createError('Cart is empty', 400));

    for (const item of cartItems) {
      if (!item.product.is_active) {
        await transaction.rollback();
        return next(createError(`Product "${item.product.name}" is no longer available`, 400));
      }
      if (item.product.stock < item.quantity) {
        await transaction.rollback();
        return next(createError(`Insufficient stock for "${item.product.name}"`, 400));
      }
    }

    const subtotal = cartItems.reduce((sum, item) => sum + parseFloat(item.product.price) * item.quantity, 0);
    const shippingCost = subtotal >= 100 ? 0 : 9.99;
    const tax = subtotal * 0.18;
    const total = subtotal + shippingCost + tax;

    const paymentResult = await paymentService.processPayment({ amount: total, method: paymentMethod });

    const order = await Order.create({
      user_id: req.user.id,
      status: 'confirmed',
      payment_status: paymentResult.success ? 'paid' : 'failed',
      payment_method: paymentMethod,
      payment_id: paymentResult.transactionId,
      subtotal: subtotal.toFixed(2),
      shipping_cost: shippingCost.toFixed(2),
      tax: tax.toFixed(2),
      total: total.toFixed(2),
      notes,
      shipping_name: shippingAddress.name || req.user.name,
      shipping_email: shippingAddress.email || req.user.email,
      shipping_phone: shippingAddress.phone,
      shipping_address_line1: shippingAddress.addressLine1,
      shipping_address_line2: shippingAddress.addressLine2,
      shipping_city: shippingAddress.city,
      shipping_state: shippingAddress.state,
      shipping_country: shippingAddress.country,
      shipping_postal_code: shippingAddress.postalCode,
    }, { transaction });

    for (const item of cartItems) {
      const primaryImage = await ProductImage.findOne({ where: { product_id: item.product.id, is_primary: true } });
      await OrderItem.create({
        order_id: order.id,
        product_id: item.product.id,
        product_name: item.product.name,
        product_image: primaryImage?.url || null,
        quantity: item.quantity,
        unit_price: item.product.price,
        total_price: (parseFloat(item.product.price) * item.quantity).toFixed(2),
      }, { transaction });

      await item.product.decrement('stock', { by: item.quantity, transaction });
      await item.product.increment('sold_count', { by: item.quantity, transaction });
    }

    await CartItem.destroy({ where: { user_id: req.user.id }, transaction });

    await transaction.commit();

    const fullOrder = await Order.findByPk(order.id, orderWithItems);

    emailService.sendOrderConfirmation(req.user, fullOrder).catch(console.error);
    emailService.sendAdminOrderAlert(fullOrder).catch(console.error);

    res.status(201).json({ success: true, data: fullOrder });
  } catch (error) {
    await transaction.rollback();
    next(error);
  }
};

exports.getMyOrders = async (req, res, next) => {
  try {
    const { page = 1, limit = 10 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    const { count, rows } = await Order.findAndCountAll({
      where: { user_id: req.user.id },
      ...orderWithItems,
      order: [['created_at', 'DESC']],
      limit: parseInt(limit),
      offset,
      distinct: true,
    });

    res.json({
      success: true,
      data: rows,
      pagination: { total: count, page: parseInt(page), totalPages: Math.ceil(count / parseInt(limit)) },
    });
  } catch (error) {
    next(error);
  }
};

exports.getOrder = async (req, res, next) => {
  try {
    const order = await Order.findOne({
      where: { id: req.params.id, user_id: req.user.id },
      ...orderWithItems,
    });
    if (!order) return next(createError('Order not found', 404));
    res.json({ success: true, data: order });
  } catch (error) {
    next(error);
  }
};
