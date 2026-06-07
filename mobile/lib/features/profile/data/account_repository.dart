import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';

/// Recursively converts Firestore values into JSON-encodable ones so an export
/// can be `jsonEncode`d (Firestore `Timestamp`/`DateTime` → ISO-8601 string,
/// `GeoPoint` → `{lat,lng}`, nested maps/lists handled). Pure + unit-tested.
Object? jsonSafe(Object? value) {
  if (value is Timestamp) return value.toDate().toIso8601String();
  if (value is DateTime) return value.toIso8601String();
  if (value is GeoPoint) {
    return {'lat': value.latitude, 'lng': value.longitude};
  }
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), jsonSafe(v)));
  }
  if (value is Iterable) return value.map(jsonSafe).toList();
  return value;
}

/// Account-level KVKK/GDPR actions: account deletion (right to erasure) and
/// personal-data export (data portability).
class AccountRepository {
  AccountRepository({
    required FirebaseFunctions functions,
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _functions = functions,
        _firestore = firestore,
        _auth = auth;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Right to erasure: the `deleteAccount` Cloud Function anonymises the user
  /// document and deletes the Firebase Auth user. We then sign out locally so
  /// the router returns to the login screen.
  Future<void> deleteAccount() async {
    await _functions.httpsCallable('deleteAccount').call<dynamic>();
    await _auth.signOut();
  }

  /// Data portability: gathers the signed-in user's own data (profile +
  /// their check-ins) into a JSON-encodable map. Only owner-readable data is
  /// touched, so no elevated permissions are required.
  Future<Map<String, dynamic>> exportMyData(String uid) async {
    final userSnap = await _firestore.collection('users').doc(uid).get();
    final checkinSnap = await _firestore
        .collection('checkins')
        .where('uid', isEqualTo: uid)
        .get();

    return {
      'exportedAt': DateTime.now().toIso8601String(),
      'userId': uid,
      'profile': jsonSafe(userSnap.data() ?? <String, dynamic>{}),
      'checkins': checkinSnap.docs.map((d) => jsonSafe(d.data())).toList(),
    };
  }
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(
    functions: ref.watch(cloudFunctionsProvider),
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});
