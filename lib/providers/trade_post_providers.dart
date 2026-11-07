import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/goods.dart';
import '../models/oshi.dart';
import '../models/trade_chat.dart';
import '../models/trade_message.dart';
import '../models/trade_post.dart';
import '../models/trade_reply.dart';
import '../repositories/trade_chat_repository.dart';
import '../repositories/trade_post_repository.dart';
import '../repositories/trade_reply_repository.dart';
import '../utils/trade_board.dart';
import '../utils/trade_match.dart';
import 'goods_providers.dart';
import 'oshi_providers.dart';
import 'profile_providers.dart';

/// 交換・売買の投稿のリポジトリ。テストでは `overrideWithValue` で差し替える
final tradePostRepositoryProvider = Provider<TradePostRepository>(
  (ref) => FirestoreTradePostRepository(FirebaseFirestore.instance),
);

/// ログイン中のユーザーの投稿（更新日時の新しい順。募集終了・非表示も含む）。
/// 未ログインなら空
final myTradePostsProvider = StreamProvider<List<TradePost>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(tradePostRepositoryProvider).watchMine(uid);
}, retry: firestoreRetry);

/// ID で取得した投稿（詳細・編集画面で使う）。見つからなければ null。
/// 保存したら `ref.invalidate` で読み直す
final tradePostByIdProvider = FutureProvider.family<TradePost?, String>(
  (ref, id) => ref.watch(tradePostRepositoryProvider).fetch(id),
  retry: firestoreRetry,
);

/// 掲示板で最初に読む件数と、「もっと見る」で増やす件数
const int boardPageSize = 50;

/// 推しの募集中の投稿（更新日時の新しい順・最大 limit 件）。
/// 掲示板は [tradeBoardProvider] を使う。未ログインなら空。
/// 推しや件数を変えたら古い購読が残らないよう、autoDispose にする
final openTradePostsProvider = StreamProvider.autoDispose
    .family<List<TradePost>, ({OshiKind kind, String id, int limit})>((ref, q) {
      if (ref.watch(currentUidProvider) == null) return Stream.value(const []);
      return ref
          .watch(tradePostRepositoryProvider)
          .watchOpenFor(q.kind, q.id, limit: q.limit);
    }, retry: firestoreRetry);

/// 掲示板で選んでいる推し。未選択なら null
class BoardTargetNotifier extends Notifier<OshiSummary?> {
  @override
  OshiSummary? build() => null;

  void select(OshiSummary? oshi) => state = oshi;
}

final boardTargetProvider = NotifierProvider<BoardTargetNotifier, OshiSummary?>(
  BoardTargetNotifier.new,
);

/// 掲示板の絞り込みの条件。掲示板の推しを変えたら、条件なしに戻る
class BoardFilterNotifier extends Notifier<BoardFilter> {
  @override
  BoardFilter build() {
    ref.watch(boardTargetProvider);
    return BoardFilter.none;
  }

  void set(BoardFilter filter) => state = filter;
}

final boardFilterProvider = NotifierProvider<BoardFilterNotifier, BoardFilter>(
  BoardFilterNotifier.new,
);

/// 推しの掲示板（募集中の投稿を更新日時の新しい順に limit 件）。
///
/// 個人の推しなら、所属グループを対象にした投稿もまとめて出す。
/// 検索は推しごとに分けて行い、[mergeBoardPosts] でまとめる。
/// どれかがエラーならエラー、どれかが読み込み中なら読み込み中
final tradeBoardProvider = Provider.autoDispose
    .family<AsyncValue<TradeBoard>, ({OshiKind kind, String id, int limit})>((
      ref,
      q,
    ) {
      final targets = <(OshiKind, String)>[(q.kind, q.id)];
      if (q.kind == OshiKind.person) {
        final all = ref.watch(allOshisProvider).value ?? const <OshiSummary>[];
        final self = all
            .where((o) => o.kind == OshiKind.person && o.id == q.id)
            .firstOrNull;
        for (final g in self?.groupIds ?? const <String>[]) {
          targets.add((OshiKind.group, g));
        }
      }
      final values = [
        for (final (kind, id) in targets)
          ref.watch(
            openTradePostsProvider((kind: kind, id: id, limit: q.limit)),
          ),
      ];
      for (final v in values) {
        if (v case AsyncError(:final error, :final stackTrace)) {
          return AsyncError(error, stackTrace);
        }
      }
      if (values.any((v) => !v.hasValue)) return const AsyncLoading();
      return AsyncData(
        mergeBoardPosts([for (final v in values) v.requireValue], q.limit),
      );
    });

/// ホームの「新しい交換」：フォロー中の推し（最大10件）の募集中の投稿を、
/// 推しごとに5件ずつ読んでまとめ、自分の投稿を除いて新しい順に6件
final homeTradePostsProvider =
    Provider.autoDispose<AsyncValue<List<TradePost>>>((ref) {
  final following = ref.watch(followingOshisProvider);
  final uid = ref.watch(currentUidProvider);
  if (following case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  final oshis = following.value;
  if (oshis == null) return const AsyncLoading();
  if (oshis.isEmpty) return const AsyncData([]);

  final values = [
    for (final o in oshis.take(10))
      ref.watch(openTradePostsProvider((kind: o.kind, id: o.id, limit: 5))),
  ];
  for (final v in values) {
    if (v case AsyncError(:final error, :final stackTrace)) {
      return AsyncError(error, stackTrace);
    }
  }
  if (values.any((v) => !v.hasValue)) return const AsyncLoading();

  // まとめる件数は多めに取り、自分の投稿を除いてから6件にする
  final merged =
      mergeBoardPosts([for (final v in values) v.requireValue], 50).posts;
  return AsyncData([
    for (final p in merged)
      if (p.uid != uid) p,
  ].take(6).toList());
});

/// 自分の募集中の投稿の求の検索用キー（重複なし・並べ替え済み）。
/// 中身が変わったときだけ、[matchCandidatesProvider] を読み直させる
final myOpenWantKeysProvider = FutureProvider<List<String>>((ref) async {
  // selectAsync は == で比べるので、文字列にして比べる（投稿の更新日時が
  // 変わっただけでは読み直さない）
  final joined = await ref.watch(
    myTradePostsProvider.selectAsync(
      (posts) => ({
        for (final p in posts)
          if (p.status == TradePostStatus.open) ...p.wantKeys,
      }.toList()..sort()).join('\n'),
    ),
  );
  return joined.isEmpty ? const [] : joined.split('\n');
});

/// マッチの候補：自分の求のどれかを譲に含む、他人の募集中の投稿（順序は不定）。
/// 自分の募集中の投稿に求がなければ空。判定は [matchTradePosts] で行う
final matchCandidatesProvider = FutureProvider<List<TradePost>>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const [];
  final keys = await ref.watch(myOpenWantKeysProvider.future);
  if (keys.isEmpty) return const [];
  final posts = await ref
      .watch(tradePostRepositoryProvider)
      .fetchOpenGiving(keys);
  return [
    for (final p in posts)
      if (p.uid != uid) p,
  ];
}, retry: firestoreRetry);

/// マッチ（相互マッチ → 片方マッチの順。[matchTradePosts] で判定）。
///
/// 判定は検索用キーだけで決まるので、先に判定してから、マッチした投稿の
/// 品目のグッズだけを読む（一致した品目の表示に使う。同じグッズは
/// [goodsByIdProvider] が覚えているので、読み直さない）
final tradeMatchesProvider = FutureProvider<List<TradeMatch>>((ref) async {
  final candidates = await ref.watch(matchCandidatesProvider.future);
  if (candidates.isEmpty) return const [];
  final mine = await ref.watch(myTradePostsProvider.future);

  final judged = matchTradePosts(
    mine: mine,
    candidates: candidates,
    goodsById: const {},
  );
  if (judged.isEmpty) return const [];
  final ids = goodsIdsForMatching(
    [
      for (final m in judged)
        for (final p in m.pairs) p.mine,
    ],
    [for (final m in judged) m.theirs],
  );
  // グッズが読めなくても、マッチ自体は出す（一致した品目の表示が減るだけ）
  Future<Goods?> read(String id) async {
    try {
      return await ref.watch(goodsByIdProvider(id).future);
    } catch (_) {
      return null;
    }
  }

  final goods = await Future.wait([for (final id in ids) read(id)]);
  return matchTradePosts(
    mine: mine,
    candidates: [for (final m in judged) m.theirs],
    goodsById: {
      for (final g in goods)
        if (g?.id != null) g!.id!: g,
    },
  );
}, retry: firestoreRetry);

/// 返信のリポジトリ。テストでは `overrideWithValue` で差し替える
final tradeReplyRepositoryProvider = Provider<TradeReplyRepository>(
  (ref) => FirestoreTradeReplyRepository(FirebaseFirestore.instance),
);

/// 投稿の返信（書いた順）。詳細画面を閉じたら購読をやめる
final tradeRepliesProvider = StreamProvider.autoDispose
    .family<List<TradeReply>, String>(
      (ref, postId) =>
          ref.watch(tradeReplyRepositoryProvider).watchReplies(postId),
      retry: firestoreRetry,
    );

/// チャットのリポジトリ（返信の承認もここで行う）。
/// テストでは `overrideWithValue` で差し替える
final tradeChatRepositoryProvider = Provider<TradeChatRepository>(
  (ref) => FirestoreTradeChatRepository(FirebaseFirestore.instance),
);

/// 自分が参加しているチャット（最後のメッセージの新しい順）。未ログインなら空
final myChatsProvider = StreamProvider<List<TradeChat>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(tradeChatRepositoryProvider).watchMyChats(uid);
}, retry: firestoreRetry);

/// チャット1件（チャット画面で使う）。画面を閉じたら購読をやめる
final tradeChatProvider = StreamProvider.autoDispose.family<TradeChat?, String>(
  (ref, chatId) => ref.watch(tradeChatRepositoryProvider).watchChat(chatId),
  retry: firestoreRetry,
);

/// チャットのメッセージ（送った順）。画面を閉じたら購読をやめる
final tradeMessagesProvider = StreamProvider.autoDispose
    .family<List<TradeMessage>, String>(
      (ref, chatId) =>
          ref.watch(tradeChatRepositoryProvider).watchMessages(chatId),
      retry: firestoreRetry,
    );

/// 未読のメッセージがあるチャットの数（交換トップのボタンに出す）
final unreadChatCountProvider = Provider<int>((ref) {
  final uid = ref.watch(currentUidProvider);
  final chats = ref.watch(myChatsProvider).value ?? const <TradeChat>[];
  if (uid == null) return 0;
  return chats.where((c) => c.isUnreadFor(uid)).length;
});

/// ログイン中のユーザーの表示名。投稿・返信・チャットに保存し、画面にも出す。
///
/// 表示名を決める処理はここだけにまとめる（仕様書 3.9）。プロフィールの
/// ハンドルネームを使い、読み込み前などで取れないときは「匿名」とする
/// （セキュリティルールで1文字以上が必須のため、空欄にはしない）
final myDisplayNameProvider = Provider<String>((ref) {
  final name = ref.watch(myProfileProvider).value?.displayName.trim() ?? '';
  return name.isEmpty ? '匿名' : name;
});