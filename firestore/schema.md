# PoM Firestore Schema (v1.0)

## Collection Hierarchy

```
users/{userId}
credit_transactions/{txnId}
banks/{bankId}
checkins/{checkinId}
aggregations/{aggId}              ← bank × family × year-month
sector_aggregations/{aggId}       ← industry-wide × family × year-month
query_sessions/{sessionId}        ← day-pass / bank-unlock grants
b2b_reports/{reportId}
```

---

## `users`

| Field             | Type      | Notes                                               |
|-------------------|-----------|-----------------------------------------------------|
| `linkedin_hash`   | string    | SHA-256(linkedin_id + SERVER_SALT). **No PII.**     |
| `bank_id`         | string    | ref → banks/{bankId}                                |
| `business_family` | string    | mapped by Cloud Function from LinkedIn title        |
| `department_type` | string    | `"HQ"` \| `"Branch"`                               |
| `seniority_level` | string    | `"exec"` \| `"senior"` \| `"mid"` \| `"junior"`    |
| `credits`         | number    | current balance (never negative)                    |
| `joined_at`       | timestamp |                                                     |
| `last_checkin_at` | timestamp | used to enforce 1 check-in / week                   |
| `checkin_streak`  | number    | consecutive weeks, for gamification                 |

---

## `credit_transactions`

| Field           | Type      | Notes                                                       |
|-----------------|-----------|-------------------------------------------------------------|
| `user_id`       | string    | ref → users/{userId}                                        |
| `type`          | string    | `signup_bonus` \| `weekly_checkin` \| `micropayment` \| `query_used` \| `day_pass` \| `bank_unlock` |
| `amount`        | number    | positive = credit earned; negative = credit spent           |
| `balance_after` | number    | snapshot for audit trail                                    |
| `metadata`      | map       | arbitrary context (bank_id, pass_duration, payment_ref …)  |
| `created_at`    | timestamp |                                                             |

---

## `banks`

| Field       | Type    | Notes                          |
|-------------|---------|--------------------------------|
| `name`      | string  |                                |
| `country`   | string  | ISO 3166-1 alpha-2             |
| `type`      | string  | `retail` \| `investment` \| `universal` |
| `is_active` | boolean | soft-delete                    |

---

## `checkins`

One document per weekly submission. The user's link to this document is
established only via `linkedin_hash` — no userId stored here.

| Field             | Type      | Notes                                             |
|-------------------|-----------|---------------------------------------------------|
| `user_hash`       | string    | SHA-256(linkedin_id + SERVER_SALT) — matches users.linkedin_hash |
| `bank_id`         | string    | ref → banks/{bankId}                              |
| `business_family` | string    |                                                   |
| `department_type` | string    | `"HQ"` \| `"Branch"`                             |
| `seniority_level` | string    |                                                   |
| `year`            | number    | e.g. 2026                                         |
| `month`           | number    | 1-12                                              |
| `week_number`     | number    | ISO week (1-53)                                   |
| `ratings`         | map       | `{salary, benefits, work_model, culture, wlb}` each 1-5 |
| `created_at`      | timestamp |                                                   |

---

## `aggregations`

Document ID format: `{bankId}_{businessFamily}_{year}_{month}`

Pre-computed at write time via Cloud Function. This is what the app queries
for bank-specific insights. The `entry_count` field is the enforcement
mechanism for the **N < 7 privacy rule**.

| Field             | Type      | Notes                                               |
|-------------------|-----------|-----------------------------------------------------|
| `bank_id`         | string    |                                                     |
| `business_family` | string    | `"all"` for bank-wide aggregate                     |
| `department_type` | string    | `"all"` \| `"HQ"` \| `"Branch"`                   |
| `year`            | number    |                                                     |
| `month`           | number    |                                                     |
| `entry_count`     | number    | **MUST be ≥ 7 before data is served**               |
| `averages`        | map       | `{salary, benefits, work_model, culture, wlb, overall}` |
| `updated_at`      | timestamp |                                                     |

---

## `sector_aggregations`

Document ID format: `{businessFamily}_{year}_{month}`

Industry-wide averages (no bank identifier — zero-knowledge baseline).

| Field             | Type      | Notes                                    |
|-------------------|-----------|------------------------------------------|
| `business_family` | string    |                                          |
| `year`            | number    |                                          |
| `month`           | number    |                                          |
| `entry_count`     | number    | applied to privacy threshold separately  |
| `averages`        | map       | same shape as aggregations.averages      |
| `updated_at`      | timestamp |                                          |

---

## `query_sessions`

Grants temporary access without spending per-query credits.

| Field        | Type            | Notes                            |
|--------------|-----------------|----------------------------------|
| `user_id`    | string          |                                  |
| `type`       | string          | `"day_pass"` \| `"bank_unlock"` |
| `bank_ids`   | array\<string\> | empty = all banks (day_pass)    |
| `expires_at` | timestamp       |                                  |
| `created_at` | timestamp       |                                  |

---

## `b2b_reports`

| Field        | Type      | Notes                                              |
|--------------|-----------|----------------------------------------------------|
| `bank_id`    | string    | the subscribing bank's ID                          |
| `type`       | string    | `"talent_retention"` \| `"competitor_benchmark"`   |
| `period`     | map       | `{year, month_from, month_to}`                     |
| `status`     | string    | `"generating"` \| `"ready"` \| `"expired"`         |
| `payload_url`| string    | signed GCS URL (short-lived)                       |
| `generated_at` | timestamp |                                                  |
| `expires_at` | timestamp |                                                    |

---

## Privacy Enforcement Summary

1. `aggregations.entry_count < 7` → Firestore rules **deny** reads.
2. Cloud Functions **re-check** entry_count before constructing API responses.
3. `checkins` collection is **never readable** by end-users (write-only from client, read only by Cloud Functions running with Admin SDK).
4. `users.linkedin_hash` is write-once; update blocked by security rules.
