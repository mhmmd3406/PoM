'use strict';

const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();

const LINKEDIN_CLIENT_SECRET = defineSecret('LINKEDIN_CLIENT_SECRET');
const LINKEDIN_CLIENT_ID = defineSecret('LINKEDIN_CLIENT_ID');
const HMAC_SECRET = defineSecret('HMAC_SECRET');
const STRIPE_SECRET_KEY = defineSecret('STRIPE_SECRET_KEY');
const STRIPE_WEBHOOK_SECRET = defineSecret('STRIPE_WEBHOOK_SECRET');

// ─── linkedinAuth ──────────────────────────────────────────────────────────────
// Exchanges an authorization code for a LinkedIn access token, derives a stable
// HMAC identity hash, mints a Firebase Custom Token, and upserts the user doc.
exports.linkedinAuth = onCall(
  { secrets: [LINKEDIN_CLIENT_SECRET, LINKEDIN_CLIENT_ID, HMAC_SECRET] },
  async (request) => {
    const { code, redirectUri } = request.data;
    if (!code || !redirectUri) {
      throw new HttpsError('invalid-argument', 'code and redirectUri required');
    }

    // Exchange code for access token
    const tokenRes = await fetch('https://www.linkedin.com/oauth/v2/accessToken', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        code,
        redirect_uri: redirectUri,
        client_id: LINKEDIN_CLIENT_ID.value(),
        client_secret: LINKEDIN_CLIENT_SECRET.value(),
      }),
    });

    if (!tokenRes.ok) {
      throw new HttpsError('unauthenticated', 'LinkedIn token exchange failed');
    }
    const { access_token: accessToken } = await tokenRes.json();

    // Fetch LinkedIn profile
    const profileRes = await fetch('https://api.linkedin.com/v2/me?projection=(id,localizedFirstName,localizedLastName)', {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!profileRes.ok) {
      throw new HttpsError('unauthenticated', 'LinkedIn profile fetch failed');
    }
    const profile = await profileRes.json();

    const linkedinId = profile.id;
    const displayName =
      `${profile.localizedFirstName ?? ''} ${profile.localizedLastName ?? ''}`.trim();

    // Derive stable UID: HMAC-SHA256(linkedinId, HMAC_SECRET)
    const linkedinHash = crypto
      .createHmac('sha256', HMAC_SECRET.value())
      .update(linkedinId)
      .digest('hex');

    // Mint Firebase Custom Token
    const firebaseToken = await admin.auth().createCustomToken(linkedinHash, {
      linkedinHash,
    });

    // Upsert user doc
    const userRef = db.collection('users').doc(linkedinHash);
    const snap = await userRef.get();
    if (!snap.exists) {
      await userRef.set({
        linkedinHash,
        displayName,
        role: 'free',
        isAdmin: false,
        kvkkAccepted: false,
        creditBalance: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else if (displayName) {
      await userRef.update({ displayName });
    }

    return { token: firebaseToken };
  }
);

// ─── createPaymentIntent ───────────────────────────────────────────────────────
exports.createPaymentIntent = onCall(
  { secrets: [STRIPE_SECRET_KEY] },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Login required');

    const { priceInTry, creditAmount, uid } = request.data;
    if (!priceInTry || !creditAmount || !uid) {
      throw new HttpsError('invalid-argument', 'priceInTry, creditAmount, uid required');
    }
    if (request.auth.uid !== uid) {
      throw new HttpsError('permission-denied', 'UID mismatch');
    }

    const stripe = require('stripe')(STRIPE_SECRET_KEY.value());
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(priceInTry * 100), // kuruş
      currency: 'try',
      metadata: { uid, creditAmount: String(creditAmount) },
    });

    return { clientSecret: paymentIntent.client_secret };
  }
);

// ─── createSubscription ────────────────────────────────────────────────────────
exports.createSubscription = onCall(
  { secrets: [STRIPE_SECRET_KEY] },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Login required');

    const { planId, uid } = request.data;
    if (!planId || !uid) throw new HttpsError('invalid-argument', 'planId and uid required');
    if (request.auth.uid !== uid) throw new HttpsError('permission-denied', 'UID mismatch');

    const stripe = require('stripe')(STRIPE_SECRET_KEY.value());

    // Retrieve or create Stripe customer linked to this uid
    const userSnap = await db.collection('users').doc(uid).get();
    let customerId = userSnap.data()?.stripeCustomerId;
    if (!customerId) {
      const customer = await stripe.customers.create({ metadata: { uid } });
      customerId = customer.id;
      await db.collection('users').doc(uid).update({ stripeCustomerId: customerId });
    }

    const subscription = await stripe.subscriptions.create({
      customer: customerId,
      items: [{ price: planId }],
      payment_behavior: 'default_incomplete',
      expand: ['latest_invoice.payment_intent'],
      metadata: { uid },
    });

    const clientSecret =
      subscription.latest_invoice?.payment_intent?.client_secret ?? null;

    return { clientSecret, subscriptionId: subscription.id };
  }
);

// ─── cancelSubscription ────────────────────────────────────────────────────────
exports.cancelSubscription = onCall(
  { secrets: [STRIPE_SECRET_KEY] },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Login required');

    const { subscriptionId, uid } = request.data;
    if (!subscriptionId || !uid) {
      throw new HttpsError('invalid-argument', 'subscriptionId and uid required');
    }
    if (request.auth.uid !== uid) throw new HttpsError('permission-denied', 'UID mismatch');

    const stripe = require('stripe')(STRIPE_SECRET_KEY.value());

    // Verify the subscription belongs to this user
    const sub = await stripe.subscriptions.retrieve(subscriptionId);
    if (sub.metadata?.uid !== uid) {
      throw new HttpsError('permission-denied', 'Subscription does not belong to user');
    }

    await stripe.subscriptions.update(subscriptionId, { cancel_at_period_end: true });
    return { cancelled: true };
  }
);

// ─── stripeWebhook ─────────────────────────────────────────────────────────────
exports.stripeWebhook = onRequest(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
  async (req, res) => {
    const stripe = require('stripe')(STRIPE_SECRET_KEY.value());
    const sig = req.headers['stripe-signature'];
    let event;

    try {
      event = stripe.webhooks.constructEvent(
        req.rawBody,
        sig,
        STRIPE_WEBHOOK_SECRET.value()
      );
    } catch (err) {
      res.status(400).send(`Webhook Error: ${err.message}`);
      return;
    }

    switch (event.type) {
      case 'payment_intent.succeeded': {
        const pi = event.data.object;
        const uid = pi.metadata?.uid;
        const creditAmount = parseInt(pi.metadata?.creditAmount ?? '0', 10);
        if (uid && creditAmount > 0) {
          await db.collection('wallets').doc(uid).set(
            { credits: admin.firestore.FieldValue.increment(creditAmount) },
            { merge: true }
          );
          await db.collection('transactions').add({
            uid,
            type: 'credit_purchase',
            credits: creditAmount,
            amountTry: pi.amount / 100,
            stripePaymentIntentId: pi.id,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        break;
      }

      case 'invoice.payment_succeeded': {
        const invoice = event.data.object;
        const uid = invoice.subscription_details?.metadata?.uid
          ?? invoice.metadata?.uid;
        if (uid) {
          await db.collection('subscriptions').doc(uid).set(
            {
              stripeSubscriptionId: invoice.subscription,
              status: 'active',
              currentPeriodEnd: new Date(invoice.lines.data[0]?.period?.end * 1000),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        }
        break;
      }

      default:
        break;
    }

    res.json({ received: true });
  }
);
