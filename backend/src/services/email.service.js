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

const formatPrice = (val) => `$${parseFloat(val || 0).toFixed(2)}`;

const formatDate = (d) =>
  new Date(d).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit' });

// ─── Order Items Rows ────────────────────────────────────────────────────────

const orderItemsHtml = (items) =>
  items.map((item) => `
    <tr>
      <td style="padding:16px 12px;border-bottom:1px solid #F0F0F0;vertical-align:middle;">
        <table cellpadding="0" cellspacing="0" width="100%">
          <tr>
            ${item.product_image
              ? `<td style="width:64px;padding-right:14px;vertical-align:middle;">
                   <img src="${item.product_image}" width="64" height="64"
                     style="object-fit:cover;border-radius:10px;border:1px solid #EBEBEB;display:block;" />
                 </td>`
              : `<td style="width:64px;padding-right:14px;vertical-align:middle;">
                   <div style="width:64px;height:64px;background:#F5F5F5;border-radius:10px;border:1px solid #EBEBEB;"></div>
                 </td>`
            }
            <td style="vertical-align:middle;">
              <p style="margin:0;font-size:14px;font-weight:700;color:#0A0A0A;">${item.product_name}</p>
              <p style="margin:4px 0 0;font-size:12px;color:#9CA3AF;">Qty: ${item.quantity} &nbsp;×&nbsp; ${formatPrice(item.unit_price)}</p>
            </td>
            <td style="vertical-align:middle;text-align:right;white-space:nowrap;">
              <span style="font-size:15px;font-weight:700;color:#3B82F6;">${formatPrice(item.total_price)}</span>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  `).join('');

// ─── Customer Invoice ────────────────────────────────────────────────────────

const invoiceHtml = (order, { isAdmin = false } = {}) => `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Order ${order.order_number} — DroneHub</title>
</head>
<body style="margin:0;padding:0;background:#F2F4F7;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#F2F4F7;padding:40px 16px;">
  <tr><td align="center">
    <table width="620" cellpadding="0" cellspacing="0" style="max-width:620px;width:100%;">

      <!-- ── Header ── -->
      <tr>
        <td style="background:#0A0A0A;padding:28px 40px;border-radius:16px 16px 0 0;">
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr>
              <td>
                <span style="font-size:24px;font-weight:900;color:#FFFFFF;letter-spacing:-0.5px;">
                  Drone<span style="color:#3B82F6;">Hub</span>
                </span>
                <p style="margin:4px 0 0;font-size:11px;color:#555;letter-spacing:3px;">
                  ${isAdmin ? 'NEW ORDER RECEIVED' : 'ORDER CONFIRMED'}
                </p>
              </td>
              <td style="text-align:right;">
                <p style="margin:0;font-size:11px;color:#555;letter-spacing:1px;">ORDER</p>
                <p style="margin:4px 0 0;font-size:18px;font-weight:700;color:#3B82F6;">${order.order_number}</p>
              </td>
            </tr>
          </table>
        </td>
      </tr>

      <!-- ── Hero Banner ── -->
      <tr>
        <td style="background:#111827;padding:24px 40px;border-left:1px solid #1F2937;border-right:1px solid #1F2937;">
          ${isAdmin
            ? `<p style="margin:0;font-size:15px;color:#D1D5DB;">
                 📦 A new order has been placed by <strong style="color:#FFF;">${order.shipping_name}</strong>.
                 Review it in the admin panel.
               </p>`
            : `<p style="margin:0;font-size:15px;color:#D1D5DB;">
                 Hi <strong style="color:#FFF;">${order.shipping_name.split(' ')[0]}</strong> 👋&nbsp;
                 Your order is confirmed and being processed. We'll notify you when it ships!
               </p>`
          }
          <p style="margin:8px 0 0;font-size:12px;color:#6B7280;">
            📅 ${formatDate(order.created_at)}
          </p>
        </td>
      </tr>

      <!-- ── Items ── -->
      <tr>
        <td style="background:#FFFFFF;padding:32px 40px 0;border-left:1px solid #E5E7EB;border-right:1px solid #E5E7EB;">
          <p style="margin:0 0 20px;font-size:13px;font-weight:700;color:#6B7280;letter-spacing:2px;">ORDER ITEMS</p>
          <table width="100%" cellpadding="0" cellspacing="0" style="border:1px solid #F0F0F0;border-radius:12px;overflow:hidden;">
            <tbody>
              ${orderItemsHtml(order.items || [])}
            </tbody>
          </table>
        </td>
      </tr>

      <!-- ── Total ── -->
      <tr>
        <td style="background:#FFFFFF;padding:24px 40px 32px;border-left:1px solid #E5E7EB;border-right:1px solid #E5E7EB;">
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr>
              <td colspan="2" style="border-top:2px solid #0A0A0A;padding-top:16px;">
                <table width="100%" cellpadding="0" cellspacing="0">
                  <tr>
                    <td style="font-size:20px;font-weight:800;color:#0A0A0A;padding:4px 0;">Total Paid</td>
                    <td style="text-align:right;font-size:24px;font-weight:900;color:#3B82F6;">${formatPrice(order.total)}</td>
                  </tr>
                  <tr>
                    <td colspan="2" style="padding-top:6px;">
                      <span style="display:inline-block;background:#DCFCE7;color:#16A34A;font-size:11px;font-weight:700;padding:4px 12px;border-radius:20px;letter-spacing:0.5px;">
                        ✓ PAYMENT CONFIRMED
                      </span>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
          </table>
        </td>
      </tr>

      <!-- ── Delivery Address ── -->
      <tr>
        <td style="background:#F9FAFB;padding:24px 40px;border:1px solid #E5E7EB;border-top:none;">
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr>
              <td style="vertical-align:top;padding-right:24px;">
                <p style="margin:0 0 8px;font-size:11px;font-weight:700;color:#9CA3AF;letter-spacing:2px;">DELIVER TO</p>
                <p style="margin:0;font-size:14px;font-weight:700;color:#111827;">${order.shipping_name}</p>
                <p style="margin:4px 0 0;font-size:13px;color:#6B7280;line-height:1.7;">
                  ${order.shipping_address_line1}
                  ${order.shipping_address_line2 ? '<br>' + order.shipping_address_line2 : ''}
                  <br>${order.shipping_city}${order.shipping_state ? ', ' + order.shipping_state : ''} ${order.shipping_postal_code || ''}
                  <br>${order.shipping_country}
                </p>
              </td>
              <td style="vertical-align:top;border-left:1px solid #E5E7EB;padding-left:24px;">
                <p style="margin:0 0 8px;font-size:11px;font-weight:700;color:#9CA3AF;letter-spacing:2px;">CONTACT</p>
                <p style="margin:0;font-size:13px;color:#374151;">✉️ ${order.shipping_email}</p>
                ${order.shipping_phone ? `<p style="margin:6px 0 0;font-size:13px;color:#374151;">📱 ${order.shipping_phone}</p>` : ''}
              </td>
            </tr>
          </table>
        </td>
      </tr>

      <!-- ── Footer ── -->
      <tr>
        <td style="background:#0A0A0A;padding:24px 40px;border-radius:0 0 16px 16px;text-align:center;">
          <p style="color:#4B5563;margin:0;font-size:13px;">
            ${isAdmin
              ? 'This is an automated admin notification from DroneHub.'
              : 'Questions about your order? Reply to this email or contact our support team.'
            }
          </p>
          <p style="color:#1F2937;margin:8px 0 0;font-size:11px;">
            © ${new Date().getFullYear()} DroneHub. All rights reserved.
          </p>
        </td>
      </tr>

    </table>
  </td></tr>
</table>
</body>
</html>
`;

// ─── Verification Email ──────────────────────────────────────────────────────

const verificationTemplate = (name, verifyUrl) => `
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Verify your DroneHub email</title></head>
<body style="margin:0;padding:0;background:#F2F4F7;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#F2F4F7;padding:40px 16px;">
  <tr><td align="center">
    <table width="560" cellpadding="0" cellspacing="0" style="max-width:560px;width:100%;">
      <tr>
        <td style="background:#0A0A0A;padding:28px 40px;border-radius:16px 16px 0 0;text-align:center;">
          <span style="font-size:22px;font-weight:900;color:#FFFFFF;letter-spacing:-0.5px;">Drone<span style="color:#3B82F6;">Hub</span></span>
        </td>
      </tr>
      <tr>
        <td style="background:#FFFFFF;padding:44px 40px 36px;border-left:1px solid #E5E7EB;border-right:1px solid #E5E7EB;">
          <h1 style="font-size:26px;font-weight:800;color:#0A0A0A;margin:0 0 16px;">Confirm your email ✈️</h1>
          <p style="font-size:15px;color:#374151;line-height:1.75;margin:0 0 8px;">Hi <strong>${name.split(' ')[0]}</strong>,</p>
          <p style="font-size:15px;color:#374151;line-height:1.75;margin:0 0 28px;">
            Welcome to DroneHub! To start exploring our premium drone parts, please verify your email address by clicking the button below.
          </p>
          <table cellpadding="0" cellspacing="0" style="margin:0 auto 32px;">
            <tr>
              <td style="background:#3B82F6;border-radius:10px;">
                <a href="${verifyUrl}" style="display:inline-block;padding:15px 40px;color:#FFFFFF;font-weight:700;font-size:15px;text-decoration:none;letter-spacing:0.3px;">Verify Email Address &rarr;</a>
              </td>
            </tr>
          </table>
          <div style="background:#F8F9FA;border-radius:10px;padding:16px 20px;border-left:3px solid #3B82F6;">
            <p style="font-size:13px;color:#6B7280;line-height:1.6;margin:0;">
              &nbsp;⏱&nbsp; This link expires in <strong>24 hours</strong>.<br>
              &nbsp;🔒&nbsp; If you didn't create this account, you can safely ignore this email.
            </p>
          </div>
          <p style="font-size:12px;color:#9CA3AF;margin-top:24px;line-height:1.6;">
            Or copy this link:<br><span style="color:#3B82F6;word-break:break-all;">${verifyUrl}</span>
          </p>
        </td>
      </tr>
      <tr>
        <td style="background:#F8F9FA;padding:20px 40px;border-radius:0 0 16px 16px;border:1px solid #E5E7EB;border-top:none;text-align:center;">
          <p style="font-size:12px;color:#9CA3AF;margin:0;line-height:1.6;">
            &copy; ${new Date().getFullYear()} DroneHub. All rights reserved.
          </p>
        </td>
      </tr>
    </table>
  </td></tr>
</table>
</body></html>`;

// ─── Exports ─────────────────────────────────────────────────────────────────

exports.sendVerificationEmail = async (email, name, token) => {
  if (!process.env.EMAIL_USER) return;
  const verifyUrl = `${process.env.FRONTEND_URL}/verify-email?token=${token}`;
  try {
    await transporter.sendMail({
      from: process.env.EMAIL_FROM || 'DroneHub <noreply@dronehub.com>',
      to: email,
      subject: '✈️ Verify your DroneHub account',
      html: verificationTemplate(name, verifyUrl),
    });
  } catch (err) {
    console.error('Failed to send verification email:', err.message);
  }
};

exports.sendOrderConfirmation = async (user, order) => {
  if (!process.env.EMAIL_USER) return;
  try {
    await transporter.sendMail({
      from: process.env.EMAIL_FROM || 'DroneHub <orders@dronehub.com>',
      to: order.shipping_email,
      subject: `✅ Order Confirmed — ${order.order_number} | DroneHub`,
      html: invoiceHtml(order, { isAdmin: false }),
    });
  } catch (err) {
    console.error('Failed to send order confirmation email:', err.message);
  }
};

exports.sendAdminOrderAlert = async (order) => {
  if (!process.env.EMAIL_USER) return;
  try {
    await transporter.sendMail({
      from: process.env.EMAIL_FROM || 'DroneHub <orders@dronehub.com>',
      to: process.env.EMAIL_USER,
      subject: `🛒 New Order — ${order.order_number} | ${formatPrice(order.total)}`,
      html: invoiceHtml(order, { isAdmin: true }),
    });
  } catch (err) {
    console.error('Failed to send admin order alert:', err.message);
  }
};
