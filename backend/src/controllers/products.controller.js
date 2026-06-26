const { Op } = require('sequelize');
const { Product, ProductImage } = require('../models');
const { createError } = require('../middleware/errorHandler');

const productWithImages = {
  include: [{ model: ProductImage, as: 'images', order: [['sort_order', 'ASC']] }],
};

exports.getProducts = async (req, res, next) => {
  try {
    const {
      page = 1, limit = 20, category, search,
      minPrice, maxPrice, sort = 'created_at', order = 'DESC', featured,
    } = req.query;

    const where = { is_active: true };
    if (category) where.category = category;
    if (featured === 'true') where.is_featured = true;
    if (minPrice || maxPrice) {
      where.price = {};
      if (minPrice) where.price[Op.gte] = parseFloat(minPrice);
      if (maxPrice) where.price[Op.lte] = parseFloat(maxPrice);
    }
    if (search) {
      where[Op.or] = [
        { name: { [Op.like]: `%${search}%` } },
        { description: { [Op.like]: `%${search}%` } },
        { brand: { [Op.like]: `%${search}%` } },
      ];
    }

    const offset = (parseInt(page) - 1) * parseInt(limit);
    const { count, rows } = await Product.findAndCountAll({
      where,
      ...productWithImages,
      order: [[sort, order.toUpperCase()]],
      limit: parseInt(limit),
      offset,
      distinct: true,
    });

    res.json({
      success: true,
      data: rows,
      pagination: {
        total: count,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(count / parseInt(limit)),
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.getProduct = async (req, res, next) => {
  try {
    const product = await Product.findOne({
      where: { id: req.params.id, is_active: true },
      ...productWithImages,
    });

    if (!product) return next(createError('Product not found', 404));
    res.json({ success: true, data: product });
  } catch (error) {
    next(error);
  }
};

exports.getProductBySlug = async (req, res, next) => {
  try {
    const product = await Product.findOne({
      where: { slug: req.params.slug, is_active: true },
      ...productWithImages,
    });

    if (!product) return next(createError('Product not found', 404));
    res.json({ success: true, data: product });
  } catch (error) {
    next(error);
  }
};

exports.getCategories = async (req, res, next) => {
  try {
    const categories = await Product.findAll({
      attributes: ['category'],
      where: { is_active: true },
      group: ['category'],
      raw: true,
    });
    res.json({ success: true, data: categories.map((c) => c.category) });
  } catch (error) {
    next(error);
  }
};
