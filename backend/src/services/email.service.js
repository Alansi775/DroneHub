const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  host: process.env.EMAIL_HOST,
  port: parseInt(process.env.EMAIL_PORT) || 587,
  secure: false,
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

const formatPrice = (val) => `$${parseFloat(val).toFixed(2)}`;

const orderItemsHtml = (items) =>
  items.map((item) => `
    <tr>
      <td style="padding:12px;border-bottom:1px solid #f0f0f0;">
        <strong>${item.product_name}</strong>
      </td>
      <td style="padding:12px;border-bottom:1px solid #f0f0f0;text-align:center;">${item.quantity}</td>
      <td style="padding:12px;border-bottom:1px solid #f0f0f0;text-align:right;">${formatPrice(item.unit_price)}</td>
      <td style="padding:12px;border-bottom:1px solid #f0f0f0;text-align:right;">${formatPrice(item.total_price)}</td>
    </tr>
  `).join('');

const invoiceHtml = (user, order) => `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f5f5f5;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;">
  <div style="max-width:600px;margin:40px auto;background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">

    <!-- Header -->
    <div style="background:#0a0a0a;padding:32px 40px;text-align:center;">
      <h1 style="color:#ffffff;margin:0;font-size:28px;letter-spacing:4px;font-weight:300;">DRONE<span style="color:#3b82f6;">HUB</span></h1>
      <p style="color:#666;margin:8px 0 0;font-size:13px;letter-spacing:2px;">ORDER CONFIRMED</p>
    </div>

    <!-- Body -->
    <div style="padding:40px;">
      <p style="color:#333;font-size:16px;">Hi <strong>${order.shipping_name}</strong>,</p>
      <p style="color:#666;line-height:1.6;">Thank you for your order! We've received your purchase and are processing it now.</p>

      <div style="background:#f8f9fa;border-radius:8px;padding:20px;margin:24px 0;">
        <p style="margin:0;color:#333;"><strong>Order Number:</strong> <span style="color:#3b82f6;font-size:18px;">${order.order_number}</span></p>
        <p style="margin:8px 0 0;color:#666;font-size:14px;">Date: ${new Date(order.created_at).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })}</p>
      </div>

      <!-- Items -->
      <h3 style="color:#333;border-bottom:2px solid #3b82f6;padding-bottom:12px;">Order Summary</h3>
      <table width="100%" cellpadding="0" cellspacing="0">
        <thead>
          <tr style="background:#f8f9fa;">
            <th style="padding:12px;text-align:left;color:#666;font-size:13px;font-weight:600;">PRODUCT</th>
            <th style="padding:12px;text-align:center;color:#666;font-size:13px;font-weight:600;">QTY</th>
            <th style="padding:12px;text-align:right;color:#666;font-size:13px;font-weight:600;">PRICE</th>
            <th style="padding:12px;text-align:right;color:#666;font-size:13px;font-weight:600;">TOTAL</th>
          </tr>
        </thead>
        <tbody>${orderItemsHtml(order.items || [])}</tbody>
      </table>

      <!-- Totals -->
      <div style="margin-top:24px;border-top:1px solid #eee;padding-top:20px;">
        <table width="100%">
          <tr><td style="color:#666;padding:4px 0;">Subtotal</td><td style="text-align:right;color:#333;">${formatPrice(order.subtotal)}</td></tr>
          <tr><td style="color:#666;padding:4px 0;">Shipping</td><td style="text-align:right;color:#333;">${parseFloat(order.shipping_cost) === 0 ? 'Free' : formatPrice(order.shipping_cost)}</td></tr>
          <tr><td style="color:#666;padding:4px 0;">Tax (18%)</td><td style="text-align:right;color:#333;">${formatPrice(order.tax)}</td></tr>
          <tr style="border-top:2px solid #0a0a0a;"><td style="padding:12px 0 0;font-size:18px;font-weight:700;color:#0a0a0a;">Total</td><td style="text-align:right;padding-top:12px;font-size:18px;font-weight:700;color:#3b82f6;">${formatPrice(order.total)}</td></tr>
        </table>
      </div>

      <!-- Shipping Address -->
      <div style="margin-top:32px;padding:20px;border:1px solid #eee;border-radius:8px;">
        <h4 style="margin:0 0 12px;color:#333;">Shipping Address</h4>
        <p style="margin:0;color:#666;line-height:1.8;">
          ${order.shipping_name}<br>
          ${order.shipping_address_line1}${order.shipping_address_line2 ? '<br>' + order.shipping_address_line2 : ''}<br>
          ${order.shipping_city}${order.shipping_state ? ', ' + order.shipping_state : ''} ${order.shipping_postal_code || ''}<br>
          ${order.shipping_country}
        </p>
      </div>
    </div>

    <!-- Footer -->
    <div style="background:#0a0a0a;padding:24px 40px;text-align:center;">
      <p style="color:#444;margin:0;font-size:13px;">Questions? Reply to this email or contact support.</p>
      <p style="color:#222;margin:8px 0 0;font-size:12px;">© ${new Date().getFullYear()} DroneHub. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
`;

exports.sendOrderConfirmation = async (user, order) => {
  if (!process.env.EMAIL_USER) return;
  try {
    await transporter.sendMail({
      from: process.env.EMAIL_FROM,
      to: order.shipping_email,
      subject: `Order Confirmed — ${order.order_number} | DroneHub`,
      html: invoiceHtml(user, order),
    });
  } catch (err) {
    console.error('Failed to send order confirmation email:', err.message);
  }
};

exports.sendAdminOrderAlert = async (order) => {
  if (!process.env.EMAIL_USER) return;
  try {
    await transporter.sendMail({
      from: process.env.EMAIL_FROM,
      to: process.env.EMAIL_USER,
      subject: `[NEW ORDER] ${order.order_number} — ${formatPrice(order.total)}`,
      html: `<h2>New Order Received</h2><pre>${JSON.stringify({ orderNumber: order.order_number, total: order.total, items: order.items?.length, customer: order.shipping_name }, null, 2)}</pre>`,
    });
  } catch (err) {
    console.error('Failed to send admin alert:', err.message);
  }
};
