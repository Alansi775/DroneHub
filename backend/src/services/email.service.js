const nodemailer = require('nodemailer');
const { generateInvoicePdf } = require('./pdf.service');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

const formatPrice = (val) => `$${parseFloat(val || 0).toFixed(2)}`;

const formatDate = (d) =>
  new Date(d).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit' });

const orderItemsHtml = (items) =>
  items.map((item) => `
    <tr>
      <td style="padding:16px 12px;border-bottom:1px solid #F0F0F0;vertical-align:middle;">
        <table cellpadding="0" cellspacing="0" width="100%"><tr>
          ${item.product_image
            ? `<td style="width:64px;padding-right:14px;vertical-align:middle;">
                 <img src="http://localhost:5001${item.product_image}" width="64" height="64"
                   style="object-fit:cover;border-radius:10px;border:1px solid #EBEBEB;display:block;" />
               </td>`
            : `<td style="width:64px;padding-right:14px;vertical-align:middle;">
                 <div style="width:64px;height:64px;background:#F5F5F5;border-radius:10px;border:1px solid #EBEBEB;"></div>
               </td>`
          }
          <td style="vertical-align:middle;">
            <p style="margin:0;font-size:14px;font-weight:700;color:#0A0A0A;">${item.product_name}</p>
            <p style="margin:4px 0 0;font-size:12px;color:#9CA3AF;">Qty: ${item.quantity} &times; ${formatPrice(item.unit_price)}</p>
          </td>
          <td style="vertical-align:middle;text-align:right;white-space:nowrap;">
            <span style="font-size:15px;font-weight:700;color:#3B82F6;">${formatPrice(item.total_price)}</span>
          </td>
        </tr></table>
      </td>
    </tr>
  `).join('');

const invoiceHtml = (order, { isAdmin = false } = {}) => {
  const orderDate = order.createdAt || order.created_at;
  return `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>Order ${order.order_number}</title></head>
<body style="margin:0;padding:0;background:#F2F4F7;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#F2F4F7;padding:40px 16px;">
<tr><td align="center"><table width="620" cellpadding="0" cellspacing="0" style="max-width:620px;width:100%;">
<tr><td style="background:#0A0A0A;padding:28px 40px;border-radius:16px 16px 0 0;">
  <table width="100%" cellpadding="0" cellspacing="0"><tr>
    <td><span style="font-size:24px;font-weight:900;color:#FFF;">Drone<span style="color:#3B82F6;">Hub</span></span>
    <p style="margin:4px 0 0;font-size:11px;color:#555;letter-spacing:3px;">${isAdmin ? 'NEW ORDER RECEIVED' : 'ORDER CONFIRMED'}</p></td>
    <td style="text-align:right;"><p style="margin:0;font-size:11px;color:#555;">ORDER</p>
    <p style="margin:4px 0 0;font-size:18px;font-weight:700;color:#3B82F6;">${order.order_number}</p></td>
  </tr></table>
</td></tr>
<tr><td style="background:#111827;padding:24px 40px;border-left:1px solid #1F2937;border-right:1px solid #1F2937;">
  ${isAdmin
    ? `<p style="margin:0;font-size:15px;color:#D1D5DB;">New order by <strong style="color:#FFF;">${order.shipping_name}</strong>.</p>`
    : `<p style="margin:0;font-size:15px;color:#D1D5DB;">Hi <strong style="color:#FFF;">${order.shipping_name.split(' ')[0]}</strong> Your order is confirmed! We'll notify you when it ships.</p>`
  }
  <p style="margin:8px 0 0;font-size:12px;color:#6B7280;">Placed on: ${formatDate(orderDate)}</p>
</td></tr>
<tr><td style="background:#FFF;padding:32px 40px 0;border-left:1px solid #E5E7EB;border-right:1px solid #E5E7EB;">
  <p style="margin:0 0 20px;font-size:13px;font-weight:700;color:#6B7280;letter-spacing:2px;">ORDER ITEMS</p>
  <table width="100%" cellpadding="0" cellspacing="0" style="border:1px solid #F0F0F0;border-radius:12px;overflow:hidden;">
    <tbody>${orderItemsHtml(order.items || [])}</tbody>
  </table>
</td></tr>
<tr><td style="background:#FFF;padding:24px 40px 32px;border-left:1px solid #E5E7EB;border-right:1px solid #E5E7EB;">
  <table width="100%" cellpadding="0" cellspacing="0"><tr><td style="border-top:2px solid #0A0A0A;padding-top:16px;">
    <table width="100%" cellpadding="0" cellspacing="0">
      <tr><td style="font-size:20px;font-weight:800;color:#0A0A0A;">Total Paid</td>
          <td style="text-align:right;font-size:24px;font-weight:900;color:#3B82F6;">${formatPrice(order.total)}</td></tr>
      <tr><td colspan="2" style="padding-top:8px;">
        <span style="background:#DCFCE7;color:#16A34A;font-size:11px;font-weight:700;padding:4px 12px;border-radius:20px;">PAYMENT CONFIRMED</span>
        &nbsp;<span style="background:#EFF6FF;color:#3B82F6;font-size:11px;font-weight:700;padding:4px 12px;border-radius:20px;">PDF Invoice Attached</span>
      </td></tr>
    </table>
  </td></tr></table>
</td></tr>
<tr><td style="background:#F9FAFB;padding:24px 40px;border:1px solid #E5E7EB;border-top:none;">
  <table width="100%" cellpadding="0" cellspacing="0"><tr>
    <td style="vertical-align:top;padding-right:24px;">
      <p style="margin:0 0 8px;font-size:11px;font-weight:700;color:#9CA3AF;letter-spacing:2px;">DELIVER TO</p>
      <p style="margin:0;font-size:14px;font-weight:700;color:#111827;">${order.shipping_name}</p>
      <p style="margin:4px 0 0;font-size:13px;color:#6B7280;line-height:1.7;">
        ${order.shipping_address_line1}${order.shipping_address_line2 ? '<br>' + order.shipping_address_line2 : ''}
        <br>${order.shipping_city}${order.shipping_state ? ', ' + order.shipping_state : ''} ${order.shipping_postal_code || ''}
        <br>${order.shipping_country}
      </p>
    </td>
    <td style="vertical-align:top;border-left:1px solid #E5E7EB;padding-left:24px;">
      <p style="margin:0 0 8px;font-size:11px;font-weight:700;color:#9CA3AF;letter-spacing:2px;">CONTACT</p>
      <p style="margin:0;font-size:13px;color:#374151;">${order.shipping_email}</p>
      ${order.shipping_phone ? `<p style="margin:6px 0 0;font-size:13px;color:#374151;">${order.shipping_phone}</p>` : ''}
    </td>
  </tr></table>
</td></tr>
<tr><td style="background:#0A0A0A;padding:24px 40px;border-radius:0 0 16px 16px;text-align:center;">
  <p style="color:#4B5563;margin:0;font-size:13px;">${isAdmin ? 'Admin notification from DroneHub.' : 'Questions? Reply to this email.'}</p>
  <p style="color:#1F2937;margin:8px 0 0;font-size:11px;">&copy; ${new Date().getFullYear()} DroneHub. All rights reserved.</p>
</td></tr>
</table></td></tr></table></body></html>`;
};

const verificationTemplate = (name, verifyUrl) => `<!DOCTYPE html><html><head><meta charset="UTF-8"></head>
<body style="margin:0;padding:0;background:#F2F4F7;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#F2F4F7;padding:40px 16px;">
<tr><td align="center"><table width="560" cellpadding="0" cellspacing="0" style="max-width:560px;width:100%;">
<tr><td style="background:#0A0A0A;padding:28px 40px;border-radius:16px 16px 0 0;text-align:center;">
  <span style="font-size:22px;font-weight:900;color:#FFF;">Drone<span style="color:#3B82F6;">Hub</span></span>
</td></tr>
<tr><td style="background:#FFF;padding:44px 40px 36px;border-left:1px solid #E5E7EB;border-right:1px solid #E5E7EB;">
  <h1 style="font-size:26px;font-weight:800;color:#0A0A0A;margin:0 0 16px;">Confirm your email</h1>
  <p style="font-size:15px;color:#374151;line-height:1.75;margin:0 0 28px;">Hi <strong>${name.split(' ')[0]}</strong>, welcome to DroneHub! Please verify your email to start shopping.</p>
  <table cellpadding="0" cellspacing="0" style="margin:0 auto 32px;">
    <tr><td style="background:#3B82F6;border-radius:10px;">
      <a href="${verifyUrl}" style="display:inline-block;padding:15px 40px;color:#FFF;font-weight:700;font-size:15px;text-decoration:none;">Verify Email Address &rarr;</a>
    </td></tr>
  </table>
  <p style="font-size:13px;color:#6B7280;">This link expires in 24 hours. If you didn't create an account, ignore this email.</p>
</td></tr>
<tr><td style="background:#F8F9FA;padding:20px 40px;border-radius:0 0 16px 16px;border:1px solid #E5E7EB;border-top:none;text-align:center;">
  <p style="font-size:12px;color:#9CA3AF;margin:0;">&copy; ${new Date().getFullYear()} DroneHub.</p>
</td></tr>
</table></td></tr></table></body></html>`;

exports.sendVerificationEmail = async (email, name, token) => {
  if (!process.env.EMAIL_USER) return;
  const verifyUrl = `${process.env.FRONTEND_URL}/verify-email?token=${token}`;
  try {
    await transporter.sendMail({
      from: process.env.EMAIL_FROM,
      to: email,
      subject: 'Verify your DroneHub account',
      html: verificationTemplate(name, verifyUrl),
    });
  } catch (err) {
    console.error('Failed to send verification email:', err.message);
  }
};

exports.sendOrderConfirmation = async (user, order) => {
  if (!process.env.EMAIL_USER) return;
  try {
    const pdfBuffer = await generateInvoicePdf(order).catch((e) => { console.error('PDF error:', e.message); return null; });
    const attachments = pdfBuffer
      ? [{ filename: `invoice-${order.order_number}.pdf`, content: pdfBuffer, contentType: 'application/pdf' }]
      : [];
    await transporter.sendMail({
      from: process.env.EMAIL_FROM,
      to: order.shipping_email,
      subject: `Order Confirmed - ${order.order_number} | DroneHub`,
      html: invoiceHtml(order, { isAdmin: false }),
      attachments,
    });
    console.log(`Confirmation sent to ${order.shipping_email}`);
  } catch (err) {
    console.error('Failed to send order confirmation email:', err.message);
  }
};

exports.sendAdminOrderAlert = async (order) => {
  if (!process.env.EMAIL_USER) return;
  try {
    const pdfBuffer = await generateInvoicePdf(order).catch((e) => { console.error('PDF error:', e.message); return null; });
    const attachments = pdfBuffer
      ? [{ filename: `invoice-${order.order_number}.pdf`, content: pdfBuffer, contentType: 'application/pdf' }]
      : [];
    await transporter.sendMail({
      from: process.env.EMAIL_FROM,
      to: process.env.EMAIL_USER,
      subject: `New Order - ${order.order_number} | ${formatPrice(order.total)}`,
      html: invoiceHtml(order, { isAdmin: true }),
      attachments,
    });
    console.log('Admin alert sent');
  } catch (err) {
    console.error('Failed to send admin order alert:', err.message);
  }
};
