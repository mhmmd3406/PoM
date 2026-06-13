import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/firebase_providers.dart';

/// Metadata for one legal document. The [key] matches the field-prefix written
/// by the admin portal (LegalTextsPage) into `platform_config/legal_texts`:
/// `{key}_text`, `{key}_version`, `{key}_updated_at`.
class LegalTextMeta {
  const LegalTextMeta(this.key, this.label, {this.required = false});

  final String key;
  final String label;
  final bool required;
}

/// The five documents managed in the admin portal, in display order.
/// Keep this list in sync with `admin/src/pages/LegalTextsPage.tsx`.
const kLegalTexts = <LegalTextMeta>[
  LegalTextMeta('kvkk', 'KVKK Aydınlatma Metni', required: true),
  LegalTextMeta('privacy_policy', 'Gizlilik Politikası', required: true),
  LegalTextMeta('terms_of_service', 'Kullanım Şartları', required: true),
  LegalTextMeta('community_rules', 'Topluluk Kuralları'),
  LegalTextMeta('fraud_policy', 'Sahte Veri Politikası'),
];

LegalTextMeta? legalMetaForKey(String key) {
  for (final m in kLegalTexts) {
    if (m.key == key) return m;
  }
  return null;
}

/// The published content of a single legal document.
class LegalDoc {
  const LegalDoc({required this.text, this.version, this.updatedAt});

  final String text;
  final String? version;
  final DateTime? updatedAt;

  /// True when the admin hasn't published this document yet.
  bool get isUnpublished => text.trim().isEmpty;
}

/// Streams `platform_config/legal_texts` and unpacks it into a map keyed by the
/// document key (`kvkk`, `privacy_policy`, …). Any document the admin hasn't
/// written yet comes back as an empty [LegalDoc] (`isUnpublished == true`).
final legalTextsProvider = StreamProvider<Map<String, LegalDoc>>((ref) {
  final db = ref.watch(firestoreProvider);
  return db
      .collection('platform_config')
      .doc('legal_texts')
      .snapshots()
      .map((snap) {
    final data = snap.data() ?? const <String, dynamic>{};
    final out = <String, LegalDoc>{};
    for (final meta in kLegalTexts) {
      final ts = data['${meta.key}_updated_at'];
      out[meta.key] = LegalDoc(
        text: (data['${meta.key}_text'] as String?) ?? '',
        version: data['${meta.key}_version'] as String?,
        updatedAt: ts is Timestamp ? ts.toDate() : null,
      );
    }
    return out;
  });
});
