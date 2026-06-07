/**
 * Pure threshold helpers — no firebase-admin import, so they are trivially
 * unit-testable (see ../test/thresholds.test.cjs) and safe to import anywhere.
 */

/**
 * Apply the privacy safety floors to a set of thresholds.
 *
 * The floors are hard-locked at company=15 / department=10 — the platform's
 * legal anonymity guarantee. An admin may raise a threshold (more conservative,
 * fewer cohorts shown) but may NEVER lower it below these values, so a small
 * cohort can never be de-anonymised by re-identification. Keep this in lock-step
 * with the .NET FirestoreService floor (api/Services/FirestoreService.cs).
 */
export const COMPANY_MIN_N_FLOOR = 15;
export const DEPARTMENT_MIN_N_FLOOR = 10;

export function applyThresholdFloors(
  raw: Record<string, number>
): Record<string, number> {
  return {
    ...raw,
    company_min_n: Math.max(raw.company_min_n ?? COMPANY_MIN_N_FLOOR, COMPANY_MIN_N_FLOOR),
    department_min_n: Math.max(
      raw.department_min_n ?? DEPARTMENT_MIN_N_FLOOR,
      DEPARTMENT_MIN_N_FLOOR
    ),
  };
}

/**
 * Keep only finite numeric fields from untrusted callable input. This prevents
 * `undefined` / `NaN` / strings / metadata objects from reaching Firestore,
 * which would reject the write and surface to the client as an opaque
 * "internal" error (the F-ADM5 symptom).
 */
export function sanitizeThresholdInput(data: unknown): Record<string, number> {
  const out: Record<string, number> = {};
  if (data && typeof data === "object") {
    for (const [key, value] of Object.entries(
      data as Record<string, unknown>
    )) {
      if (typeof value === "number" && Number.isFinite(value)) {
        out[key] = value;
      }
    }
  }
  return out;
}
