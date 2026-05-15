import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Threshold model ───────────────────────────────────────────────────────────

class PlatformThresholds {
  final int companyThreshold;
  final int departmentThreshold;
  final int minEmployees;
  final int checkinCooldownDays;

  const PlatformThresholds({
    this.companyThreshold    = 15,
    this.departmentThreshold = 10,
    this.minEmployees        = 200,
    this.checkinCooldownDays = 7,
  });

  factory PlatformThresholds.fromDoc(Map<String, dynamic> d) {
    int safeInt(String k, int def) {
      final v = d[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return def;
    }
    return PlatformThresholds(
      companyThreshold:    safeInt('company_privacy_threshold',    15).clamp(7, 999),
      departmentThreshold: safeInt('department_privacy_threshold', 10).clamp(5, 999),
      minEmployees:        safeInt('min_company_employees',        200).clamp(0, 999999),
      checkinCooldownDays: safeInt('checkin_cooldown_days',        7).clamp(1, 365),
    );
  }
}

// ── Legal text model ──────────────────────────────────────────────────────────

class LegalTexts {
  final String kvkkVersion;
  final String kvkkText;
  final String privacyPolicyVersion;
  final String privacyPolicyText;
  final String termsVersion;
  final String termsText;

  const LegalTexts({
    this.kvkkVersion           = '',
    this.kvkkText              = '',
    this.privacyPolicyVersion  = '',
    this.privacyPolicyText     = '',
    this.termsVersion          = '',
    this.termsText             = '',
  });

  factory LegalTexts.fromDoc(Map<String, dynamic> d) {
    String s(String k) => (d[k] as String?) ?? '';
    return LegalTexts(
      kvkkVersion:          s('kvkk_version'),
      kvkkText:             s('kvkk_text'),
      privacyPolicyVersion: s('privacy_policy_version'),
      privacyPolicyText:    s('privacy_policy_text'),
      termsVersion:         s('terms_of_service_version'),
      termsText:            s('terms_of_service_text'),
    );
  }
}

// ── Feature flags model ───────────────────────────────────────────────────────

class FeatureFlags {
  final bool maintenanceMode;
  final String maintenanceMessage;

  const FeatureFlags({
    this.maintenanceMode    = false,
    this.maintenanceMessage = '',
  });

  factory FeatureFlags.fromDoc(Map<String, dynamic> d) {
    return FeatureFlags(
      maintenanceMode:    (d['maintenance_mode'] as bool?) ?? false,
      maintenanceMessage: (d['maintenance_message'] as String?) ?? '',
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final _firestore = FirebaseFirestore.instance;

final thresholdsProvider = StreamProvider<PlatformThresholds>((ref) {
  return _firestore
      .doc('platform_config/thresholds')
      .snapshots()
      .map((s) => s.exists
          ? PlatformThresholds.fromDoc(s.data()!)
          : const PlatformThresholds());
});

final legalTextsProvider = StreamProvider<LegalTexts>((ref) {
  return _firestore
      .doc('platform_config/legal_texts')
      .snapshots()
      .map((s) => s.exists
          ? LegalTexts.fromDoc(s.data()!)
          : const LegalTexts());
});

final featureFlagsProvider = StreamProvider<FeatureFlags>((ref) {
  return _firestore
      .doc('platform_config/feature_flags')
      .snapshots()
      .map((s) => s.exists
          ? FeatureFlags.fromDoc(s.data()!)
          : const FeatureFlags());
});
