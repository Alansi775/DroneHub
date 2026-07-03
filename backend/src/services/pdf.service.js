const PDFDocument = require('pdfkit');

const fmtPrice = (v) => `$${parseFloat(v || 0).toFixed(2)}`;
const fmtDate = (d) =>
  new Date(d).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });

function generateInvoicePdf(order) {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ margin: 50, size: 'A4' });
    const chunks = [];
    doc.on('data', (chunk) => chunks.push(chunk));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    const W = doc.page.width;
    const L = 50;
    const R = W - 50;
    const CW = R - L;

    // ─── Dark Header ──────────────────────────────────────────────────────────
    doc.rect(0, 0, W, 90).fill('#0A0A0A');

    doc.font('Helvetica-Bold').fontSize(26).fillColor('#FFFFFF').text('Drone', L, 26, { continued: true });
    doc.fillColor('#3B82F6').text('Hub');

    doc.font('Helvetica').fontSize(8).fillColor('#555555').text('PREMIUM DRONE PARTS', L, 58);

    doc.font('Helvetica').fontSize(8).fillColor('#555555').text('INVOICE', L, 28, { align: 'right', width: CW });
    doc.font('Helvetica-Bold').fontSize(14).fillColor('#3B82F6').text(order.order_number, L, 42, { align: 'right', width: CW });

    // ─── Order Meta ───────────────────────────────────────────────────────────
    let y = 108;
    const orderDate = order.createdAt || order.created_at;

    doc.font('Helvetica').fontSize(8).fillColor('#9CA3AF').text('ORDER DATE', L, y);
    doc.font('Helvetica-Bold').fontSize(10).fillColor('#0A0A0A').text(fmtDate(orderDate), L, y + 12);

    doc.font('Helvetica').fontSize(8).fillColor('#9CA3AF').text('STATUS', L + 160, y);
    doc.font('Helvetica-Bold').fontSize(10).fillColor('#0A0A0A').text((order.status || 'pending').toUpperCase(), L + 160, y + 12);

    doc.font('Helvetica').fontSize(8).fillColor('#9CA3AF').text('PAYMENT', L + 320, y);
    doc.font('Helvetica-Bold').fontSize(10).fillColor('#16A34A').text('CONFIRMED ✓', L + 320, y + 12);

    y += 42;
    doc.moveTo(L, y).lineTo(R, y).strokeColor('#E5E7EB').lineWidth(1).stroke();

    // ─── Addresses ────────────────────────────────────────────────────────────
    y += 16;
    const colW = CW / 2 - 16;

    doc.font('Helvetica-Bold').fontSize(8).fillColor('#9CA3AF').text('BILL TO', L, y);
    doc.font('Helvetica-Bold').fontSize(10).fillColor('#111827').text(order.shipping_name, L, y + 13);
    doc.font('Helvetica').fontSize(9).fillColor('#6B7280').text(order.shipping_email, L, y + 27);
    if (order.shipping_phone) doc.text(order.shipping_phone, L, y + 41);

    const shipX = L + colW + 32;
    doc.font('Helvetica-Bold').fontSize(8).fillColor('#9CA3AF').text('SHIP TO', shipX, y);
    doc.font('Helvetica-Bold').fontSize(10).fillColor('#111827').text(order.shipping_name, shipX, y + 13);
    doc.font('Helvetica').fontSize(9).fillColor('#6B7280');
    doc.text(order.shipping_address_line1, shipX, y + 27);
    let aY = y + 41;
    if (order.shipping_address_line2) { doc.text(order.shipping_address_line2, shipX, aY); aY += 14; }
    const city = [order.shipping_city, order.shipping_state, order.shipping_postal_code].filter(Boolean).join(', ');
    doc.text(city, shipX, aY);
    doc.text(order.shipping_country, shipX, aY + 14);

    // ─── Items Table ──────────────────────────────────────────────────────────
    y += 95;
    doc.rect(L, y, CW, 26).fill('#0A0A0A');
    doc.font('Helvetica-Bold').fontSize(8).fillColor('#FFFFFF');
    doc.text('PRODUCT', L + 8, y + 9);
    doc.text('QTY', R - 165, y + 9, { width: 35, align: 'center' });
    doc.text('UNIT PRICE', R - 120, y + 9, { width: 60, align: 'right' });
    doc.text('TOTAL', R - 52, y + 9, { width: 52, align: 'right' });

    y += 26;
    const items = order.items || order.OrderItems || [];
    items.forEach((item, i) => {
      const rH = 30;
      doc.rect(L, y, CW, rH).fill(i % 2 === 0 ? '#FFFFFF' : '#F9FAFB');
      doc.font('Helvetica-Bold').fontSize(9).fillColor('#111827').text(item.product_name, L + 8, y + 9, { width: CW - 200, ellipsis: true });
      doc.font('Helvetica').fontSize(9).fillColor('#6B7280').text(String(item.quantity), R - 165, y + 9, { width: 35, align: 'center' });
      doc.text(fmtPrice(item.unit_price), R - 120, y + 9, { width: 60, align: 'right' });
      doc.font('Helvetica-Bold').fontSize(9).fillColor('#3B82F6').text(fmtPrice(item.total_price), R - 52, y + 9, { width: 52, align: 'right' });
      y += rH;
    });

    doc.rect(L, y, CW, 1).fill('#E5E7EB');
    y += 20;

    // ─── Totals ───────────────────────────────────────────────────────────────
    const tX = R - 200;
    const tW = 200;

    doc.font('Helvetica').fontSize(10).fillColor('#6B7280').text('Subtotal:', tX, y, { width: tW - 70 });
    doc.font('Helvetica-Bold').fontSize(10).fillColor('#111827').text(fmtPrice(order.subtotal), tX, y, { width: tW, align: 'right' });
    y += 18;

    doc.font('Helvetica').fontSize(10).fillColor('#6B7280').text('Shipping:', tX, y, { width: tW - 70 });
    doc.font('Helvetica-Bold').fontSize(10).fillColor('#16A34A').text('Free', tX, y, { width: tW, align: 'right' });
    y += 16;

    doc.moveTo(tX, y).lineTo(R, y).strokeColor('#0A0A0A').lineWidth(1).stroke();
    y += 10;

    doc.font('Helvetica-Bold').fontSize(13).fillColor('#0A0A0A').text('TOTAL', tX, y, { width: tW - 80 });
    doc.fillColor('#3B82F6').text(fmtPrice(order.total), tX, y, { width: tW, align: 'right' });

    // ─── Footer ───────────────────────────────────────────────────────────────
    const fY = doc.page.height - 55;
    doc.rect(0, fY, W, 55).fill('#0A0A0A');
    doc.font('Helvetica').fontSize(9).fillColor('#6B7280')
      .text('Thank you for shopping with DroneHub! Questions? Reply to this email.', L, fY + 13, { align: 'center', width: CW });
    doc.fontSize(8).fillColor('#374151')
      .text(`© ${new Date().getFullYear()} DroneHub. All rights reserved.`, L, fY + 30, { align: 'center', width: CW });

    doc.end();
  });
}

module.exports = { generateInvoicePdf };