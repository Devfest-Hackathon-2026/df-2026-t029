import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/expense.dart';

/// 費用管理の個人データ（H-1）。
/// - 手入力の出費：`users/{uid}/expenses/{id}`
/// - チケット代の設定：`users/{uid}/ticketCosts/{receptionId}`
/// - 予算：`users/{uid}/settings/budget`
abstract class ExpenseRepository {
  /// 手入力の出費（順序は不定）
  Stream<List<Expense>> watchExpenses(String uid);

  /// 手入力の出費を作る。作成日時・更新日時はサーバー時刻
  Future<void> addExpense(String uid, Expense expense);

  /// 手入力の出費を書き換える（[Expense.id] が必要）。更新日時はサーバー時刻
  Future<void> updateExpense(String uid, Expense expense);

  Future<void> deleteExpense(String uid, String id);

  /// receptionId → チケット代の設定
  Stream<Map<String, TicketCost>> watchTicketCosts(String uid);

  Future<void> saveTicketCost(String uid, TicketCost cost);

  /// チケット代の設定を消す（受付の最初の席種 × 1枚に戻る）
  Future<void> deleteTicketCost(String uid, String receptionId);

  /// 1か月の予算（円）。未設定なら null
  Stream<int?> watchBudget(String uid);

  /// 予算を保存する。null なら消す
  Future<void> saveBudget(String uid, int? monthly);
}

/// Firestore 版の [ExpenseRepository]
class FirestoreExpenseRepository implements ExpenseRepository {
  FirestoreExpenseRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _expenses(String uid) =>
      _user(uid).collection('expenses');

  CollectionReference<Map<String, dynamic>> _ticketCosts(String uid) =>
      _user(uid).collection('ticketCosts');

  DocumentReference<Map<String, dynamic>> _budget(String uid) =>
      _user(uid).collection('settings').doc('budget');

  @override
  Stream<List<Expense>> watchExpenses(String uid) => _expenses(uid)
      .snapshots()
      .map((snap) => [for (final doc in snap.docs) Expense.fromFirestore(doc)]);

  @override
  Future<void> addExpense(String uid, Expense expense) =>
      _expenses(uid).add({
        ...expense.toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> updateExpense(String uid, Expense expense) =>
      // 丸ごと書き換えて、空にした項目（ライブ）を消す（作成日時は引き継ぐ）
      _expenses(uid).doc(expense.id).set({
        ...expense.toFirestore(),
        'createdAt': expense.createdAt != null
            ? Timestamp.fromDate(expense.createdAt!)
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> deleteExpense(String uid, String id) =>
      _expenses(uid).doc(id).delete();

  @override
  Stream<Map<String, TicketCost>> watchTicketCosts(String uid) =>
      _ticketCosts(uid).snapshots().map(
        (snap) => {
          for (final doc in snap.docs) doc.id: TicketCost.fromFirestore(doc),
        },
      );

  @override
  Future<void> saveTicketCost(String uid, TicketCost cost) =>
      _ticketCosts(uid).doc(cost.receptionId).set({
        ...cost.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> deleteTicketCost(String uid, String receptionId) =>
      _ticketCosts(uid).doc(receptionId).delete();

  @override
  Stream<int?> watchBudget(String uid) => _budget(
    uid,
  ).snapshots().map((doc) => (doc.data()?['monthly'] as num?)?.toInt());

  @override
  Future<void> saveBudget(String uid, int? monthly) => monthly == null
      ? _budget(uid).delete()
      : _budget(uid).set({
          'monthly': monthly,
          'updatedAt': FieldValue.serverTimestamp(),
        });
}