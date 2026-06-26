const { v4: uuidv4 } = require('uuid');

/**
 * Mock payment service — replace with iyzico integration later.
 * iyzico docs: https://dev.iyzipay.com/
 */
exports.processPayment = async ({ amount, method }) => {
  await new Promise((r) => setTimeout(r, 300));

  return {
    success: true,
    transactionId: `MOCK-${uuidv4()}`,
    amount,
    method,
    processedAt: new Date().toISOString(),
  };
};

/**
 * iyzico integration placeholder (implement when ready):
 *
 * const Iyzipay = require('iyzipay');
 * const iyzipay = new Iyzipay({
 *   apiKey: process.env.IYZICO_API_KEY,
 *   secretKey: process.env.IYZICO_SECRET_KEY,
 *   uri: 'https://sandbox-api.iyzipay.com',
 * });
 */
