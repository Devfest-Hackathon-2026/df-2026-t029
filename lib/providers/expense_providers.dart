import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/expense.dart';
import '../repositories/expense_repository.dart';
import '../utils/expense_summary.dart';
import 'live_providers.dart';
import 'oshi_providers.dart';
import 'trip_providers.dart';

/// 費用管理のリポジトリ
final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => FirestoreExpenseRepository(FirebaseFirestore.instance),
);

/// 手入力の出費。未ログインなら空
final myExpensesProvider = StreamProvider<List<Expense>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(expenseRepositoryProvider).watchExpenses(uid);
}, retry: firestoreRetry);

/// チケット代の設定（receptionId → 設定）。未ログインなら空
final myTicketCostsProvider = StreamProvider<Map<String, TicketCost>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const {});
  return ref.watch(expenseRepositoryProvider).watchTicketCosts(uid);
}, retry: firestoreRetry);

/// 1か月の予算（円）。未設定・未ログインなら null
final myBudgetProvider = StreamProvider<int?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(expenseRepositoryProvider).watchBudget(uid);
}, retry: firestoreRetry);

/// 出費の全件（チケット・遠征・手入力。仕様書 4.1）。
/// どれかがエラーならエラー、どれかが読み込み中なら読み込み中
final expenseItemsProvider = Provider<AsyncValue<List<ExpenseItem>>>((ref) {
  final receptions = ref.watch(myReceptionsProvider);
  final applications = ref.watch(applicationsProvider);
  final lives = ref.watch(myLivesProvider);
  final ticketCosts = ref.watch(myTicketCostsProvider);
  final trips = ref.watch(myTripsProvider);
  final expenses = ref.watch(myExpensesProvider);
  final all = <AsyncValue<Object?>>[
    receptions,
    applications,
    lives,
    ticketCosts,
    trips,
    expenses,
  ];
  for (final s in all) {
    if (s case AsyncError(:final error, :final stackTrace)) {
      return AsyncError(error, stackTrace);
    }
  }
  if (all.any((s) => !s.hasValue)) return const AsyncLoading();
  return AsyncData(
    buildExpenseItems(
      receptions: receptions.value!,
      applications: applications.value!,
      lives: lives.value!,
      ticketCosts: ticketCosts.value!,
      trips: trips.value!,
      expenses: expenses.value!,
    ),
  );
});
