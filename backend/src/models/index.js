const sequelize = require('../config/database');
const User = require('./user.model');
const Product = require('./product.model');
const ProductImage = require('./productImage.model');
const CartItem = require('./cartItem.model');
const Order = require('./order.model');
const OrderItem = require('./orderItem.model');
const Category = require('./category.model');

// Product <-> Images
Product.hasMany(ProductImage, { foreignKey: 'product_id', as: 'images', onDelete: 'CASCADE' });
ProductImage.belongsTo(Product, { foreignKey: 'product_id' });

// User <-> Cart
User.hasMany(CartItem, { foreignKey: 'user_id', as: 'cartItems', onDelete: 'CASCADE' });
CartItem.belongsTo(User, { foreignKey: 'user_id' });
CartItem.belongsTo(Product, { foreignKey: 'product_id', as: 'product' });
Product.hasMany(CartItem, { foreignKey: 'product_id', onDelete: 'CASCADE' });

// User <-> Orders
User.hasMany(Order, { foreignKey: 'user_id', as: 'orders', onDelete: 'RESTRICT' });
Order.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

// Order <-> OrderItems
Order.hasMany(OrderItem, { foreignKey: 'order_id', as: 'items', onDelete: 'CASCADE' });
OrderItem.belongsTo(Order, { foreignKey: 'order_id' });
OrderItem.belongsTo(Product, { foreignKey: 'product_id', as: 'product' });

module.exports = {
  sequelize,
  User,
  Product,
  ProductImage,
  CartItem,
  Order,
  OrderItem,
  Category,
};
