import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';

class FirestoreService {
  FirestoreService(this._db, this._functions);
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  // -------------------------------------------------------------------------
  // User
  // -------------------------------------------------------------------------

  Stream<PomUser> userStream(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map(PomUser.fromFirestore);

  Future<void> completeProfile({
    required String uid,
    required String linkedinTitle,
    required String bankId,
  }) async {
    await _functions.httpsCallable('completeProfile').call({
      'linkedinTitle': linkedinTitle,
      'bankId': bankId,
    });
  }

  // -------------------------------------------------------------------------
  // Banks
  // -------------------------------------------------------------------------

  Future<List<Bank>> fetchBanks() async {
    final snap = await _db
        .collection('banks')
        .where('is_active', isEqualTo: true)
        .orderBy('name')
        .get();
    return snap.docs.map(Bank.fromFirestore).toList();
  }

  // -------------------------------------------------------------------------
  // Check-in
  // -------------------------------------------------------------------------

  Future<({int creditsAwarded, int newStreak})> submitCheckin(
      CheckinRatings ratings) async {
    final result = await _functions.httpsCallable('submitCheckin').call({
      'ratings': ratings.toMap(),
    });
    final data = result.data as Map<String, dynamic>;
    return (
      creditsAwarded: (data['creditsAwarded'] as num).toInt(),
      newStreak: (data['newStreak'] as num).toInt(),
    );
  }

  // -------------------------------------------------------------------------
  // Insights
  // -------------------------------------------------------------------------

  Future<InsightData?> queryInsights({
    required String bankId,
    String? businessFamily,
    required int year,
    required int month,
  }) async {
    final result = await _functions.httpsCallable('queryInsights').call({
      'bankId': bankId,
      'businessFamily': businessFamily,
      'year': year,
      'month': month,
    });
    final data = result.data as Map<String, dynamic>;
    if (data['available'] == false) return null;
    return InsightData.fromMap(data);
  }

  // -------------------------------------------------------------------------
  // Micro-payments
  // -------------------------------------------------------------------------

  Future<String> purchaseSession({
    required String sessionType,
    required List<String> bankIds,
    required String paymentRef,
  }) async {
    final result = await _functions.httpsCallable('purchaseSession').call({
      'sessionType': sessionType,
      'bankIds': bankIds,
      'paymentRef': paymentRef,
    });
    return (result.data as Map<String, dynamic>)['sessionId'] as String;
  }

  // -------------------------------------------------------------------------
  // Credit transactions (last 10 for history widget)
  // -------------------------------------------------------------------------

  Stream<List<Map<String, dynamic>>> creditHistoryStream(String uid) => _db
      .collection('credit_transactions')
      .where('user_id', isEqualTo: uid)
      .orderBy('created_at', descending: true)
      .limit(10)
      .snapshots()
      .map((s) => s.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList());
}

final firestoreProvider = Provider<FirebaseFirestore>(
  (_) => FirebaseFirestore.instance,
);

final functionsProvider = Provider<FirebaseFunctions>(
  (_) => FirebaseFunctions.instance,
);

final firestoreServiceProvider = Provider<FirestoreService>(
  (ref) => FirestoreService(
    ref.read(firestoreProvider),
    ref.read(functionsProvider),
  ),
);
