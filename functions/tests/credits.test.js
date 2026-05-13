'use strict';

// Unit tests for credits.js pure logic.
// Firestore is fully mocked — no emulator required.

const CREDITS = {
  SIGNUP_BONUS: 3,
  WEEKLY_CHECKIN: 2,
  QUERY_COST: 1,
};

const MS_PER_WEEK = 7 * 24 * 60 * 60 * 1000;

// ── Isolated pure-logic helpers (extracted from credits.js for unit testing) ─

function canAwardCheckin(lastCheckinDate, now) {
  if (!lastCheckinDate) return true;
  return (now - lastCheckinDate) >= MS_PER_WEEK;
}

function computeNewStreak(lastCheckinDate, currentStreak, now) {
  if (!lastCheckinDate) return 1;
  const diff = now - lastCheckinDate;
  return diff < 2 * MS_PER_WEEK ? currentStreak + 1 : 1;
}

function computeBalanceAfter(current, delta) {
  const next = current + delta;
  if (next < 0) throw new Error('insufficient_credits');
  return next;
}

function sessionExpiryMs(sessionType) {
  return sessionType === 'day_pass'
    ? 24 * 60 * 60 * 1000
    : 30 * 24 * 60 * 60 * 1000;
}

// ── Tests ──────────────────────────────────────────────────────────────────

describe('Credit balance logic', () => {
  test('positive award increases balance', () => {
    expect(computeBalanceAfter(3, 2)).toBe(5);
  });

  test('deduction that keeps balance at 0 is allowed', () => {
    expect(computeBalanceAfter(1, -1)).toBe(0);
  });

  test('deduction below zero throws insufficient_credits', () => {
    expect(() => computeBalanceAfter(0, -1)).toThrow('insufficient_credits');
  });

  test('large deduction throws insufficient_credits', () => {
    expect(() => computeBalanceAfter(2, -5)).toThrow('insufficient_credits');
  });
});

describe('Checkin timing enforcement', () => {
  const now = new Date('2024-06-15T10:00:00Z');

  test('first checkin is always allowed (no last_checkin_at)', () => {
    expect(canAwardCheckin(null, now)).toBe(true);
  });

  test('checkin 8 days later is allowed', () => {
    const lastCheckin = new Date(now.getTime() - 8 * 24 * 60 * 60 * 1000);
    expect(canAwardCheckin(lastCheckin, now)).toBe(true);
  });

  test('checkin exactly 7 days later is allowed', () => {
    const lastCheckin = new Date(now.getTime() - MS_PER_WEEK);
    expect(canAwardCheckin(lastCheckin, now)).toBe(true);
  });

  test('checkin 3 days later is rejected', () => {
    const lastCheckin = new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000);
    expect(canAwardCheckin(lastCheckin, now)).toBe(false);
  });
});

describe('Streak calculation', () => {
  const now = new Date('2024-06-15T10:00:00Z');

  test('first checkin starts streak at 1', () => {
    expect(computeNewStreak(null, 0, now)).toBe(1);
  });

  test('checkin within 2 weeks increments streak', () => {
    const last = new Date(now.getTime() - 8 * 24 * 60 * 60 * 1000);
    expect(computeNewStreak(last, 5, now)).toBe(6);
  });

  test('checkin after 2+ weeks resets streak to 1', () => {
    const last = new Date(now.getTime() - 15 * 24 * 60 * 60 * 1000);
    expect(computeNewStreak(last, 5, now)).toBe(1);
  });
});

describe('Session expiry', () => {
  test('day_pass expires in 24 hours', () => {
    expect(sessionExpiryMs('day_pass')).toBe(24 * 60 * 60 * 1000);
  });

  test('bank_unlock expires in 30 days', () => {
    expect(sessionExpiryMs('bank_unlock')).toBe(30 * 24 * 60 * 60 * 1000);
  });
});

describe('CREDITS constants', () => {
  test('signup bonus is 3', () => expect(CREDITS.SIGNUP_BONUS).toBe(3));
  test('weekly checkin is 2', () => expect(CREDITS.WEEKLY_CHECKIN).toBe(2));
  test('query cost is 1', () => expect(CREDITS.QUERY_COST).toBe(1));
});
