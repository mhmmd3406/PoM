/**
 * PoM (Peace of Mind) — Firebase Cloud Functions
 * B2B Employee Wellbeing Platform
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
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
    const secret = functions.config().stripe?.secret_key ?? process.env.STRIPE_SECRET_KEY ?? "";
    if (!secret) throw new functions.https.HttpsError("failed-precondition", "Stripe secret key not configured");
    _stripe = new Stripe(secret, { apiVersion: "2024-06-20" });
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
    clientId: functions.config().linkedin?.client_id ?? process.env.LINKEDIN_CLIENT_ID ?? "",
    clientSecret: functions.config().linkedin?.client_secret ?? process.env.LINKEDIN_CLIENT_SECRET ?? "",
    redirectUri: functions.config().linkedin?.redirect_uri ?? process.env.LINKEDIN_REDIRECT_URI ?? "https://app.pom.app/auth/callback",
    hmacSecret: functions.config().linkedin?.hmac_secret ?? process.env.LINKEDIN_HMAC_SECRET ?? "pom-linkedin-hmac-secret",
  };
}

/** Compute HMAC-SHA256 of LinkedIn user ID */
function hashLinkedinId(linkedinId: string, secret: string): string {
  return crypto.createHmac("sha256", secret).update(linkedinId).digest("hex");
}

/** Safety-floor applied thresholds */
function applyThresholdFloors(raw: Record<string, number>): Record<string, number> {
  return {
    ...raw,
    company_min_n: Math.max(raw.company_min_n ?? 15, 7),
    department_min_n: Math.max(raw.department_min_n ?? 10, 5),
  };
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

export const linkedinAuth = functions.https.onCall(async (data: { code: string; codeVerifier: string }) => {
  const { code, codeVerifier } = data;
  if (!code || !codeVerifier) {
    throw new functions.https.HttpsError("invalid-argument", "code and codeVerifier are required");
  }

  const cfg = linkedinConfig();

  // Exchange authorisation code for access token
  let accessToken: string;
  try {
    const tokenResp = await axios.post(
      "https://www.linkedin.com/oauth/v2/accessToken",
      new URLSearchParams({
        grant_type: "authorization_code",
        code,
        redirect_uri: cfg.redirectUri,
        client_id: cfg.clientId,
        client_secret: cfg.clientSecret,
        code_verifier: codeVerifier,
      }),
      { headers: { "Content-Type": "application/x-www-form-urlencoded" } }
    );
    accessToken = tokenResp.data.access_token as string;
  } catch (err: unknown) {
    functions.logger.error("LinkedIn token exchange failed", err);
    throw new functions.https.HttpsError("unauthenticated", "LinkedIn token exchange failed");
  }

  // Fetch LinkedIn profile (lite profile + email)
  let profile: {
    id: string;
    localizedFirstName: string;
    localizedLastName: string;
    profilePicture?: { displayImage: string };
  };
  try {
    const profileResp = await axios.get("https://api.linkedin.com/v2/me?projection=(id,localizedFirstName,localizedLastName,profilePicture(displayImage~:playableStreams))", {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    profile = profileResp.data;
  } catch (err: unknown) {
    functions.logger.error("LinkedIn profile fetch failed", err);
    throw new functions.https.HttpsError("unauthenticated", "Could not fetch LinkedIn profile");
  }

  const linkedinHash = hashLinkedinId(profile.id, cfg.hmacSecret);

  // Check for existing user by linkedin_hash
  const usersSnap = await db.collection("users").where("linkedin_hash", "==", linkedinHash).limit(1).get();

  let uid: string;
  let isNewUser: boolean;

  if (!usersSnap.empty) {
    // Existing user
    uid = usersSnap.docs[0].id;
    isNewUser = false;
    functions.logger.info("Existing LinkedIn user signed in", { uid });
  } else {
    // New user — create Firebase Auth user
    const authUser = await admin.auth().createUser({
      displayName: `${profile.localizedFirstName} ${profile.localizedLastName}`,
    });
    uid = authUser.uid;
    isNewUser = true;

    const now = admin.firestore.FieldValue.serverTimestamp();
    const batch = db.batch();

    // User document
    batch.set(db.collection("users").doc(uid), {
      uid,
      linkedin_hash: linkedinHash,
      displayName: `${profile.localizedFirstName} ${profile.localizedLastName}`,
      firstName: profile.localizedFirstName,
      lastName: profile.localizedLastName,
      avatar: null,
      role: "free",
      companyId: null,
      department: null,
      kvkk_accepted: false,
      kvkk_version: null,
      created_at: now,
      updated_at: now,
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
    functions.logger.info("New LinkedIn user created", { uid });
  }

  // Set custom claims
  await admin.auth().setCustomUserClaims(uid, {
    role: "free",
    is_admin: false,
    linkedin_hash: linkedinHash,
  });

  // Create Firebase custom token
  const customToken = await admin.auth().createCustomToken(uid, {
    role: "free",
    is_admin: false,
    linkedin_hash: linkedinHash,
  });

  return { customToken, isNewUser };
});

// ---------------------------------------------------------------------------
// 2. createPaymentIntent — HTTPS Callable (Auth required)
// ---------------------------------------------------------------------------

export const createPaymentIntent = functions.https.onCall(
  async (data: { amount: number; currency: string; creditAmount: number }, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }
    const { amount, currency, creditAmount } = data;
    if (!amount || amount <= 0) {
      throw new functions.https.HttpsError("invalid-argument", "amount must be a positive number");
    }
    if (!currency) {
      throw new functions.https.HttpsError("invalid-argument", "currency is required");
    }
    if (!creditAmount || creditAmount <= 0) {
      throw new functions.https.HttpsError("invalid-argument", "creditAmount must be a positive number");
    }

    const stripe = getStripe();
    const uid = context.auth.uid;

    // Fetch or create Stripe customer
    const subDoc = await db.collection("subscriptions").doc(uid).get();
    let stripeCustomerId: string | null = subDoc.exists ? (subDoc.data()?.stripe_customer_id ?? null) : null;

    if (!stripeCustomerId) {
      const userDoc = await db.collection("users").doc(uid).get();
      const customer = await stripe.customers.create({
        metadata: { firebase_uid: uid },
        name: userDoc.data()?.displayName ?? undefined,
      });
      stripeCustomerId = customer.id;
      await db.collection("subscriptions").doc(uid).set({ stripe_customer_id: stripeCustomerId }, { merge: true });
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

export const createSubscription = functions.https.onCall(
  async (data: { planId: "pro" | "enterprise" }, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }
    const { planId } = data;
    if (!["pro", "enterprise"].includes(planId)) {
      throw new functions.https.HttpsError("invalid-argument", "planId must be 'pro' or 'enterprise'");
    }

    const stripe = getStripe();
    const uid = context.auth.uid;

    // Load stripe plan config from Firestore
    const plansDoc = await db.collection("platform_config").doc("stripe_plans").get();
    const plans = plansDoc.data() as Record<string, { price_id: string; amount: number; currency: string }> | undefined;
    const plan = plans?.[planId];
    if (!plan?.price_id || plan.price_id === "price_REPLACE_ME") {
      throw new functions.https.HttpsError("failed-precondition", `Stripe price ID for plan '${planId}' is not configured`);
    }

    // Fetch or create Stripe customer
    const subDoc = await db.collection("subscriptions").doc(uid).get();
    let stripeCustomerId: string | null = subDoc.exists ? (subDoc.data()?.stripe_customer_id ?? null) : null;

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

export const stripeWebhook = functions.https.onRequest(async (req, res) => {
  const stripe = getStripe();
  const webhookSecret =
    functions.config().stripe?.webhook_secret ?? process.env.STRIPE_WEBHOOK_SECRET ?? "";

  const sig = req.headers["stripe-signature"] as string;
  let event: Stripe.Event;

  try {
    event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
  } catch (err: unknown) {
    functions.logger.warn("Stripe webhook signature verification failed", err);
    res.status(400).send("Webhook signature verification failed");
    return;
  }

  functions.logger.info("Stripe webhook received", { type: event.type });

  try {
    switch (event.type) {
      case "payment_intent.succeeded": {
        const pi = event.data.object as Stripe.PaymentIntent;
        const uid = pi.metadata?.firebase_uid;
        const creditAmount = parseInt(pi.metadata?.credit_amount ?? "0", 10);
        if (uid && creditAmount > 0) {
          await db.collection("wallets").doc(uid).set(
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
          functions.logger.info("Credits added to wallet", { uid, creditAmount });
        }
        break;
      }

      case "customer.subscription.created":
      case "customer.subscription.updated": {
        const sub = event.data.object as Stripe.Subscription;
        const uid = sub.metadata?.firebase_uid;
        if (!uid) break;

        const planId = (sub.items.data[0]?.price?.metadata?.plan_id ?? sub.metadata?.plan_id ?? "free") as string;
        const status = sub.status;
        const currentPeriodEnd = new Date((sub as unknown as { current_period_end: number }).current_period_end * 1000);

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

        // Update custom claims if subscription is active
        if (status === "active") {
          await admin.auth().setCustomUserClaims(uid, {
            role: planId,
            is_admin: false,
          });
        }

        functions.logger.info("Subscription updated in Firestore", { uid, planId, status });
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

        functions.logger.info("Subscription canceled, downgraded to free", { uid });
        break;
      }

      default:
        functions.logger.info("Unhandled Stripe webhook event", { type: event.type });
    }
  } catch (err: unknown) {
    functions.logger.error("Error processing Stripe webhook", err);
    res.status(500).send("Internal error processing webhook");
    return;
  }

  res.json({ received: true });
});

// ---------------------------------------------------------------------------
// 5. deleteAccount — HTTPS Callable (Auth required)
// ---------------------------------------------------------------------------

export const deleteAccount = functions.https.onCall(async (_data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }

  const uid = context.auth.uid;
  const timestamp = Date.now();

  // Anonymise user document — keep record for aggregate stats
  await db.collection("users").doc(uid).update({
    displayName: null,
    firstName: null,
    lastName: null,
    avatar: null,
    linkedin_hash: `deleted_${timestamp}`,
    deleted: true,
    deleted_at: admin.firestore.FieldValue.serverTimestamp(),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Delete Firebase Auth user and revoke all tokens
  await admin.auth().revokeRefreshTokens(uid);
  await admin.auth().deleteUser(uid);

  functions.logger.info("Account deleted and anonymised", { uid });
  return { success: true };
});

// ---------------------------------------------------------------------------
// 6. computeInsights — Firestore trigger on checkin create
// ---------------------------------------------------------------------------

export const computeInsights = functions.firestore
  .document("checkins/{checkinId}")
  .onCreate(async (snap) => {
    const checkin = snap.data() as {
      userId: string;
      companyId?: string;
      department?: string;
      scores: Record<string, number>;
      created_at: admin.firestore.Timestamp;
    };

    const { userId, companyId, department, scores } = checkin;
    if (!userId) return;

    // Load thresholds (cached)
    const thresholds = (await cachedRead("platform_config/thresholds", async () => {
      const doc = await db.collection("platform_config").doc("thresholds").get();
      return doc.exists ? doc.data() : {};
    })) as Record<string, number>;

    const safeThresholds = applyThresholdFloors(thresholds);
    const companyMinN = safeThresholds.company_min_n;
    const deptMinN = safeThresholds.department_min_n;

    // Fetch all user check-ins for personal stats
    const userCheckinsSnap = await db
      .collection("checkins")
      .where("userId", "==", userId)
      .orderBy("created_at", "asc")
      .get();

    const userCheckins = userCheckinsSnap.docs.map((d) => d.data() as typeof checkin);
    const dimensions = Object.keys(scores);

    // Personal averages
    const personalAvg: Record<string, number> = {};
    for (const dim of dimensions) {
      const vals = userCheckins.map((c) => c.scores?.[dim] ?? null).filter((v): v is number => v !== null);
      const a = avg(vals);
      if (a !== null) personalAvg[dim] = a;
    }

    // OLS retention risk based on overall mood trend
    const moodTimeSeries = userCheckins.map((c) => {
      const dimVals = dimensions.map((d) => c.scores?.[d] ?? null).filter((v): v is number => v !== null);
      return avg(dimVals) ?? 0;
    });
    const trendSlope = olsSlope(moodTimeSeries);
    // Negative slope → rising risk; clamp [0, 1]
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
            .map((d) => (d.data() as typeof checkin).scores?.[dim] ?? null)
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
            .map((d) => (d.data() as typeof checkin).scores?.[dim] ?? null)
            .filter((v): v is number => v !== null);
          const a = avg(vals);
          if (a !== null) departmentAvg[dim] = a;
        }
      }
    }

    // Write insights
    await db.collection("insights").doc(userId).set(
      {
        userId,
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

    functions.logger.info("Insights computed", { userId, companyId, retentionRisk });
  });

// ---------------------------------------------------------------------------
// 7. getThresholds — HTTPS Callable (Auth required)
// ---------------------------------------------------------------------------

export const getThresholds = functions.https.onCall(async (_data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }

  const raw = (await cachedRead("platform_config/thresholds", async () => {
    const doc = await db.collection("platform_config").doc("thresholds").get();
    return doc.exists ? doc.data() : {};
  })) as Record<string, number>;

  return applyThresholdFloors(raw);
});

// ---------------------------------------------------------------------------
// 8. updateThresholds — HTTPS Callable (Admin only)
// ---------------------------------------------------------------------------

export const updateThresholds = functions.https.onCall(
  async (data: Record<string, number>, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }
    if (!context.auth.token.is_admin) {
      throw new functions.https.HttpsError("permission-denied", "Admin access required");
    }

    const safe = applyThresholdFloors(data);

    await db.collection("platform_config").doc("thresholds").set(safe, { merge: true });

    // Invalidate cache
    cache.delete("platform_config/thresholds");

    functions.logger.info("Thresholds updated by admin", { uid: context.auth.uid, safe });
    return safe;
  }
);

// ---------------------------------------------------------------------------
// 9. daasWidgetApi — HTTPS (API key auth, rate-limited)
// ---------------------------------------------------------------------------

export const daasWidgetApi = functions.https.onRequest(async (req, res) => {
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
  const keySnap = await db.collection("daas_api_keys").where("key", "==", apiKey).where("active", "==", true).limit(1).get();
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

  // Rate limiting: 100 requests per hour using Firestore counter
  const windowStart = new Date();
  windowStart.setMinutes(0, 0, 0); // start of current hour
  const windowKey = `${windowStart.toISOString()}`;

  const rateRef = db.collection("daas_rate_limits").doc(`${keyDoc.id}_${windowKey}`);
  const rateDoc = await rateRef.get();
  const currentCount: number = rateDoc.exists ? (rateDoc.data()?.count ?? 0) : 0;

  const rateLimit = keyData.rate_limit_hour ?? 100;
  if (currentCount >= rateLimit) {
    res.status(429).json({ error: "Rate limit exceeded. Maximum 100 requests per hour." });
    return;
  }

  // Increment counter (TTL 2 hours to auto-clean)
  await rateRef.set(
    {
      count: admin.firestore.FieldValue.increment(1),
      window: windowKey,
      expires_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 2 * 60 * 60 * 1000)),
    },
    { merge: true }
  );

  const companyId = keyData.companyId;

  // Load thresholds
  const thresholds = (await cachedRead("platform_config/thresholds", async () => {
    const doc = await db.collection("platform_config").doc("thresholds").get();
    return doc.exists ? doc.data() : {};
  })) as Record<string, number>;
  const safe = applyThresholdFloors(thresholds);
  const companyMinN = safe.company_min_n;

  // Fetch company check-ins
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

  // Aggregate scores
  type CheckinData = { scores: Record<string, number>; created_at: admin.firestore.Timestamp };
  const checkins = checkinsSnap.docs.map((d) => d.data() as CheckinData);
  const allDimensions = Object.keys(checkins[0]?.scores ?? {});

  const dimAvgs: Record<string, number> = {};
  for (const dim of allDimensions) {
    const vals = checkins.map((c) => c.scores?.[dim]).filter((v): v is number => typeof v === "number");
    const a = avg(vals);
    if (a !== null) dimAvgs[dim] = parseFloat(a.toFixed(2));
  }

  const overallWellbeing = avg(Object.values(dimAvgs));

  // Trend: compare last 30 vs previous 30 check-ins
  const recent = checkins.slice(0, Math.min(30, checkins.length));
  const older = checkins.slice(Math.min(30, checkins.length), Math.min(60, checkins.length));

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
    wellbeing_score: overallWellbeing !== null ? parseFloat(overallWellbeing.toFixed(2)) : null,
    dimensions: dimAvgs,
    trend,
  });
});

// ---------------------------------------------------------------------------
// 10. setAdminClaim — HTTPS Callable (Admin only)
// ---------------------------------------------------------------------------

export const setAdminClaim = functions.https.onCall(
  async (data: { targetUid: string }, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }
    if (!context.auth.token.is_admin) {
      throw new functions.https.HttpsError("permission-denied", "Admin access required");
    }

    const { targetUid } = data;
    if (!targetUid) {
      throw new functions.https.HttpsError("invalid-argument", "targetUid is required");
    }

    // Get existing claims to preserve other fields
    const targetUser = await admin.auth().getUser(targetUid);
    const existingClaims = (targetUser.customClaims ?? {}) as Record<string, unknown>;

    await admin.auth().setCustomUserClaims(targetUid, {
      ...existingClaims,
      is_admin: true,
      role: "admin",
    });

    functions.logger.info("Admin claim set", {
      by: context.auth.uid,
      for: targetUid,
    });

    return { success: true, targetUid };
  }
);
