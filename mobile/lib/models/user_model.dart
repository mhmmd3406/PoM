import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  const UserModel({
    required this.uid,
    required this.linkedinHash,
    this.userIdHash = '',
    this.displayName,
    this.avatarUrl,
    this.role = 'free',
    this.isAdmin = false,
    this.kvkkAccepted = false,
    this.kvkkVersion,
    this.kvkkAcceptedAt,
    this.creditBalance = 0,
    this.companyId,
    this.department,
    this.email,
    this.createdAt,
    this.lastCheckinAt,
    this.answeredSurveyIds = const [],
    this.surveyAnswers = const {},
  });

  final String uid;
  final String linkedinHash;

  /// Pseudonymous, server-derived identifier (HMAC-salted hash of the uid).
  /// Used to read this user's anonymous check-ins / insights without exposing
  /// the raw uid. Written by the linkedinAuth Cloud Function; empty in debug.
  final String userIdHash;

  final String? displayName;
  final String? avatarUrl;

  /// 'free' | 'pro' | 'enterprise' | 'daas'
  final String role;
  final bool isAdmin;
  final bool kvkkAccepted;
  final String? kvkkVersion;
  final DateTime? kvkkAcceptedAt;
  final int creditBalance;
  final String? companyId;
  final String? department;
  final String? email;
  final DateTime? createdAt;
  final DateTime? lastCheckinAt;

  /// Survey IDs this user has already answered. Tracked on the user document
  /// (owner-readable) so the app never needs to read `survey_responses`, which
  /// firestore.rules restrict to admins / company members.
  final List<String> answeredSurveyIds;

  /// This user's OWN survey answers, keyed by surveyId → (questionId → answer).
  /// Persisted on the owner-readable user doc at submit time so the personal
  /// result view can be re-rendered later without reading `survey_responses`
  /// (which firestore.rules block for non-admins/non-members).
  final Map<String, Map<String, dynamic>> surveyAnswers;

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      linkedinHash: data['linkedinHash'] as String? ?? '',
      userIdHash: data['userIdHash'] as String? ?? '',
      displayName: data['displayName'] as String?,
      avatarUrl: data['avatarUrl'] as String?,
      role: data['role'] as String? ?? 'free',
      isAdmin: data['isAdmin'] as bool? ?? false,
      kvkkAccepted: data['kvkkAccepted'] as bool? ?? false,
      kvkkVersion: data['kvkkVersion'] as String?,
      kvkkAcceptedAt: data['kvkkAcceptedAt'] != null
          ? (data['kvkkAcceptedAt'] as Timestamp).toDate()
          : null,
      creditBalance: data['creditBalance'] as int? ?? 0,
      companyId: data['companyId'] as String?,
      department: data['department'] as String?,
      email: data['email'] as String?,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      lastCheckinAt: data['lastCheckinAt'] != null
          ? (data['lastCheckinAt'] as Timestamp).toDate()
          : null,
      answeredSurveyIds:
          (data['answeredSurveyIds'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              const [],
      surveyAnswers: (data['surveyAnswers'] as Map<String, dynamic>?)?.map(
            (surveyId, answers) => MapEntry(
              surveyId,
              Map<String, dynamic>.from(answers as Map),
            ),
          ) ??
          const {},
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'linkedinHash': linkedinHash,
      if (userIdHash.isNotEmpty) 'userIdHash': userIdHash,
      if (displayName != null) 'displayName': displayName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'role': role,
      'isAdmin': isAdmin,
      'kvkkAccepted': kvkkAccepted,
      if (kvkkVersion != null) 'kvkkVersion': kvkkVersion,
      if (kvkkAcceptedAt != null)
        'kvkkAcceptedAt': Timestamp.fromDate(kvkkAcceptedAt!),
      'creditBalance': creditBalance,
      if (companyId != null) 'companyId': companyId,
      if (department != null) 'department': department,
      if (email != null) 'email': email,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (lastCheckinAt != null)
        'lastCheckinAt': Timestamp.fromDate(lastCheckinAt!),
    };
  }

  UserModel copyWith({
    String? uid,
    String? linkedinHash,
    String? userIdHash,
    String? displayName,
    String? avatarUrl,
    String? role,
    bool? isAdmin,
    bool? kvkkAccepted,
    String? kvkkVersion,
    DateTime? kvkkAcceptedAt,
    int? creditBalance,
    String? companyId,
    String? department,
    String? email,
    DateTime? createdAt,
    DateTime? lastCheckinAt,
    List<String>? answeredSurveyIds,
    Map<String, Map<String, dynamic>>? surveyAnswers,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      linkedinHash: linkedinHash ?? this.linkedinHash,
      userIdHash: userIdHash ?? this.userIdHash,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      isAdmin: isAdmin ?? this.isAdmin,
      kvkkAccepted: kvkkAccepted ?? this.kvkkAccepted,
      kvkkVersion: kvkkVersion ?? this.kvkkVersion,
      kvkkAcceptedAt: kvkkAcceptedAt ?? this.kvkkAcceptedAt,
      creditBalance: creditBalance ?? this.creditBalance,
      companyId: companyId ?? this.companyId,
      department: department ?? this.department,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      lastCheckinAt: lastCheckinAt ?? this.lastCheckinAt,
      answeredSurveyIds: answeredSurveyIds ?? this.answeredSurveyIds,
      surveyAnswers: surveyAnswers ?? this.surveyAnswers,
    );
  }

  bool get isPro => role == 'pro' || role == 'enterprise' || role == 'daas';
  bool get isEnterprise => role == 'enterprise' || role == 'daas';
  bool get isDaas => role == 'daas';
}
