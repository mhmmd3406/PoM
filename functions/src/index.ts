/**
 * PoM (Peace of Mind) — Firebase Cloud Functions
 * B2B Employee Wellbeing Platform
 *
 * Uses firebase-functions v6 (gen2 API) with firebase-admin v12 and Stripe v17.
 */

import { onCall, onRequest, CallableRequest, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";
import * as admin from "firebase-admin";
import { applyThresholdFloors, sanitizeThresholdInput } from "./thresholds";
import axios from "axios";
import * as crypto from "crypto";
import Stripe from "stripe";

// ---------------------------------------------------------------------------
// Initialisation
// ---------------------------------------------------------------------------

admin.initializeApp();
const db = admin.firestore();

// Stripe is initialised lazily so cold-starts without Stripe secrets still work.
let _stripe: Stripe | null = null;
function getStripe(): Stripe {
  if (!_stripe) {
    const secret = process.env.STRIPE_SECRET_KEY ?? "";
    if (!secret) throw new HttpsError("failed-precondition", "Stripe secret key not configured");
    _stripe = new Stripe(secret, { apiVersion: "2025-02-24.acacia" });
  }
  return _stripe;
}

// ---------------------------------------------------------------------------
// In-memory cache (5-minute TTL)
// ---------------------------------------------------------------------------

const cache = new Map<string, { data: unknown; expiry: number }>();

async function cachedRead(key: string, fetcher: () => Promise<unknown>): Promise<unknown> {
  const now = Date.now();
  const cached = cache.get(key);
  if (cached && cached.expiry > now) return cached.data;
  const data = await fetcher();
  cache.set(key, { data, expiry: now + 5 * 60 * 1000 });
  return data;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** LinkedIn OAuth config */
function linkedinConfig() {
  return {
    clientId: process.env.LINKEDIN_CLIENT_ID ?? "",
    clientSecret: process.env.LINKEDIN_CLIENT_SECRET ?? "",
    redirectUri: process.env.LINKEDIN_REDIRECT_URI ?? "https://app.pom.app/auth/callback",
    hmacSecret: process.env.LINKEDIN_HMAC_SECRET ?? "pom-linkedin-hmac-secret",
  };
}

/** Compute HMAC-SHA256 of LinkedIn user ID */
function hashLinkedinId(linkedinId: string, secret: string): string {
  return crypto.createHmac("sha256", secret).update(linkedinId).digest("hex");
}

/**
 * Server-only salt for the pseudonymous `userIdHash`. Kept on the backend (never
 * shipped to the client) so that a leaked check-ins dump cannot be reversed to a
 * Firebase uid via a rainbow table. The hash is deterministic for a given uid so
 * the same value can be re-derived for queries / erasure.
 */
function userHashSalt(): string {
  return process.env.USER_HASH_SALT ?? "pom-user-id-hash-salt";
}

/**
 * Pseudonymous, deterministic per-user identifier. Stored on the user doc and on
 * every check-in so check-ins carry NO raw uid; firestore.rules bridge owner
 * access by comparing the caller's users/{uid}.userIdHash to the doc's value.
 */
function hashUserId(uid: string): string {
  return crypto.createHmac("sha256", userHashSalt()).update(uid).digest("hex");
}

/** Extract the largest available profile image URL from a LinkedIn lite profile. */
function extractLinkedinAvatar(profile: {
  profilePicture?: {
    "displayImage~"?: {
      elements?: Array<{ identifiers?: Array<{ identifier?: string }> }>;
    };
  };
}): string | null {
  const elements = profile.profilePicture?.["displayImage~"]?.elements;
  if (!elements || elements.length === 0) return null;
  // LinkedIn returns ascending sizes; take the last (largest).
  return elements[elements.length - 1]?.identifiers?.[0]?.identifier ?? null;
}

/** Simple OLS slope: returns slope of y = a + b*x over integer x = 0..n-1 */
function olsSlope(values: number[]): number {
  const n = values.length;
  if (n < 2) return 0;
  const xMean = (n - 1) / 2;
  const yMean = values.reduce((s, v) => s + v, 0) / n;
  let num = 0;
  let den = 0;
  for (let i = 0; i < n; i++) {
    num += (i - xMean) * (values[i] - yMean);
    den += (i - xMean) ** 2;
  }
  return den === 0 ? 0 : num / den;
}

/** Compute average of a numeric array, returns null if empty */
function avg(values: number[]): number | null {
  if (values.length === 0) return null;
  return values.reduce((s, v) => s + v, 0) / values.length;
}

// ---------------------------------------------------------------------------
// 1. linkedinAuth — HTTPS Callable
// ---------------------------------------------------------------------------

export const linkedinAuth = onCall(
  async (request: CallableRequest<{ code: string; redirectUri?: string }>) => {
    const { code, redirectUri } = request.data;
    if (!code) {
      throw new HttpsError("invalid-argument", "code is required");
    }

    const cfg = linkedinConfig();
    // Confidential-client (server-side) auth-code exchange uses client_secret,
    // not PKCE. The redirect_uri must match the one the app used to obtain the
    // code; fall back to the configured default if the client omits it.
    const effectiveRedirectUri = redirectUri ?? cfg.redirectUri;

    // Exchange authorisation code for access token
    let accessToken: string;
    try {
      const tokenResp = await axios.post(
        "https://www.linkedin.com/oauth/v2/accessToken",
        new URLSearchParams({
          grant_type: "authorization_code",
          code,
          redirect_uri: effectiveRedirectUri,
          client_id: cfg.clientId,
          client_secret: cfg.clientSecret,
        }),
        { headers: { "Content-Type": "application/x-www-form-urlencoded" } }
      );
      accessToken = tokenResp.data.access_token as string;
    } catch (err: unknown) {
      logger.error("LinkedIn token exchange failed", err);
      throw new HttpsError("unauthenticated", "LinkedIn token exchange failed");
    }

    // Fetch LinkedIn lite profile
    let profile: {
      id: string;
      localizedFirstName: string;
      localizedLastName: string;
      profilePicture?: {
        "displayImage~"?: {
          elements?: Array<{ identifiers?: Array<{ identifier?: string }> }>;
        };
      };
    };
    try {
      const profileResp = await axios.get(
        "https://api.linkedin.com/v2/me?projection=(id,localizedFirstName,localizedLastName,profilePicture(displayImage~:playableStreams))",
        { headers: { Authorization: `Bearer ${accessToken}` } }
      );
      profile = profileResp.data;
    } catch (err: unknown) {
      logger.error("LinkedIn profile fetch failed", err);
      throw new HttpsError("unauthenticated", "Could not fetch LinkedIn profile");
    }

    const displayName = `${profile.localizedFirstName} ${profile.localizedLastName}`;
    const avatarUrl = extractLinkedinAvatar(profile);

    // Best-effort email — requires the r_emailaddress scope. If it is not
    // granted the request 401s; we swallow it and return null rather than
    // failing the whole sign-in.
    let email: string | null = null;
    try {
      const emailResp = await axios.get(
        "https://api.linkedin.com/v2/emailAddress?q=members&projection=(elements*(handle~))",
        { headers: { Authorization: `Bearer ${accessToken}` } }
      );
      email = emailResp.data?.elements?.[0]?.["handle~"]?.emailAddress ?? null;
    } catch {
      logger.info("LinkedIn email unavailable (scope not granted)");
    }

    const linkedinHash = hashLinkedinId(profile.id, cfg.hmacSecret);

    // Check for existing user by linkedinHash (camelCase, single users schema).
    const usersSnap = await db
      .collection("users")
      .where("linkedinHash", "==", linkedinHash)
      .limit(1)
      .get();

    let uid: string;
    let isNewUser: boolean;

    if (!usersSnap.empty) {
      // Existing user
      uid = usersSnap.docs[0].id;
      isNewUser = false;
      logger.info("Existing LinkedIn user signed in", { uid });
    } else {
      // New user — create Firebase Auth user
      const authUser = await admin.auth().createUser({
        displayName,
      });
      uid = authUser.uid;
      isNewUser = true;

      const now = admin.firestore.FieldValue.serverTimestamp();
      const batch = db.batch();

      // User document — single canonical camelCase schema (read by both the
      // mobile UserModel and the admin portal; no snake_case duplicates).
      batch.set(db.collection("users").doc(uid), {
        uid,
        linkedinHash,
        displayName,
        firstName: profile.localizedFirstName,
        lastName: profile.localizedLastName,
        avatarUrl: avatarUrl,
        email: email,
        role: "free",
        companyId: null,
        department: null,
        kvkkAccepted: false,
        kvkkVersion: null,
        createdAt: now,
        updatedAt: now,
        deleted: false,
      });

      // Wallet — 0 credits
      batch.set(db.collection("wallets").doc(uid), {
        userId: uid,
        credits: 0,
        total_purchased: 0,
        created_at: now,
        updated_at: now,
      });

      // Subscription — free tier
      batch.set(db.collection("subscriptions").doc(uid), {
        userId: uid,
        plan: "free",
        status: "active",
        stripe_customer_id: null,
        stripe_subscription_id: null,
        current_period_end: null,
        created_at: now,
        updated_at: now,
      });

      await batch.commit();
      logger.info("New LinkedIn user created", { uid });
    }

    // Ensure the pseudonymous userIdHash is present on the user doc. New users:
    // stamps it on the freshly-created doc; existing users: backfills if missing.
    // firestore.rules read this to bridge owner access to anonymous check-ins.
    const userIdHash = hashUserId(uid);
    await db.collection("users").doc(uid).set({ userIdHash }, { merge: true });

    // Set custom claims on the Firebase Auth user record
    await admin.auth().setCustomUserClaims(uid, {
      role: "free",
      is_admin: false,
      linkedin_hash: linkedinHash,
    });

    // Create Firebase custom token (claims embedded for immediate use)
    const customToken = await admin.auth().createCustomToken(uid, {
      role: "free",
      is_admin: false,
      linkedin_hash: linkedinHash,
    });

    // Return the custom token plus the profile fields the mobile client needs
    // to render immediately. `linkedinHash` is the server-computed dedup key so
    // the client never re-hashes with a divergent secret.
    return { customToken, isNewUser, linkedinHash, userIdHash, displayName, avatarUrl, email };
  }
);

// ---------------------------------------------------------------------------
// 2. createPaymentIntent — HTTPS Callable (Auth required)
// ---------------------------------------------------------------------------

// Authoritative credit packs (credits → price in TRY). The client MUST NOT
// dictate the charge amount independently of the credit count, otherwise a
// crafted request could pay 1 kuruş for an arbitrary number of credits. The
// server derives the amount from `creditAmount` against this allow-list, so the
// client-supplied `amount` is never trusted. Mirrors AppConstants.creditPacks
// in mobile/lib/core/constants/app_constants.dart — keep the two in sync.
const CREDIT_PACKS: Record<number, number> = {
  10: 49,
  50: 199,
  100: 349,
};

export const createPaymentIntent = onCall(
  async (
    request: CallableRequest<{ amount?: number; currency: string; creditAmount: number }>
  ) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const { currency, creditAmount } = request.data;
    if (!currency) {
      throw new HttpsError("invalid-argument", "currency is required");
    }
    // Only TRY packs are sold; reject anything else so the amount lookup below
    // (denominated in TRY kuruş) cannot be bypassed with a foreign currency.
    if (currency.toLowerCase() !== "try") {
      throw new HttpsError("invalid-argument", "currency must be 'try'");
    }
    // Derive the charge amount server-side from the requested pack. Never trust
    // request.data.amount — it is intentionally ignored.
    const priceInTry = CREDIT_PACKS[creditAmount];
    if (!priceInTry) {
      throw new HttpsError(
        "invalid-argument",
        "creditAmount must match a valid credit pack"
      );
    }
    const amount = priceInTry * 100; // TRY → kuruş

    const stripe = getStripe();
    const uid = request.auth.uid;

    // Fetch or create Stripe customer
    const subDoc = await db.collection("subscriptions").doc(uid).get();
    let stripeCustomerId: string | null = subDoc.exists
      ? (subDoc.data()?.stripe_customer_id ?? null)
      : null;

    if (!stripeCustomerId) {
      const userDoc = await db.collection("users").doc(uid).get();
      const customer = await stripe.customers.create({
        metadata: { firebase_uid: uid },
        name: userDoc.data()?.displayName ?? undefined,
      });
      stripeCustomerId = customer.id;
      await db
        .collection("subscriptions")
        .doc(uid)
        .set({ stripe_customer_id: stripeCustomerId }, { merge: true });
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency: currency.toLowerCase(),
      customer: stripeCustomerId,
      metadata: { firebase_uid: uid, credit_amount: String(creditAmount) },
    });

    // Store pending transaction
    await db.collection("transactions").add({
      userId: uid,
      stripePaymentIntentId: paymentIntent.id,
      amount,
      currency: currency.toLowerCase(),
      creditAmount,
      status: "pending",
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { clientSecret: paymentIntent.client_secret };
  }
);

// ---------------------------------------------------------------------------
// 3. createSubscription — HTTPS Callable (Auth required)
// ---------------------------------------------------------------------------

export const createSubscription = onCall(
  async (request: CallableRequest<{ planId: "pro" | "enterprise" }>) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const { planId } = request.data;
    if (!["pro", "enterprise"].includes(planId)) {
      throw new HttpsError("invalid-argument", "planId must be 'pro' or 'enterprise'");
    }

    const stripe = getStripe();
    const uid = request.auth.uid;

    // Load stripe plan config from Firestore
    const plansDoc = await db.collection("platform_config").doc("stripe_plans").get();
    const plans = plansDoc.data() as
      | Record<string, { price_id: string; amount: number; currency: string }>
      | undefined;
    const plan = plans?.[planId];
    if (!plan?.price_id || plan.price_id === "price_REPLACE_ME") {
      throw new HttpsError(
        "failed-precondition",
        `Stripe price ID for plan '${planId}' is not configured`
      );
    }

    // Fetch or create Stripe customer
    const subDoc = await db.collection("subscriptions").doc(uid).get();
    let stripeCustomerId: string | null = subDoc.exists
      ? (subDoc.data()?.stripe_customer_id ?? null)
      : null;

    if (!stripeCustomerId) {
      const userDoc = await db.collection("users").doc(uid).get();
      const customer = await stripe.customers.create({
        metadata: { firebase_uid: uid },
        name: userDoc.data()?.displayName ?? undefined,
      });
      stripeCustomerId = customer.id;
    }

    // Create Stripe subscription (incomplete — requires client-side payment confirmation)
    const subscription = await stripe.subscriptions.create({
      customer: stripeCustomerId,
      items: [{ price: plan.price_id }],
      payment_behavior: "default_incomplete",
      expand: ["latest_invoice.payment_intent"],
      metadata: { firebase_uid: uid, plan_id: planId },
    });

    const invoice = subscription.latest_invoice as Stripe.Invoice;
    const paymentIntent = invoice.payment_intent as Stripe.PaymentIntent;

    // Persist pending subscription state
    await db.collection("subscriptions").doc(uid).set(
      {
        stripe_customer_id: stripeCustomerId,
        stripe_subscription_id: subscription.id,
        plan: planId,
        status: "incomplete",
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return { clientSecret: paymentIntent.client_secret, subscriptionId: subscription.id };
  }
);

// ---------------------------------------------------------------------------
// 4. stripeWebhook — HTTPS (public, validates Stripe signature)
// ---------------------------------------------------------------------------

export const stripeWebhook = onRequest(async (req, res) => {
  const stripe = getStripe();
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET ?? "";

  const sig = req.headers["stripe-signature"] as string;
  let event: Stripe.Event;

  try {
    event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
  } catch (err: unknown) {
    logger.warn("Stripe webhook signature verification failed", { err });
    res.status(400).send("Webhook signature verification failed");
    return;
  }

  logger.info("Stripe webhook received", { type: event.type });

  try {
    switch (event.type) {
      case "payment_intent.succeeded": {
        const pi = event.data.object as Stripe.PaymentIntent;
        const uid = pi.metadata?.firebase_uid;
        const creditAmount = parseInt(pi.metadata?.credit_amount ?? "0", 10);
        if (uid && creditAmount > 0) {
          await db
            .collection("wallets")
            .doc(uid)
            .set(
              {
                credits: admin.firestore.FieldValue.increment(creditAmount),
                total_purchased: admin.firestore.FieldValue.increment(creditAmount),
                updated_at: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true }
            );
          // Mark transaction as succeeded
          const txSnap = await db
            .collection("transactions")
            .where("stripePaymentIntentId", "==", pi.id)
            .limit(1)
            .get();
          if (!txSnap.empty) {
            await txSnap.docs[0].ref.update({ status: "succeeded" });
          }
          logger.info("Credits added to wallet", { uid, creditAmount });
        }
        break;
      }

      case "customer.subscription.created":
      case "customer.subscription.updated": {
        const sub = event.data.object as Stripe.Subscription;
        const uid = sub.metadata?.firebase_uid;
        if (!uid) break;

        const planId = (
          sub.items.data[0]?.price?.metadata?.plan_id ??
          sub.metadata?.plan_id ??
          "free"
        ) as string;
        const status = sub.status;
        // current_period_end is a Unix timestamp in seconds
        const periodEndSeconds = (sub as unknown as { current_period_end: number })
          .current_period_end;
        const currentPeriodEnd = new Date(periodEndSeconds * 1000);

        await db.collection("subscriptions").doc(uid).set(
          {
            plan: planId,
            status,
            stripe_subscription_id: sub.id,
            current_period_end: admin.firestore.Timestamp.fromDate(currentPeriodEnd),
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        // Update custom claims when subscription becomes active
        if (status === "active") {
          await admin.auth().setCustomUserClaims(uid, {
            role: planId,
            is_admin: false,
          });
        }

        logger.info("Subscription updated in Firestore", { uid, planId, status });
        break;
      }

      case "customer.subscription.deleted": {
        const sub = event.data.object as Stripe.Subscription;
        const uid = sub.metadata?.firebase_uid;
        if (!uid) break;

        await db.collection("subscriptions").doc(uid).set(
          {
            plan: "free",
            status: "canceled",
            current_period_end: null,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        // Downgrade custom claims to free
        await admin.auth().setCustomUserClaims(uid, {
          role: "free",
          is_admin: false,
        });

        logger.info("Subscription canceled, downgraded to free", { uid });
        break;
      }

      default:
        logger.info("Unhandled Stripe webhook event", { type: event.type });
    }
  } catch (err: unknown) {
    logger.error("Error processing Stripe webhook", { err });
    res.status(500).send("Internal error processing webhook");
    return;
  }

  res.json({ received: true });
});

// ---------------------------------------------------------------------------
// 5. cancelSubscription — HTTPS Callable (Auth required)
// ---------------------------------------------------------------------------

export const cancelSubscription = onCall(
  async (request: CallableRequest<{ subscriptionId: string }>) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const { subscriptionId } = request.data;
    if (!subscriptionId) {
      throw new HttpsError("invalid-argument", "subscriptionId is required");
    }

    const uid = request.auth.uid;

    // Subscription doc ID equals the Firebase UID
    const subRef = db.collection("subscriptions").doc(uid);
    const subDoc = await subRef.get();

    if (!subDoc.exists) {
      throw new HttpsError("not-found", "Subscription not found");
    }

    const storedSubId = subDoc.data()?.stripe_subscription_id as string | null;
    if (!storedSubId || storedSubId !== subscriptionId) {
      throw new HttpsError("permission-denied", "Subscription ID mismatch");
    }

    const stripe = getStripe();
    // Cancel at period end — user retains access until the current period expires
    await stripe.subscriptions.update(subscriptionId, {
      cancel_at_period_end: true,
    });

    await subRef.update({
      cancel_at_period_end: true,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info("Subscription scheduled for cancellation", { uid, subscriptionId });
    return { success: true };
  }
);

// ---------------------------------------------------------------------------
// 6b. deleteAccount — HTTPS Callable (Auth required)
// ---------------------------------------------------------------------------

export const deleteAccount = onCall(async (request: CallableRequest<unknown>) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required");
  }

  const uid = request.auth.uid;
  const timestamp = Date.now();

  // The pseudonym this user's check-ins / insights are keyed by.
  const userDoc = await db.collection("users").doc(uid).get();
  const oldHash =
    (userDoc.data()?.userIdHash as string | undefined) ?? hashUserId(uid);
  // Unique per user (carries the old hash) so two accounts deleted in the same
  // instant never collapse into one cohort in aggregate stats.
  const deletedHash = `deleted_${oldHash}`;

  // Right to erasure on check-ins: rotate every past check-in's userIdHash to
  // sever the pseudonym → person link. The anonymised rows remain so company
  // aggregates stay intact. (Single batch; a user never has >500 check-ins
  // pre-launch — chunk this if that assumption ever changes.)
  const userCheckins = await db
    .collection("checkins")
    .where("userIdHash", "==", oldHash)
    .get();
  if (!userCheckins.empty) {
    const batch = db.batch();
    userCheckins.docs.forEach((d) =>
      batch.update(d.ref, { userIdHash: deletedHash })
    );
    await batch.commit();
  }

  // Delete the personal insights doc (the user's own aggregate).
  await db.collection("insights").doc(oldHash).delete();

  // Anonymise the user document — keep the record for company aggregate stats.
  await db.collection("users").doc(uid).update({
    displayName: null,
    firstName: null,
    lastName: null,
    avatarUrl: null,
    email: null,
    linkedinHash: `deleted_${timestamp}`,
    userIdHash: deletedHash,
    deleted: true,
    deletedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Revoke tokens then delete the Auth user
  await admin.auth().revokeRefreshTokens(uid);
  await admin.auth().deleteUser(uid);

  logger.info("Account deleted and anonymised", {
    checkinsRotated: userCheckins.size,
  });
  return { success: true };
});

// ---------------------------------------------------------------------------
// 6. computeInsights — Firestore trigger on checkin create
// ---------------------------------------------------------------------------

type CheckinDoc = {
  userIdHash: string;
  companyId?: string;
  department?: string;
  scores: Record<string, number>;
  created_at: admin.firestore.Timestamp;
};

export const computeInsights = onDocumentCreated(
  "checkins/{checkinId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const checkin = snap.data() as CheckinDoc;
    const { userIdHash, companyId, department, scores } = checkin;
    if (!userIdHash) return;

    // Load thresholds (cached)
    const thresholds = (await cachedRead("platform_config/thresholds", async () => {
      const doc = await db.collection("platform_config").doc("thresholds").get();
      return doc.exists ? doc.data() : {};
    })) as Record<string, number>;

    const safeThresholds = applyThresholdFloors(thresholds);
    const companyMinN = safeThresholds.company_min_n;
    const deptMinN = safeThresholds.department_min_n;

    // Fetch all user check-ins for personal stats (ordered asc for trend)
    const userCheckinsSnap = await db
      .collection("checkins")
      .where("userIdHash", "==", userIdHash)
      .orderBy("created_at", "asc")
      .get();

    const userCheckins = userCheckinsSnap.docs.map((d) => d.data() as CheckinDoc);
    const dimensions = Object.keys(scores);

    // Personal averages
    const personalAvg: Record<string, number> = {};
    for (const dim of dimensions) {
      const vals = userCheckins
        .map((c) => c.scores?.[dim] ?? null)
        .filter((v): v is number => v !== null);
      const a = avg(vals);
      if (a !== null) personalAvg[dim] = a;
    }

    // OLS retention risk: negative slope (mood declining) → higher risk
    const moodTimeSeries = userCheckins.map((c) => {
      const dimVals = dimensions
        .map((d) => c.scores?.[d] ?? null)
        .filter((v): v is number => v !== null);
      return avg(dimVals) ?? 0;
    });
    const trendSlope = olsSlope(moodTimeSeries);
    // Clamp retention risk to [0, 1]; slope of -0.05 → risk ~1.0
    const retentionRisk = Math.max(0, Math.min(1, 0.5 - trendSlope * 10));

    // Company averages (N ≥ companyMinN)
    let companyAvg: Record<string, number> | null = null;
    let companyCheckinCount = 0;
    if (companyId) {
      const companyCheckinsSnap = await db
        .collection("checkins")
        .where("companyId", "==", companyId)
        .get();
      companyCheckinCount = companyCheckinsSnap.size;
      if (companyCheckinsSnap.size >= companyMinN) {
        companyAvg = {};
        for (const dim of dimensions) {
          const vals = companyCheckinsSnap.docs
            .map((d) => (d.data() as CheckinDoc).scores?.[dim] ?? null)
            .filter((v): v is number => v !== null);
          const a = avg(vals);
          if (a !== null) companyAvg[dim] = a;
        }
      }
    }

    // Department averages (N ≥ deptMinN)
    let departmentAvg: Record<string, number> | null = null;
    let deptCheckinCount = 0;
    if (companyId && department) {
      const deptCheckinsSnap = await db
        .collection("checkins")
        .where("companyId", "==", companyId)
        .where("department", "==", department)
        .get();
      deptCheckinCount = deptCheckinsSnap.size;
      if (deptCheckinsSnap.size >= deptMinN) {
        departmentAvg = {};
        for (const dim of dimensions) {
          const vals = deptCheckinsSnap.docs
            .map((d) => (d.data() as CheckinDoc).scores?.[dim] ?? null)
            .filter((v): v is number => v !== null);
          const a = avg(vals);
          if (a !== null) departmentAvg[dim] = a;
        }
      }
    }

    // Write insights document for the user — keyed by the pseudonymous
    // userIdHash (no raw uid), so the insights collection is also anonymous at
    // rest. firestore.rules grant owner read by comparing the doc id to the
    // caller's users/{uid}.userIdHash.
    await db
      .collection("insights")
      .doc(userIdHash)
      .set(
        {
          userIdHash,
          companyId: companyId ?? null,
          department_name: department ?? null,
          personal: {
            avg: personalAvg,
            checkin_count: userCheckins.length,
            trend_slope: trendSlope,
            retention_risk: retentionRisk,
          },
          company: companyAvg
            ? { avg: companyAvg, checkin_count: companyCheckinCount }
            : null,
          department_stats: departmentAvg
            ? { avg: departmentAvg, checkin_count: deptCheckinCount }
            : null,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

    logger.info("Insights computed", { companyId, retentionRisk });
  }
);

// ---------------------------------------------------------------------------
// 6b. computeSurveyAggregate — scheduled min-N-protected survey aggregates
// ---------------------------------------------------------------------------
// The 48-question Genel Çalışan Deneyimi Anketi is a platform survey
// (companyId='__admin__'), so survey_responses do NOT carry the respondent's
// real company/department. We recover them by JOINING on sha256(uid): the mobile
// submit path stores `userIdHash = sha256(uid)` (plain, unsalted — see
// surveys_repository.dart hashUserId), so for each user we recompute sha256(uid)
// and match it to the response. Mirrors scripts/seed_gate_aggregate_data.js
// --verify (the reference implementation) + the scoring engine in
// admin/.../PortalSurveyResultsPage.tsx and mobile survey_scoring.dart.
//
// Output: one doc per (survey, company) at survey_aggregates/{surveyId}__{cid},
// containing that company's aggregate + its departments + its sector benchmark
// (sector denormalized so a user reads ONE doc). firestore.rules restrict each
// doc to that company's members (+ admins), so no company sees another's scores;
// the sector block is an anonymized cross-company benchmark.

type SurveyQ = {
  id: string;
  type: string;
  category?: string;
  reverseScore?: boolean;
  isEnps?: boolean;
};

/** Normalize one survey answer to 1–5 (mirrors survey_scoring.dart). */
function normalizeSurveyAnswer(
  answer: unknown,
  type: string,
  reverseScore?: boolean
): number | null {
  if (answer === null || answer === undefined) return null;
  switch (type) {
    case "emoji5":
      return typeof answer === "number" ? answer + 1 : null; // mobile 0-indexed
    case "scale5":
      return typeof answer === "number" ? answer : null;
    case "scale10":
      return typeof answer === "number" ? (answer / 10) * 4 + 1 : null;
    case "yesno":
    case "trueFalse":
      if (typeof answer !== "boolean") return null;
      return answer ? (reverseScore ? 1 : 5) : (reverseScore ? 5 : 1);
    default:
      return null;
  }
}

type Acc = { n: number; cat: Record<string, number[]>; enps: number[] };
const emptyAcc = (): Acc => ({ n: 0, cat: {}, enps: [] });

function accInto(
  acc: Acc,
  questions: SurveyQ[],
  answers: Record<string, unknown>,
  enpsQ?: SurveyQ
): void {
  acc.n += 1;
  for (const q of questions) {
    if (!q.category || q.type === "text") continue;
    const v = normalizeSurveyAnswer(answers[q.id], q.type, q.reverseScore);
    if (v === null) continue;
    (acc.cat[q.category] = acc.cat[q.category] ?? []).push(v);
  }
  if (enpsQ && typeof answers[enpsQ.id] === "number") {
    acc.enps.push(answers[enpsQ.id] as number);
  }
}

function enpsScore(raw: number[]): number | null {
  if (raw.length === 0) return null;
  const promoters = raw.filter((x) => x >= 9).length;
  const detractors = raw.filter((x) => x <= 6).length;
  return Math.round((promoters / raw.length) * 100 - (detractors / raw.length) * 100);
}

/** Reduce an accumulator to a published group summary, gated by min-N. */
function summarize(acc: Acc, minN: number) {
  if (acc.n < minN) {
    return { n: acc.n, locked: true, overall: null, categories: {}, enps: null };
  }
  const categories: Record<string, number> = {};
  for (const [c, vals] of Object.entries(acc.cat)) {
    if (vals.length) categories[c] = Math.round((avg(vals) as number) * 100) / 100;
  }
  const catVals = Object.values(categories);
  const overall = catVals.length
    ? Math.round((catVals.reduce((s, v) => s + v, 0) / catVals.length) * 100) / 100
    : null;
  return { n: acc.n, locked: false, overall, categories, enps: enpsScore(acc.enps) };
}

export const computeSurveyAggregate = onSchedule(
  {
    schedule: "every 24 hours",
    region: "europe-west1",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
    const thresholds = (await (async () => {
      const doc = await db.collection("platform_config").doc("thresholds").get();
      return doc.exists ? doc.data() : {};
    })()) as Record<string, number>;
    const safe = applyThresholdFloors(thresholds);
    const companyMinN = safe.company_min_n;
    const deptMinN = safe.department_min_n;

    // sha256(uid) → {companyId, department}; companyId → industry.
    const usersSnap = await db.collection("users").get();
    const hashToUser = new Map<string, { companyId: string; department: string }>();
    for (const d of usersSnap.docs) {
      const u = d.data();
      if (!u.companyId || u.deleted) continue;
      const h = crypto.createHash("sha256").update(d.id).digest("hex");
      hashToUser.set(h, { companyId: u.companyId, department: (u.department as string) ?? "(belirsiz)" });
    }
    const companiesSnap = await db.collection("companies").get();
    const industryOf = new Map<string, string>();
    const nameOf = new Map<string, string>();
    for (const d of companiesSnap.docs) {
      industryOf.set(d.id, (d.data().industry as string) ?? "Diğer");
      nameOf.set(d.id, (d.data().name as string) ?? d.id);
    }

    // Experience surveys = active surveys whose questions carry categories.
    const surveysSnap = await db.collection("surveys").where("status", "==", "active").get();
    let surveysProcessed = 0;
    let docsWritten = 0;

    for (const sdoc of surveysSnap.docs) {
      const questions = ((sdoc.data().questions as SurveyQ[]) ?? []).filter(Boolean);
      if (!questions.some((q) => q.category)) continue;
      const enpsQ = questions.find((q) => q.isEnps && q.type === "scale10");

      const respSnap = await db.collection("survey_responses").where("surveyId", "==", sdoc.id).get();

      const companyAcc: Record<string, Acc> = {};
      const deptAcc: Record<string, Record<string, Acc>> = {};
      const sectorAcc: Record<string, Acc & { companies: Set<string> }> = {};

      for (const r of respSnap.docs) {
        const data = r.data();
        const g = hashToUser.get(data.userIdHash);
        if (!g) continue; // unjoined response (no matching user)
        const answers = (data.answers as Record<string, unknown>) ?? {};
        const industry = industryOf.get(g.companyId) ?? "Diğer";

        (companyAcc[g.companyId] ??= emptyAcc());
        accInto(companyAcc[g.companyId], questions, answers, enpsQ);

        (deptAcc[g.companyId] ??= {});
        (deptAcc[g.companyId][g.department] ??= emptyAcc());
        accInto(deptAcc[g.companyId][g.department], questions, answers, enpsQ);

        const sa = (sectorAcc[industry] ??= Object.assign(emptyAcc(), { companies: new Set<string>() }));
        accInto(sa, questions, answers, enpsQ);
        sa.companies.add(g.companyId);
      }

      const batch = db.batch();
      for (const companyId of Object.keys(companyAcc)) {
        const industry = industryOf.get(companyId) ?? "Diğer";
        const sa = sectorAcc[industry];
        const departments: Record<string, ReturnType<typeof summarize>> = {};
        for (const [dept, acc] of Object.entries(deptAcc[companyId] ?? {})) {
          departments[dept] = summarize(acc, deptMinN);
        }
        const ref = db.collection("survey_aggregates").doc(`${sdoc.id}__${companyId}`);
        batch.set(ref, {
          surveyId: sdoc.id,
          companyId,
          companyMinN,
          departmentMinN: deptMinN,
          company: summarize(companyAcc[companyId], companyMinN),
          departments,
          sector: sa
            ? { industry, nCompanies: sa.companies.size, ...summarize(sa, companyMinN) }
            : null,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        docsWritten += 1;
      }

      // Cross-company benchmark doc: anonymized, min-N-cleared company averages +
      // sector averages, readable by any authenticated user (the benchmarking
      // product). Only companies that cleared the company floor are listed — no
      // individuals, no sub-min-N groups. Drives the "Şirket Karşılaştırması"
      // survey comparison (Sen vs selected companies / sector / all).
      const benchCompanies = Object.keys(companyAcc)
        .map((companyId) => {
          const s = summarize(companyAcc[companyId], companyMinN);
          if (s.locked) return null;
          return {
            companyId,
            name: nameOf.get(companyId) ?? companyId,
            industry: industryOf.get(companyId) ?? "Diğer",
            n: s.n,
            overall: s.overall,
            categories: s.categories,
            enps: s.enps,
          };
        })
        .filter((c): c is NonNullable<typeof c> => c !== null)
        .sort((a, b) => (b.overall ?? 0) - (a.overall ?? 0));

      const benchSectors: Record<string, unknown> = {};
      for (const [industry, sa] of Object.entries(sectorAcc)) {
        const s = summarize(sa, companyMinN);
        if (s.locked) continue;
        benchSectors[industry] = {
          industry,
          nCompanies: sa.companies.size,
          n: s.n,
          overall: s.overall,
          categories: s.categories,
          enps: s.enps,
        };
      }

      batch.set(db.collection("survey_benchmarks").doc(sdoc.id), {
        surveyId: sdoc.id,
        companyMinN,
        companies: benchCompanies,
        sectors: benchSectors,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      docsWritten += 1;

      await batch.commit();
      surveysProcessed += 1;
    }

    logger.info("computeSurveyAggregate done", { surveysProcessed, docsWritten });
  }
);

// ---------------------------------------------------------------------------
// 6d. submitSurveyResponse — HTTPS Callable (Auth required)
// ---------------------------------------------------------------------------
// Server-authoritative survey submission. Previously the mobile client wrote
// survey_responses directly (+ incremented responseCount, + updated its own user
// doc) in a batch, which firestore.rules could not fully constrain: rules cannot
// hash sha256(uid) to prove the userIdHash belongs to the caller, nor enforce
// one-response-per-user. That let a malicious client attribute responses to an
// arbitrary userIdHash or stuff the ballot to skew a company's aggregates. This
// callable closes both: the pseudonym is derived from request.auth.uid, the
// companyId is taken from the survey (not the client), and a transaction enforces
// a single response per user. firestore.rules now set survey_responses create to
// `false` so this is the only write path.
export const submitSurveyResponse = onCall(
  async (
    request: CallableRequest<{ surveyId: string; answers: Record<string, unknown> }>
  ) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    const uid = request.auth.uid;
    const { surveyId, answers } = request.data;
    if (!surveyId || typeof surveyId !== "string") {
      throw new HttpsError("invalid-argument", "surveyId is required");
    }
    if (!answers || typeof answers !== "object" || Array.isArray(answers)) {
      throw new HttpsError("invalid-argument", "answers must be a map");
    }

    // Survey must exist. companyId is read from the survey (never the client) so a
    // response cannot be mislabeled into another company's data pool. Platform
    // surveys carry companyId '__admin__' on both sides.
    const surveyRef = db.collection("surveys").doc(surveyId);
    const surveySnap = await surveyRef.get();
    if (!surveySnap.exists) {
      throw new HttpsError("not-found", "Survey not found");
    }
    const surveyCompanyId =
      (surveySnap.data()?.companyId as string | undefined) ?? "__admin__";

    // Pseudonym used by computeSurveyAggregate to JOIN responses back to a user.
    // MUST remain plain (unsalted) sha256(uid) to match that join + the mobile
    // hashUserId it replaces.
    const userIdHash = crypto.createHash("sha256").update(uid).digest("hex");
    const userRef = db.collection("users").doc(uid);

    // One response per user per survey, enforced transactionally on the user's own
    // answeredSurveyIds (the app's source of truth) so two concurrent submits
    // cannot both succeed.
    await db.runTransaction(async (tx) => {
      const userDoc = await tx.get(userRef);
      const answered =
        (userDoc.data()?.answeredSurveyIds as string[] | undefined) ?? [];
      if (answered.includes(surveyId)) {
        throw new HttpsError("already-exists", "Survey already answered");
      }

      const responseRef = db.collection("survey_responses").doc();
      tx.set(responseRef, {
        surveyId,
        companyId: surveyCompanyId,
        userIdHash,
        answers,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.update(surveyRef, {
        responseCount: admin.firestore.FieldValue.increment(1),
      });
      // Mirror the answered state onto the owner-readable user doc so the app
      // keeps working without reading survey_responses (admin/company-only).
      tx.set(
        userRef,
        {
          answeredSurveyIds: admin.firestore.FieldValue.arrayUnion(surveyId),
          surveyAnswers: { [surveyId]: answers },
        },
        { merge: true }
      );
    });

    logger.info("Survey response submitted", { surveyId, companyId: surveyCompanyId });
    return { success: true };
  }
);

// ---------------------------------------------------------------------------
// 7. getThresholds — HTTPS Callable (Auth required)
// ---------------------------------------------------------------------------

export const getThresholds = onCall(async (request: CallableRequest<unknown>) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required");
  }

  const raw = (await cachedRead("platform_config/thresholds", async () => {
    const doc = await db.collection("platform_config").doc("thresholds").get();
    return doc.exists ? doc.data() : {};
  })) as Record<string, unknown>;

  // Expose only numeric thresholds — drop metadata (e.g. _updated_at) so the
  // payload stays a clean Record<string, number>.
  return applyThresholdFloors(sanitizeThresholdInput(raw));
});

// ---------------------------------------------------------------------------
// 8. updateThresholds — HTTPS Callable (Admin only)
// ---------------------------------------------------------------------------

export const updateThresholds = onCall(
  async (request: CallableRequest<Record<string, unknown>>) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    if (request.auth.token.is_admin !== true) {
      throw new HttpsError("permission-denied", "Admin access required");
    }

    // Drop non-numeric fields before applying floors so undefined / NaN /
    // strings can never reach Firestore (which would fail the write with an
    // opaque "internal" error — the F-ADM5 symptom).
    const safe = applyThresholdFloors(sanitizeThresholdInput(request.data));

    await db.collection("platform_config").doc("thresholds").set(
      { ...safe, _updated_at: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true }
    );

    // Invalidate cache so the next read picks up new values
    cache.delete("platform_config/thresholds");

    logger.info("Thresholds updated by admin", { uid: request.auth.uid, safe });
    return safe;
  }
);

// ---------------------------------------------------------------------------
// 9. daasWidgetApi — HTTPS (API key auth, rate-limited)
// ---------------------------------------------------------------------------

export const daasWidgetApi = onRequest(async (req, res) => {
  // Only GET is supported
  if (req.method !== "GET") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const apiKey = (req.headers["x-api-key"] ?? req.query.api_key) as string | undefined;
  if (!apiKey) {
    res.status(401).json({ error: "API key required" });
    return;
  }

  // Validate API key
  const keySnap = await db
    .collection("daas_api_keys")
    .where("key", "==", apiKey)
    .where("active", "==", true)
    .limit(1)
    .get();
  if (keySnap.empty) {
    res.status(401).json({ error: "Invalid or inactive API key" });
    return;
  }

  const keyDoc = keySnap.docs[0];
  const keyData = keyDoc.data() as {
    userId: string;
    companyId: string;
    key: string;
    active: boolean;
    rate_limit_hour: number;
  };

  // Rate limiting: N requests per hour using Firestore counter
  const windowStart = new Date();
  windowStart.setMinutes(0, 0, 0); // truncate to start of current hour
  const windowKey = windowStart.toISOString();

  const rateRef = db
    .collection("daas_rate_limits")
    .doc(`${keyDoc.id}_${windowKey}`);
  const rateDoc = await rateRef.get();
  const currentCount: number = rateDoc.exists ? (rateDoc.data()?.count ?? 0) : 0;

  const rateLimit = keyData.rate_limit_hour ?? 100;
  if (currentCount >= rateLimit) {
    res.status(429).json({ error: "Rate limit exceeded. Maximum 100 requests per hour." });
    return;
  }

  // Increment counter with 2-hour TTL for auto-clean
  await rateRef.set(
    {
      count: admin.firestore.FieldValue.increment(1),
      window: windowKey,
      expires_at: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 2 * 60 * 60 * 1000)
      ),
    },
    { merge: true }
  );

  const companyId = keyData.companyId;

  // Load thresholds (cached)
  const thresholds = (await cachedRead("platform_config/thresholds", async () => {
    const doc = await db.collection("platform_config").doc("thresholds").get();
    return doc.exists ? doc.data() : {};
  })) as Record<string, number>;
  const safe = applyThresholdFloors(thresholds);
  const companyMinN = safe.company_min_n;

  // Fetch recent company check-ins (cap at 500 for performance)
  const checkinsSnap = await db
    .collection("checkins")
    .where("companyId", "==", companyId)
    .orderBy("created_at", "desc")
    .limit(500)
    .get();

  if (checkinsSnap.size < companyMinN) {
    res.status(200).json({
      anonymized: true,
      message: `Insufficient data: minimum ${companyMinN} check-ins required`,
      wellbeing_score: null,
      dimensions: null,
      trend: null,
    });
    return;
  }

  type CheckinData = { scores: Record<string, number>; created_at: admin.firestore.Timestamp };
  const checkins = checkinsSnap.docs.map((d) => d.data() as CheckinData);
  const allDimensions = Object.keys(checkins[0]?.scores ?? {});

  // Aggregate dimension averages
  const dimAvgs: Record<string, number> = {};
  for (const dim of allDimensions) {
    const vals = checkins
      .map((c) => c.scores?.[dim])
      .filter((v): v is number => typeof v === "number");
    const a = avg(vals);
    if (a !== null) dimAvgs[dim] = parseFloat(a.toFixed(2));
  }

  const overallWellbeing = avg(Object.values(dimAvgs));

  // Trend: compare average of most recent 30 vs previous 30 check-ins
  const recent = checkins.slice(0, Math.min(30, checkins.length));
  const older = checkins.slice(
    Math.min(30, checkins.length),
    Math.min(60, checkins.length)
  );

  const recentAvg = avg(recent.flatMap((c) => Object.values(c.scores)));
  const olderAvg = avg(older.flatMap((c) => Object.values(c.scores)));
  let trend: "up" | "down" | "stable" = "stable";
  if (recentAvg !== null && olderAvg !== null) {
    const diff = recentAvg - olderAvg;
    if (diff > 0.2) trend = "up";
    else if (diff < -0.2) trend = "down";
  }

  res.status(200).json({
    anonymized: true,
    checkin_count: checkinsSnap.size,
    wellbeing_score:
      overallWellbeing !== null ? parseFloat(overallWellbeing.toFixed(2)) : null,
    dimensions: dimAvgs,
    trend,
  });
});

// ---------------------------------------------------------------------------
// 10. setAdminClaim — HTTPS Callable (Admin only)
// ---------------------------------------------------------------------------

export const setAdminClaim = onCall(
  async (request: CallableRequest<{ targetUid: string }>) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    if (!request.auth.token.is_admin) {
      throw new HttpsError("permission-denied", "Admin access required");
    }

    const { targetUid } = request.data;
    if (!targetUid) {
      throw new HttpsError("invalid-argument", "targetUid is required");
    }

    // Preserve any existing claims, then elevate
    const targetUser = await admin.auth().getUser(targetUid);
    const existingClaims = (targetUser.customClaims ?? {}) as Record<string, unknown>;

    await admin.auth().setCustomUserClaims(targetUid, {
      ...existingClaims,
      is_admin: true,
      role: "admin",
    });

    // Also record the admin in the `admins` collection so the admin portal can
    // list current admins — the Auth custom claim alone is not queryable from
    // the client (this was the F-ADM6 "empty admin list" bug). firestore.rules
    // already recognise admins/{uid} as an admin source.
    await db.collection("admins").doc(targetUid).set(
      {
        email: targetUser.email ?? null,
        displayName: targetUser.displayName ?? null,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    logger.info("Admin claim set", {
      by: request.auth.uid,
      for: targetUid,
    });

    return { success: true, targetUid };
  }
);
