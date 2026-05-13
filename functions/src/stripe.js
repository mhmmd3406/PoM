'use strict';

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { defineSecret } = require('firebase-functions/params');

// Secret Manager — value injected at runtime, never in source
const stripeSecretKey = defineSecret('STRIPE_SECRET_KEY');

/**
 * Creates a Stripe PaymentIntent for a PoM session purchase.
 *
 * Products:
 *   day_pass     → $2.99  (24-hour all-banks access)
 *   bank_unlock  → $1.49  (30-day single-bank access)
 *
 * Flow:
 *   1. Flutter calls createPaymentIntent (callable)
 *   2. Flutter confirms payment with Stripe SDK
 *   3. Flutter calls confirmPurchase with paymentIntentId
 *   4. Cloud Function verifies payment server-side → grants session
 */

const PRICES_CENTS = {
  day_pass: 299,
  bank_unlock: 149,
};

/**
 * Step 1 — Create a PaymentIntent and return clientSecret to Flutter.
 */
exports.createPaymentIntent = functions
  .runWith({ secrets: ['STRIPE_SECRET_KEY'] })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Login required');
    }

    const { sessionType, bankIds = [] } = data;

    if (!PRICES_CENTS[sessionType]) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid sessionType');
    }
    if (sessionType === 'bank_unlock' && !bankIds.length) {
      throw new functions.https.HttpsError('invalid-argument', 'bank_unlock requires bankIds');
    }

    const stripe = require('stripe')(stripeSecretKey.value());

    const paymentIntent = await stripe.paymentIntents.create({
      amount: PRICES_CENTS[sessionType],
      currency: 'usd',
      automatic_payment_methods: { enabled: true },
      metadata: {
        userId: context.auth.uid,
        sessionType,
        bankIds: JSON.stringify(bankIds),
      },
    });

    return { clientSecret: paymentIntent.client_secret };
  });

/**
 * Step 3 — Verify PaymentIntent succeeded server-side, then grant session.
 */
exports.confirmPurchase = functions
  .runWith({ secrets: ['STRIPE_SECRET_KEY'] })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Login required');
    }

    const { paymentIntentId } = data;
    if (!paymentIntentId) {
      throw new functions.https.HttpsError('invalid-argument', 'paymentIntentId required');
    }

    const stripe = require('stripe')(stripeSecretKey.value());
    const pi = await stripe.paymentIntents.retrieve(paymentIntentId);

    if (pi.status !== 'succeeded') {
      throw new functions.https.HttpsError('failed-precondition', `Payment not succeeded: ${pi.status}`);
    }
    if (pi.metadata.userId !== context.auth.uid) {
      throw new functions.https.HttpsError('permission-denied', 'PaymentIntent owner mismatch');
    }

    const { sessionType, bankIds: bankIdsJson } = pi.metadata;
    const bankIds = JSON.parse(bankIdsJson || '[]');

    // recordMicropayment is idempotent via payment_ref uniqueness
    const { recordMicropayment } = require('./credits');
    const sessionId = await recordMicropayment(
      context.auth.uid,
      sessionType,
      bankIds,
      paymentIntentId,
    );

    return { sessionId, sessionType, bankIds };
  });

/**
 * Stripe webhook — fallback for mobile clients that crash before confirmPurchase.
 * Verifies signature, then grants session for payment_intent.succeeded events.
 */
exports.stripeWebhook = functions
  .runWith({ secrets: ['STRIPE_SECRET_KEY', 'STRIPE_WEBHOOK_SECRET'] })
  .https.onRequest(async (req, res) => {
    const { defineSecret: ds } = require('firebase-functions/params');
    const webhookSecret = ds('STRIPE_WEBHOOK_SECRET').value();
    const stripe = require('stripe')(stripeSecretKey.value());

    let event;
    try {
      event = stripe.webhooks.constructEvent(
        req.rawBody,
        req.headers['stripe-signature'],
        webhookSecret,
      );
    } catch (err) {
      console.error('Webhook signature verification failed:', err.message);
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    if (event.type === 'payment_intent.succeeded') {
      const pi = event.data.object;
      const { userId, sessionType, bankIds: bankIdsJson } = pi.metadata;

      if (userId && sessionType) {
        const bankIds = JSON.parse(bankIdsJson || '[]');
        const { recordMicropayment } = require('./credits');
        await recordMicropayment(userId, sessionType, bankIds, pi.id).catch(
          (err) => console.error('recordMicropayment in webhook failed:', err.message),
        );
      }
    }

    res.json({ received: true });
  });
