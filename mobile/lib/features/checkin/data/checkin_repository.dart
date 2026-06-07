import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/checkin_model.dart';

class CheckinRepository {
  CheckinRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// Submit a new check-in and update the user's lastCheckinAt.
  ///
  /// [uid] is used only to stamp lastCheckinAt on the caller's own user doc; the
  /// check-in itself carries only [userIdHash] (no raw uid), and uses a random
  /// Firestore auto-ID so the document name leaks nothing either.
  Future<CheckinModel> submitCheckin({
    required String uid,
    required String userIdHash,
    required int overallMood,
    required int workStress,
    required int teamHarmony,
    required int personalGrowth,
    required int workLifeBalance,
    String? companyId,
    String? department,
  }) async {
    final now = DateTime.now();
    final docRef =
        _firestore.collection(AppConstants.checkinsCollection).doc();
    final checkin = CheckinModel(
      id: docRef.id,
      userIdHash: userIdHash,
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

    // Write checkin doc (anonymous: auto-ID + userIdHash only).
    batch.set(docRef, checkin.toFirestore());

    // Update the caller's own lastCheckinAt (owner-writable, not anonymous data).
    batch.update(
      _firestore.collection(AppConstants.usersCollection).doc(uid),
      {'lastCheckinAt': Timestamp.fromDate(now)},
    );

    await batch.commit();
    return checkin;
  }

  /// Get the last check-in for a user (by pseudonymous hash).
  Future<CheckinModel?> getLastCheckin(String userIdHash) async {
    final snap = await _firestore
        .collection(AppConstants.checkinsCollection)
        .where('userIdHash', isEqualTo: userIdHash)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return CheckinModel.fromFirestore(snap.docs.first);
  }

  /// Check if the user is within the cooldown window.
  Future<bool> isWithinCooldown(String userIdHash) async {
    final last = await getLastCheckin(userIdHash);
    if (last == null) return false;

    final cooldownEnd = last.createdAt.add(
      const Duration(days: AppConstants.checkinCooldownDays),
    );
    return DateTime.now().isBefore(cooldownEnd);
  }

  /// Returns remaining cooldown duration (zero if not in cooldown).
  Future<Duration> remainingCooldown(String userIdHash) async {
    final last = await getLastCheckin(userIdHash);
    if (last == null) return Duration.zero;

    final cooldownEnd = last.createdAt.add(
      const Duration(days: AppConstants.checkinCooldownDays),
    );
    final remaining = cooldownEnd.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Stream the user's most recent check-ins (up to [limit]).
  Stream<List<CheckinModel>> watchCheckins(String userIdHash, {int limit = 10}) {
    return _firestore
        .collection(AppConstants.checkinsCollection)
        .where('userIdHash', isEqualTo: userIdHash)
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
