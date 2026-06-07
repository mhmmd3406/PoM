const test = require("node:test");
const assert = require("node:assert/strict");
const {
  applyThresholdFloors,
  sanitizeThresholdInput,
} = require("../lib/thresholds.js");

test("applyThresholdFloors enforces the privacy safety floors", () => {
  const out = applyThresholdFloors({ company_min_n: 3, department_min_n: 2 });
  assert.equal(out.company_min_n, 15);
  assert.equal(out.department_min_n, 10);
});

test("applyThresholdFloors keeps above-floor values and defaults missing", () => {
  const out = applyThresholdFloors({ company_min_n: 50 });
  assert.equal(out.company_min_n, 50);
  assert.equal(out.department_min_n, 10);
});

test("sanitizeThresholdInput keeps only finite numbers", () => {
  const out = sanitizeThresholdInput({
    company_min_n: 20,
    department_min_n: NaN, // dropped
    bad: "12", // dropped (string)
    missing: undefined, // dropped
    infinite: Infinity, // dropped
    extra: 8, // kept
  });
  assert.deepEqual(out, { company_min_n: 20, extra: 8 });
});

test("sanitizeThresholdInput tolerates null / non-objects", () => {
  assert.deepEqual(sanitizeThresholdInput(null), {});
  assert.deepEqual(sanitizeThresholdInput(undefined), {});
  assert.deepEqual(sanitizeThresholdInput(42), {});
});

test("update pipeline drops junk/metadata and protects the floor", () => {
  // Simulates request.data carrying junk + a below-floor value.
  const result = applyThresholdFloors(
    sanitizeThresholdInput({
      company_min_n: 1,
      department_min_n: 2,
      _updated_at: { _seconds: 1 }, // metadata object → dropped
      note: "x", // string → dropped
    })
  );
  assert.equal(result.company_min_n, 15);
  assert.equal(result.department_min_n, 10);
  assert.equal(result._updated_at, undefined);
  assert.equal(result.note, undefined);
});
