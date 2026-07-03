const path = require('path');
const fs = require('fs');
const { Op } = require('sequelize');
const { Product, ProductImage, Order, OrderItem, User, Category, sequelize } = require('../models');
const { createError } = require('../middleware/errorHandler');
const BASE_URL = process.env.BASE_URL || 'http://10.155.83.72:5001';

// ─── Products ───────────────────────────────────────────────────────────────

exports.createProduct = async (req, res, next) => {
  const transaction = await sequelize.transaction();
  try {
    const {
      name, description, shortDescription, price, comparePrice,
      stock, category, brand, weight, specifications, isFeatured, currency,
    } = req.body;

    const slug = (name || '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '') + '-' + Date.now();
    const toNum = (v) => { if (v === '' || v == null) return null; const n = Number(v); return Number.isNaN(n) ? null : n; };

    const product = await Product.create({
      name, description, slug,
      short_description: shortDescription,
      price: toNum(price),
      compare_price: toNum(comparePrice),
      stock: toNum(stock) ?? 0,
      category, brand, weight: toNum(weight),
      currency: currency || 'USD',
      specifications: specifications ? JSON.parse(specifications) : null,
      is_featured: isFeatured === 'true',
    }, { transaction });

    if (req.files && req.files.length > 0) {
      const imageData = req.files.map((file, index) => ({
        product_id: product.id,
        url: `/uploads/products/${file.filename}`,
        is_primary: index === 0,
        sort_order: index,
      }));
      await ProductImage.bulkCreate(imageData, { transaction });
    }

    await transaction.commit();

    const fullProduct = await Product.findByPk(product.id, {
      include: [{ model: ProductImage, as: 'images' }],
    });

    res.status(201).json({ success: true, data: fullProduct });
  } catch (error) {
    await transaction.rollback();
    next(error);
  }
};

exports.updateProduct = async (req, res, next) => {
  const transaction = await sequelize.transaction();
  try {
    const product = await Product.findByPk(req.params.id, { transaction });
    if (!product) return next(createError('Product not found', 404));

    const updateFields = {};
    const allowed = ['name', 'description', 'price', 'stock', 'category', 'brand', 'weight', 'is_featured', 'is_active', 'currency'];
    allowed.forEach((key) => {
      if (req.body[key] !== undefined) updateFields[key] = req.body[key];
    });
    if (req.body.shortDescription) updateFields.short_description = req.body.shortDescription;
    if (req.body.comparePrice) updateFields.compare_price = req.body.comparePrice;
    if (req.body.specifications) updateFields.specifications = JSON.parse(req.body.specifications);
    if (req.body.isFeatured !== undefined) updateFields.is_featured = req.body.isFeatured === 'true';
    if (req.body.isActive !== undefined) updateFields.is_active = req.body.isActive === 'true';

    await product.update(updateFields, { transaction });

    if (req.files && req.files.length > 0) {
      const imageData = req.files.map((file, index) => ({
        product_id: product.id,
        url: `/uploads/products/${file.filename}`,
        is_primary: false,
        sort_order: index + 100,
      }));
      await ProductImage.bulkCreate(imageData, { transaction });
    }

    await transaction.commit();
    const fullProduct = await Product.findByPk(product.id, {
      include: [{ model: ProductImage, as: 'images' }],
    });
    res.json({ success: true, data: fullProduct });
  } catch (error) {
    await transaction.rollback();
    next(error);
  }
};

exports.getProductById = async (req, res, next) => {
  try {
    const product = await Product.findByPk(req.params.id, {
      include: [{ model: ProductImage, as: 'images' }],
    });
    if (!product) return next(createError('Product not found', 404));
    res.json({ success: true, data: product });
  } catch (error) {
    next(error);
  }
};

exports.deleteProduct = async (req, res, next) => {
  const transaction = await sequelize.transaction();
  try {
    const product = await Product.findByPk(req.params.id, { transaction });
    if (!product) return next(createError('Product not found', 404));

    // Delete image files from disk
    const images = await ProductImage.findAll({ where: { product_id: req.params.id }, transaction });
    for (const img of images) {
      const filePath = path.join(__dirname, '../../', img.url);
      if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
    }

    await product.destroy({ transaction });
    await transaction.commit();
    res.json({ success: true, message: 'Product deleted' });
  } catch (error) {
    await transaction.rollback();
    next(error);
  }
};

exports.deleteProductImage = async (req, res, next) => {
  try {
    const image = await ProductImage.findByPk(req.params.imageId);
    if (!image) return next(createError('Image not found', 404));

    const filePath = path.join(__dirname, '../../', image.url);
    if (fs.existsSync(filePath)) fs.unlinkSync(filePath);

    await image.destroy();
    res.json({ success: true, message: 'Image deleted' });
  } catch (error) {
    next(error);
  }
};

exports.setPrimaryImage = async (req, res, next) => {
  try {
    const image = await ProductImage.findByPk(req.params.imageId);
    if (!image) return next(createError('Image not found', 404));

    await ProductImage.update({ is_primary: false }, { where: { product_id: image.product_id } });
    await image.update({ is_primary: true });

    res.json({ success: true, message: 'Primary image updated' });
  } catch (error) {
    next(error);
  }
};

// ─── Orders ─────────────────────────────────────────────────────────────────

exports.getAllOrders = async (req, res, next) => {
  try {
    const { page = 1, limit = 20, status, search } = req.query;
    const where = {};
    if (status) where.status = status;
    if (search) where[Op.or] = [{ order_number: { [Op.like]: `%${search}%` } }];

    const offset = (parseInt(page) - 1) * parseInt(limit);
    const { count, rows } = await Order.findAndCountAll({
      where,
      include: [
        { model: User, as: 'user', attributes: ['id', 'name', 'email'] },
        { model: OrderItem, as: 'items' },
      ],
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

exports.updateOrderStatus = async (req, res, next) => {
  try {
    const { status } = req.body;
    const order = await Order.findByPk(req.params.id);
    if (!order) return next(createError('Order not found', 404));
    await order.update({ status });
    res.json({ success: true, data: order });
  } catch (error) {
    next(error);
  }
};

// ─── Dashboard ──────────────────────────────────────────────────────────────

exports.getDashboardStats = async (req, res, next) => {
  try {
    const [totalOrders, totalRevenue, totalProducts, totalUsers, recentOrders] = await Promise.all([
      Order.count({ where: { payment_status: 'paid' } }),
      Order.sum('total', { where: { payment_status: 'paid' } }),
      Product.count({ where: { is_active: true } }),
      User.count({ where: { role: 'customer' } }),
      Order.findAll({
        limit: 5,
        order: [['created_at', 'DESC']],
        include: [{ model: User, as: 'user', attributes: ['name', 'email'] }],
      }),
    ]);

    res.json({
      success: true,
      data: {
        totalOrders,
        totalRevenue: parseFloat(totalRevenue || 0).toFixed(2),
        totalProducts,
        totalUsers,
        recentOrders,
      },
    });
  } catch (error) {
    next(error);
  }
};

// ─── Categories ─────────────────────────────────────────────────────────────

exports.getCategories = async (req, res, next) => {
  try {
    const categories = await Category.findAll({ order: [['created_at', 'ASC']] });
    const result = await Promise.all(categories.map(async (cat) => {
      const products = await Product.findAll({
        where: { category: cat.slug, is_active: true },
        include: [{ model: ProductImage, as: 'images' }],
        limit: 4,
        order: [['created_at', 'DESC']],
      });
      const previewImages = products.map(p => {
        const img = p.images?.find(i => i.is_primary) || p.images?.[0];
        return img ? `${BASE_URL}${img.url}` : null;
      }).filter(Boolean);
      return { ...cat.toJSON(), previewImages, productCount: products.length };
    }));
    res.json({ success: true, data: result });
  } catch (error) { next(error); }
};

exports.createCategory = async (req, res, next) => {
  try {
    const { name } = req.body;
    if (!name?.trim()) return next(createError('Name required', 400));
    const slug = name.trim().toLowerCase().replace(/\s+/g, '_').replace(/[^a-z0-9_]/g, '');
    const cat = await Category.create({ name: name.trim(), slug });
    res.status(201).json({ success: true, data: cat });
  } catch (error) { next(error); }
};

exports.deleteCategory = async (req, res, next) => {
  try {
    const cat = await Category.findByPk(req.params.id);
    if (!cat) return next(createError('Category not found', 404));
    await Product.update({ category: 'accessories' }, { where: { category: cat.slug } });
    await cat.destroy();
    res.json({ success: true });
  } catch (error) { next(error); }
};

exports.getPendingOrdersCount = async (req, res, next) => {
  try {
    const count = await Order.count({ where: { status: 'pending' } });
    res.json({ success: true, data: { count } });
  } catch (error) { next(error); }
};

exports.getAllProducts = async (req, res, next) => {
  try {
    const { page = 1, limit = 20 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    const { count, rows } = await Product.findAndCountAll({
      include: [{ model: ProductImage, as: 'images' }],
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
