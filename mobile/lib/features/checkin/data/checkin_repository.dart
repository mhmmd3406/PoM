import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/checkin_model.dart';
import '../../../models/user_model.dart';

class CheckinRepository {
  CheckinRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// Submit a new check-in and update the user's lastCheckinAt.
  Future<CheckinModel> submitCheckin({
    required String uid,
    required int overallMood,
    required int workStress,
    required int teamHarmony,
    required int personalGrowth,
    required int workLifeBalance,
    String? companyId,
    String? department,
  }) async {
    final now = DateTime.now();
    final docId = '${uid}_${now.millisecondsSinceEpoch}';
    final checkin = CheckinModel(
      id: docId,
      uid: uid,
      overallMood: overallMood,
      workStress: workStress,
      teamHarmony: teamHarmony,
      personalGrowth: personalGrowth,
      workLifeBalance: workLifeBalance,
      createdAt: now,
      companyId: companyId,
      department: department,
    );

    final batch = _firestore.batch();

    // Write checkin doc
    batch.set(
      _firestore.collection(AppConstants.checkinsCollection).doc(docId),
      checkin.toFirestore(),
    );

    // Update user's lastCheckinAt
    batch.update(
      _firestore.collection(AppConstants.usersCollection).doc(uid),
      {'lastCheckinAt': Timestamp.fromDate(now)},
    );

    await batch.commit();
    return checkin;
  }

  /// Get the last check-in for a user.
  Future<CheckinModel?> getLastCheckin(String uid) async {
    final snap = await _firestore
        .collection(AppConstants.checkinsCollection)
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return CheckinModel.fromFirestore(snap.docs.first);
  }

  /// Check if the user is within the cooldown window.
  Future<bool> isWithinCooldown(String uid) async {
    final last = await getLastCheckin(uid);
    if (last == null) return false;

    final cooldownEnd = last.createdAt.add(
      const Duration(days: AppConstants.checkinCooldownDays),
    );
    return DateTime.now().isBefore(cooldownEnd);
  }

  /// Returns remaining cooldown duration (zero if not in cooldown).
  Future<Duration> remainingCooldown(String uid) async {
    final last = await getLastCheckin(uid);
    if (last == null) return Duration.zero;

    final cooldownEnd = last.createdAt.add(
      const Duration(days: AppConstants.checkinCooldownDays),
    );
    final remaining = cooldownEnd.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Stream the user's most recent check-ins (up to [limit]).
  Stream<List<CheckinModel>> watchCheckins(String uid, {int limit = 10}) {
    return _firestore
        .collection(AppConstants.checkinsCollection)
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map(CheckinModel.fromFirestore).toList());
  }
}

final checkinRepositoryProvider = Provider<CheckinRepository>((ref) {
  return CheckinRepository(firestore: ref.watch(firestoreProvider));
});
