using Google.Cloud.Firestore;
using Microsoft.AspNetCore.Mvc;
using PoM.B2B.Api.Models;
using Stripe;

namespace PoM.B2B.Api.Controllers;

/// <summary>
/// Handles Stripe subscription lifecycle webhooks for the B2B subscription tier.
///
/// Events:
///   invoice.paid                    → activate / renew subscription
///   customer.subscription.deleted   → downgrade to free
///   customer.subscription.updated   → plan upgrade / downgrade
///
/// The Cloud Function stripeSubscriptionWebhook handles the same events for
/// the consumer (Flutter) subscription flow. This controller is dedicated to
/// B2B customers whose Stripe customer IDs are stored with b2b_bank_id metadata.
///
/// After updating Firestore, the Cloud Function trigger onUserSubscriptionChanged
/// syncs the subscription_tier custom claim in Firebase Auth automatically.
/// </summary>
[ApiController]
[Route("api/stripe")]
public sealed class StripeWebhookController(IConfiguration config) : ControllerBase
{
    private const int PrivacyThreshold = 7;

    [HttpPost("webhook")]
    [Consumes("application/json")]
    public async Task<IActionResult> HandleWebhook(CancellationToken ct)
    {
        var webhookSecret = config["Stripe:WebhookSecret"]
            ?? throw new InvalidOperationException("Stripe:WebhookSecret not configured");
        StripeClient.Default = new StripeClient(config["Stripe:SecretKey"]);

        var json = await new StreamReader(Request.Body).ReadToEndAsync(ct);
        Event stripeEvent;
        try
        {
            stripeEvent = EventUtility.ConstructEvent(
                json,
                Request.Headers["Stripe-Signature"],
                webhookSecret);
        }
        catch (StripeException ex)
        {
            return BadRequest(new { error = ex.Message });
        }

        var projectId = config["Firebase:ProjectId"]!;
        var db = FirestoreDb.Create(projectId);

        try
        {
            switch (stripeEvent.Type)
            {
                case Events.InvoicePaid:
                {
                    var invoice = (Invoice)stripeEvent.Data.Object;
                    await HandleInvoicePaid(db, invoice, ct);
                    break;
                }
                case Events.CustomerSubscriptionDeleted:
                {
                    var sub = (Subscription)stripeEvent.Data.Object;
                    await HandleSubscriptionDeleted(db, sub, ct);
                    break;
                }
                case Events.CustomerSubscriptionUpdated:
                {
                    var sub = (Subscription)stripeEvent.Data.Object;
                    await HandleSubscriptionUpdated(db, sub, ct);
                    break;
                }
            }
        }
        catch (Exception ex)
        {
            // Log but return 200 — prevent Stripe retries for transient errors
            Console.Error.WriteLine($"[StripeWebhook] {stripeEvent.Type} error: {ex.Message}");
        }

        return Ok(new { received = true });
    }

    // ── Event handlers ────────────────────────────────────────────────────────

    private static async Task HandleInvoicePaid(FirestoreDb db, Invoice invoice, CancellationToken ct)
    {
        var customerId = invoice.CustomerId;
        var subId      = invoice.SubscriptionId;
        if (string.IsNullOrEmpty(customerId) || string.IsNullOrEmpty(subId)) return;

        var service = new SubscriptionService();
        var sub     = await service.GetAsync(subId, cancellationToken: ct);
        var tier    = TierFromSubscription(sub);

        await UpdateUserSubscription(db, customerId, new
        {
            subscription_tier     = tier,
            subscription_status   = "active",
            subscription_expires_at = Timestamp.FromDateTime(
                DateTimeOffset.FromUnixTimeSeconds(sub.CurrentPeriodEnd).UtcDateTime),
            stripe_subscription_id = subId,
        }, ct);
    }

    private static async Task HandleSubscriptionDeleted(FirestoreDb db, Subscription sub, CancellationToken ct)
    {
        await UpdateUserSubscription(db, sub.CustomerId, new
        {
            subscription_tier     = "free",
            subscription_status   = "cancelled",
            subscription_expires_at = (Timestamp?)null,
            stripe_subscription_id  = (string?)null,
        }, ct);
    }

    private static async Task HandleSubscriptionUpdated(FirestoreDb db, Subscription sub, CancellationToken ct)
    {
        var tier   = TierFromSubscription(sub);
        var status = sub.Status == "active" ? "active" : sub.Status;

        await UpdateUserSubscription(db, sub.CustomerId, new
        {
            subscription_tier     = tier,
            subscription_status   = status,
            subscription_expires_at = Timestamp.FromDateTime(
                DateTimeOffset.FromUnixTimeSeconds(sub.CurrentPeriodEnd).UtcDateTime),
            stripe_subscription_id = sub.Id,
        }, ct);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static string TierFromSubscription(Subscription sub)
    {
        var meta = sub.Items?.Data?.FirstOrDefault()?.Price?.Product?.Metadata;
        var raw  = meta != null && meta.TryGetValue("pom_tier", out var t) ? t : "standard";
        return SubscriptionTierExtensions.Parse(raw).ToString().ToLowerInvariant();
    }

    private static async Task UpdateUserSubscription(
        FirestoreDb db, string customerId, object update, CancellationToken ct)
    {
        // Find user by Stripe customer ID
        var snap = await db.Collection("users")
            .WhereEqualTo("stripe_customer_id", customerId)
            .Limit(1)
            .GetSnapshotAsync(ct);

        if (snap.Count == 0)
        {
            Console.Error.WriteLine($"[StripeWebhook] No user for customer {customerId}");
            return;
        }

        var userRef = snap.Documents[0].Reference;
        var dict    = update.GetType().GetProperties()
            .ToDictionary(p => p.Name, p => p.GetValue(update));

        dict["updated_at"] = FieldValue.ServerTimestamp;
        await userRef.UpdateAsync(dict, ct);
    }
}
