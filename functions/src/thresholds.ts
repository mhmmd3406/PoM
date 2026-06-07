/**
 * Pure threshold helpers — no firebase-admin import, so they are trivially
 * unit-testable (see ../test/thresholds.test.cjs) and safe to import anywhere.
 */

/** Apply the privacy safety floors to a set of thresholds. */
export function applyThresholdFloors(
  raw: Record<string, number>
): Record<string, number> {
  return {
    ...raw,
    company_min_n: Math.max(raw.company_min_n ?? 15, 7),
    department_min_n: Math.max(raw.department_min_n ?? 10, 5),
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
