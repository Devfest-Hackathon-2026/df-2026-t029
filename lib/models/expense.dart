import 'package:cloud_firestore/cloud_firestore.dart';

import 'converters.dart';

/// 出費の種類。Firestore には [code] を保存する
enum ExpenseCategory {
  ticket('ticket', 'チケット'),
  travel('travel', '遠征'),
  goods('goods', 'グッズ'),
  other('other', 'その他');

  const ExpenseCategory(this.code, this.label);

  final String code;
  final String label;

  /// 手入力で選べる種類（チケットは受付から自動で出すので選ばせない）
  static const manual = [goods, travel, other];

  /// 不明な値・欠けている値は [other]
  static ExpenseCategory fromCode(Object? code) {
    for (final c in values) {
      if (c.code == code) return c;
    }
    return other;
  }
}

/// 手入力の出費（`users/{uid}/expenses/{id}`。H-1）
class Expense {
  const Expense({
    this.id,
    required this.category,
    required this.title,
    required this.amount,
    required this.date,
    this.liveId,
    this.liveTitle,
    this.createdAt,
  });

  static const int maxTitleLength = 50;
  static const int maxAmount = 1000000;

  /// 保存前は null
  final String? id;
  final ExpenseCategory category;
  final String title;

  /// 金額（円）
  final int amount;

  /// 日付（日だけ使う）
  final DateTime date;

  /// 関係するライブ（任意）
  final String? liveId;
  final String? liveTitle;

  final DateTime? createdAt;

  factory Expense.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Expense(
      id: doc.id,
      category: ExpenseCategory.fromCode(data['category']),
      title: data['title'] as String? ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      date: toDateTime(data['date']) ?? DateTime(1970),
      liveId: data['liveId'] as String?,
      liveTitle: data['liveTitle'] as String?,
      createdAt: toDateTime(data['createdAt']),
    );
  }

  /// 保存用の Map。作成日時・更新日時はリポジトリが付ける
  Map<String, dynamic> toFirestore() => {
    'category': category.code,
    'title': title,
    'amount': amount,
    'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
    if (liveId != null) 'liveId': liveId,
    if (liveTitle != null) 'liveTitle': liveTitle,
  };
}

/// チケット代の設定（`users/{uid}/ticketCosts/{receptionId}`。H-1）
class TicketCost {
  const TicketCost({
    required this.receptionId,
    required this.seat,
    required this.unitPrice,
    required this.count,
  });

  static const int maxCount = 8;

  final String receptionId;

  /// 席種（受付の料金の席種名）
  final String seat;

  /// 1枚の料金（円）
  final int unitPrice;

  /// 枚数
  final int count;

  int get amount => unitPrice * count;

  factory TicketCost.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TicketCost(
      receptionId: doc.id,
      seat: data['seat'] as String? ?? '',
      unitPrice: (data['unitPrice'] as num?)?.toInt() ?? 0,
      count: (data['count'] as num?)?.toInt() ?? 1,
    );
  }

  /// 保存用の Map。更新日時はリポジトリが付ける
  Map<String, dynamic> toFirestore() => {
    'seat': seat,
    'unitPrice': unitPrice,
    'count': count,
  };
}