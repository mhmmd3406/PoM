'use strict';

/**
 * Stripe Subscription lifecycle handler.
 *
 * Events handled:
 *   invoice.paid                     → activate / renew subscription tier
 *   customer.subscription.deleted    → downgrade to free
 *   customer.subscription.updated    → tier change (plan upgrade/downgrade)
 *
 * Flow:
 *   Stripe → stripeSubscriptionWebhook (Cloud Function HTTP) →
 *     update users/{uid} in Firestore →
 *       onUserSubscriptionChanged (Firestore trigger) →
 *         setCustomUserClaims (Firebase Auth) →
 *           next token refresh picks up new tier
 */

const admin = require('firebase-admin');
const { defineSecret } = require('firebase-functions/params');

const stripeSecretKey     = defineSecret('STRIPE_SECRET_KEY');
const stripeSubWebhookSecret = defineSecret('STRIPE_SUB_WEBHOOK_SECRET');

// Map Stripe product metadata.pom_tier → internal tier string.
// Set these in Stripe Dashboard: Product → Metadata → pom_tier: 'pro'
const VALID_TIERS = new Set(['free', 'pro', 'standard', 'professional', 'enterprise']);

function tierFromMetadata(metadata = {}) {
  const t = (metadata.pom_tier || '').toLowerCase();
  return VALID_TIERS.has(t) ? t : 'pro'; // safest default for a paid invoice
}

/**
 * Look up the PoM user by Stripe customer ID.
 * Returns the Firestore DocumentSnapshot or null if not found.
 */
async function userDocByCustomerId(customerId) {
  const snap = await admin
    .firestore()
    .collection('users')
    .where('stripe_customer_id', '==', customerId)
    .limit(1)
    .get();

  return snap.empty ? null : snap.docs[0];
}

/**
 * Persist subscription state to Firestore.
 * The onUserSubscriptionChanged trigger will propagate the tier to Firebase Auth claims.
 */
async function applySubscription(userId, { tier, status, expiresAt, stripeCustomerId, stripeSubscriptionId }) {
  const update = {
    subscription_tier: tier,
    subscription_status: status,
    subscription_expires_at: expiresAt
      ? admin.firestore.Timestamp.fromDate(new Date(expiresAt * 1000))
      : null,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (stripeCustomerId) update.stripe_customer_id = stripeCustomerId;
  if (stripeSubscriptionId) update.stripe_subscription_id = stripeSubscriptionId;

  await admin.firestore().collection('users').doc(userId).update(update);
}

/**
 * HTTP webhook — receives Stripe subscription events.
 * Registered as exports.stripeSubscriptionWebhook in index.js.
 */
async function handleSubscriptionWebhook(req, res) {
  const stripe = require('stripe')(stripeSecretKey.value());
  const webhookSecret = stripeSubWebhookSecret.value();

  let event;
  try {
    event = stripe.webhooks.constructEvent(
      req.rawBody,
      req.headers['stripe-signature'],
      webhookSecret,
    );
  } catch (err) {
    console.error('Subscription webhook signature failed:', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  const obj = event.data.object;

  try {
    switch (event.type) {
      case 'invoice.paid': {
        // Subscription renewed or started
        const customerId     = obj.customer;
        const subscriptionId = obj.subscription;
        const userDoc = await userDocByCustomerId(customerId);
        if (!userDoc) { console.warn('No user for customer', customerId); break; }

        // Retrieve the subscription to get plan metadata
        const sub = await stripe.subscriptions.retrieve(subscriptionId);
        const productId = sub.items.data[0]?.price?.product;
        const product = productId ? await stripe.products.retrieve(productId) : null;
        const tier = tierFromMetadata(product?.metadata);

        await applySubscription(userDoc.id, {
          tier,
          status: 'active',
          expiresAt: sub.current_period_end,
          stripeCustomerId: customerId,
          stripeSubscriptionId: subscriptionId,
        });
        console.log(`Activated ${tier} for user ${userDoc.id}`);
        break;
      }

      case 'customer.subscription.deleted': {
        const customerId = obj.customer;
        const userDoc = await userDocByCustomerId(customerId);
        if (!userDoc) { console.warn('No user for customer', customerId); break; }

        await applySubscription(userDoc.id, {
          tier: 'free',
          status: 'cancelled',
          expiresAt: null,
          stripeSubscriptionId: null,
        });
        console.log(`Downgraded user ${userDoc.id} to free`);
        break;
      }

      case 'customer.subscription.updated': {
        const customerId     = obj.customer;
        const subscriptionId = obj.id;
        const userDoc = await userDocByCustomerId(customerId);
        if (!userDoc) break;

        const productId = obj.items?.data[0]?.price?.product;
        const product = productId ? await stripe.products.retrieve(productId) : null;
        const tier = tierFromMetadata(product?.metadata);
        const status = obj.status === 'active' ? 'active' : obj.status;

        await applySubscription(userDoc.id, {
          tier,
          status,
          expiresAt: obj.current_period_end,
          stripeCustomerId: customerId,
          stripeSubscriptionId: subscriptionId,
        });
        console.log(`Updated subscription: user ${userDoc.id} → ${tier} (${status})`);
        break;
      }

      default:
        // Unhandled — not an error
        break;
    }
  } catch (err) {
    console.error(`Failed processing ${event.type}:`, err.message);
    // Return 200 so Stripe doesn't retry; log for investigation
  }

  return res.json({ received: true });
}

/**
 * Firestore trigger: users/{userId} onUpdate
 * When subscription_tier changes, sync the Firebase Auth custom claim.
 * This ensures the next token refresh carries the new tier — no server restart needed.
 */
async function syncSubscriptionClaim(change, context) {
  const before = change.before.data();
  const after  = change.after.data();

  if (before.subscription_tier === after.subscription_tier) return; // no-op

  const newTier = after.subscription_tier || 'free';
  const userId = context.params.userId;

  try {
    // Preserve existing custom claims (e.g., b2b_bank_id)
    const user = await admin.auth().getUser(userId);
    const existingClaims = user.customClaims || {};

    await admin.auth().setCustomUserClaims(userId, {
      ...existingClaims,
      subscription_tier: newTier,
    });

    console.log(`Custom claim synced: user ${userId} → subscription_tier=${newTier}`);
  } catch (err) {
    console.error(`Failed to sync claim for user ${userId}:`, err.message);
  }
}

/**
 * Callable: create a Stripe Checkout Session for subscription.
 * Returns a checkout URL; the client opens it in the browser.
 */
async function createCheckoutSession(data, context) {
  if (!context.auth) {
    const { HttpsError } = require('firebase-functions').https;
    throw new HttpsError('unauthenticated', 'Login required');
  }

  const { priceId, successUrl, cancelUrl } = data;
  if (!priceId || !successUrl || !cancelUrl) {
    const { HttpsError } = require('firebase-functions').https;
    throw new HttpsError('invalid-argument', 'priceId, successUrl and cancelUrl are required');
  }

  const stripe = require('stripe')(stripeSecretKey.value());
  const db = admin.firestore();
  const userSnap = await db.collection('users').doc(context.auth.uid).get();
  const userData = userSnap.data() || {};

  // Re-use existing Stripe customer if available
  let customerId = userData.stripe_customer_id;
  if (!customerId) {
    const customer = await stripe.customers.create({
      metadata: { firebase_uid: context.auth.uid },
    });
    customerId = customer.id;
    await db.collection('users').doc(context.auth.uid).update({
      stripe_customer_id: customerId,
    });
  }

  const session = await stripe.checkout.sessions.create({
    customer: customerId,
    mode: 'subscription',
    line_items: [{ price: priceId, quantity: 1 }],
    success_url: successUrl,
    cancel_url: cancelUrl,
    metadata: { firebase_uid: context.auth.uid },
  });

  return { checkoutUrl: session.url, sessionId: session.id };
}

/**
 * Callable: open the Stripe Customer Portal (manage/cancel subscription).
 */
async function createPortalSession(data, context) {
  if (!context.auth) {
    const { HttpsError } = require('firebase-functions').https;
    throw new HttpsError('unauthenticated', 'Login required');
  }

  const stripe = require('stripe')(stripeSecretKey.value());
  const userSnap = await admin.firestore().collection('users').doc(context.auth.uid).get();
  const customerId = userSnap.data()?.stripe_customer_id;

  if (!customerId) {
    const { HttpsError } = require('firebase-functions').https;
    throw new HttpsError('not-found', 'No Stripe customer found for this user');
  }

  const session = await stripe.billingPortal.sessions.create({
    customer: customerId,
    return_url: data.returnUrl,
  });

  return { portalUrl: session.url };
}

module.exports = {
  handleSubscriptionWebhook,
  syncSubscriptionClaim,
  createCheckoutSession,
  createPortalSession,
  subscriptionSecrets: [stripeSecretKey, stripeSubWebhookSecret],
};
