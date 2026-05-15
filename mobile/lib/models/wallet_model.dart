import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { purchase, spend, refund, bonus }

class WalletTransactionModel {
  const WalletTransactionModel({
    required this.id,
    required this.uid,
    required this.type,
    required this.amount,
    required this.createdAt,
    this.description,
    this.stripePaymentIntentId,
  });

  final String id;
  final String uid;
  final TransactionType type;

  /// Positive = credits added, negative = credits spent
  final int amount;
  final DateTime createdAt;
  final String? description;
  final String? stripePaymentIntentId;

  factory WalletTransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalletTransactionModel(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      type: _parseType(data['type'] as String? ?? 'purchase'),
      amount: data['amount'] as int? ?? 0,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      description: data['description'] as String?,
      stripePaymentIntentId: data['stripePaymentIntentId'] as String?,
    );
  }

  static TransactionType _parseType(String raw) {
    switch (raw) {
      case 'spend':
        return TransactionType.spend;
      case 'refund':
        return TransactionType.refund;
      case 'bonus':
        return TransactionType.bonus;
      default:
        return TransactionType.purchase;
    }
  }

  String get typeLabel {
    switch (type) {
      case TransactionType.purchase:
        return 'Satın Alma';
      case TransactionType.spend:
        return 'Harcama';
      case TransactionType.refund:
        return 'İade';
      case TransactionType.bonus:
        return 'Bonus';
    }
  }

  bool get isCredit => amount > 0;
}

class WalletModel {
  const WalletModel({
    required this.uid,
    required this.balance,
    this.transactions = const [],
  });

  final String uid;
  final int balance;
  final List<WalletTransactionModel> transactions;

  WalletModel copyWith({
    String? uid,
    int? balance,
    List<WalletTransactionModel>? transactions,
  }) {
    return WalletModel(
      uid: uid ?? this.uid,
      balance: balance ?? this.balance,
      transactions: transactions ?? this.transactions,
    );
  }
}
