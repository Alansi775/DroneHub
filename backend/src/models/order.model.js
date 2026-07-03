const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Order = sequelize.define('Order', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  order_number: {
    type: DataTypes.STRING(20),
    allowNull: false,
    unique: true,
  },
  user_id: {
    type: DataTypes.UUID,
    allowNull: false,
  },
  status: {
    type: DataTypes.ENUM('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded'),
    defaultValue: 'pending',
  },
  payment_status: {
    type: DataTypes.ENUM('pending', 'paid', 'failed', 'refunded'),
    defaultValue: 'pending',
  },
  payment_method: {
    type: DataTypes.STRING(50),
    defaultValue: 'mock',
  },
  payment_id: {
    type: DataTypes.STRING(255),
    allowNull: true,
  },
  subtotal: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
  },
  shipping_cost: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0.00,
  },
  tax: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0.00,
  },
  total: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
  },
  shipping_name: { type: DataTypes.STRING(100), allowNull: false },
  shipping_email: { type: DataTypes.STRING(255), allowNull: false },
  shipping_phone: { type: DataTypes.STRING(20), allowNull: true },
  shipping_address_line1: { type: DataTypes.STRING(255), allowNull: false },
  shipping_address_line2: { type: DataTypes.STRING(255), allowNull: true },
  shipping_city: { type: DataTypes.STRING(100), allowNull: false },
  shipping_state: { type: DataTypes.STRING(100), allowNull: true },
  shipping_country: { type: DataTypes.STRING(100), allowNull: false },
  shipping_postal_code: { type: DataTypes.STRING(20), allowNull: true },
  notes: {
    type: DataTypes.TEXT,
    allowNull: true,
  },
}, {
  tableName: 'orders',
  hooks: {
    beforeValidate: (order) => {
      if (!order.order_number) {
        const ts = Date.now().toString().slice(-8);
        const rand = Math.random().toString(36).substring(2, 6).toUpperCase();
        order.order_number = `DH-${ts}-${rand}`;
      }
    },
  },
});

module.exports = Order;
