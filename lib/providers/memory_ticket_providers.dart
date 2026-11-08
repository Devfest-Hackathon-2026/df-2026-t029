import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/common/photo_items.dart';
import '../models/live_memory.dart';
import '../models/oshi.dart';
import '../repositories/live_repository.dart';
import '../repositories/memory_repository.dart';
import '../repositories/photo_repository.dart';
import '../repositories/public_memory_repository.dart';
import '../utils/share_ticket.dart';
import 'live_providers.dart';
import 'memory_providers.dart';
import 'oshi_providers.dart';
import 'photo_providers.dart';
import 'profile_providers.dart';
import 'public_memory_providers.dart';

/// 保存した結果
class MemorySaveResult {
  const MemorySaveResult(this.memory, {required this.publicSynced});

  /// 保存したあとの記録
  final LiveMemory memory;

  /// 公開の写しを書けたか（公開していなければ true）
  final bool publicSynced;
}

String? _nullIfBlank(String? text) {
  final t = text?.trim() ?? '';
  return t.isEmpty ? null : t;
}

/// 記録の保存の窓口。画面は `MemoryRepository` などを直接呼ばず、これを通す。
/// 保存の順と失敗の扱いは `memory_form_page.dart` の `_save` と同じ
class MemoryEditor {
  MemoryEditor({
    required this.uid,
    required MemoryRepository memories,
    required PhotoRepository photos,
    required PublicMemoryRepository publics,
    required LiveRepository lives,
    required Future<String> Function() displayName,
  }) : _memoryRepo = memories,
       _photoRepo = photos,
       _publicRepo = publics,
       _liveRepo = lives,
       _nameLoader = displayName;

  /// ログイン中の uid（未ログインなら null。保存は StateError になる）
  final String? uid;
  final MemoryRepository _memoryRepo;
  final PhotoRepository _photoRepo;
  final PublicMemoryRepository _publicRepo;
  final LiveRepository _liveRepo;
  final Future<String> Function() _nameLoader;

  String _requireUid() {
    final id = uid;
    if (id == null) throw StateError('ログインしていません');
    return id;
  }

  /// 座席・セトリ・感想を保存する（前後の空白を除き、空なら項目を消す）。
  /// 公開中なら、公開の写しも書き直す。記録の保存に失敗したら例外
  Future<MemorySaveResult> saveFields(
    LiveMemory memory, {
    String? seat,
    required List<String> setlist,
    String? impression,
  }) async {
    final id = _requireUid();
    final next = memory.copyWithContent(
      seat: _nullIfBlank(seat),
      setlist: [
        for (final s in setlist)
          if (s.trim().isNotEmpty) s.trim(),
      ],
      impression: _nullIfBlank(impression),
      images: memory.images,
    );
    await _memoryRepo.update(id, next);
    final synced = await _syncPublic(id, next);
    return MemorySaveResult(next, publicSynced: synced);
  }

  /// 写真の並びを保存する。順は「新しい写真をアップロード → 記録を保存 →
  /// 公開の写し → 外した写真を消す」。失敗の扱いも `_save` と同じ:
  /// 上げた分は消す・写しを書けなかったら外した写真は消さない
  Future<MemorySaveResult> savePhotos(
    LiveMemory memory,
    List<PhotoItem> items,
  ) async {
    final id = _requireUid();
    // 失敗したときは uploadNewPhotos が上げた分を消して例外を投げ直す
    final uploaded = await uploadNewPhotos(
      _photoRepo,
      'users/$id/memories/${memory.performanceId}',
      items,
    );
    final images = photoPathsOf(items, uploaded);
    final next = memory.copyWithContent(
      seat: memory.seat,
      setlist: memory.setlist,
      impression: memory.impression,
      images: images,
    );
    try {
      await _memoryRepo.update(id, next);
    } catch (_) {
      await _photoRepo.deleteAll(uploaded.values);
      rethrow;
    }
    final synced = await _syncPublic(id, next);
    if (synced) {
      await _photoRepo.deleteAll(
        memory.images.where((p) => !images.contains(p)),
      );
    }
    return MemorySaveResult(next, publicSynced: synced);
  }

  /// 公開・座席の公開を保存し、公開の写しを書く・消す
  Future<MemorySaveResult> setPublic(
    LiveMemory memory, {
    required bool isPublic,
    required bool publicSeat,
  }) async {
    final id = _requireUid();
    final next = memory.copyWithContent(
      seat: memory.seat,
      setlist: memory.setlist,
      impression: memory.impression,
      images: memory.images,
      isPublic: isPublic,
      publicSeat: publicSeat,
    );
    await _memoryRepo.update(id, next);
    final synced = await _syncPublic(id, next);
    return MemorySaveResult(next, publicSynced: synced);
  }

  /// postedAt を書く。すでにあれば何もしない。失敗しても例外を投げない
  Future<void> markPosted(LiveMemory memory) async {
    if (memory.postedAt != null) return;
    final id = uid;
    if (id == null) return;
    try {
      await _memoryRepo.markPosted(id, memory.performanceId);
    } catch (_) {
      // 投稿の操作は止めない
    }
  }

  /// 公開の写しを書く・消す（add_K 5.1）。成功したら true。
  /// 公開しないときは、念のため写しを消しておく（無くてもエラーにならない）
  Future<bool> _syncPublic(String uid, LiveMemory memory) async {
    try {
      if (!memory.isPublic) {
        await _publicRepo.unpublish(uid, memory.performanceId);
        return true;
      }
      // 推しで探せるように、ライブの出演者を写す。読めなければ空で書く
      var groupIds = const <String>[];
      var oshiIds = const <String>[];
      try {
        final live = await _liveRepo.watchLive(memory.liveId).first;
        if (live != null) {
          groupIds = live.groupIds;
          oshiIds = live.oshiIds;
        }
      } catch (_) {
        // 出演者なしで公開する
      }
      final name = (await _nameLoader()).trim();
      await _publicRepo.publish(
        memory,
        uid: uid,
        displayName: name.isEmpty ? '匿名' : name,
        groupIds: groupIds,
        oshiIds: oshiIds,
      );
      return true;
    } catch (e) {
      debugPrint('公開の写しの保存に失敗');
      return false;
    }
  }
}

final memoryEditorProvider = Provider<MemoryEditor>(
  (ref) => MemoryEditor(
    uid: ref.watch(currentUidProvider),
    memories: ref.watch(memoryRepositoryProvider),
    photos: ref.watch(photoRepositoryProvider),
    publics: ref.watch(publicMemoryRepositoryProvider),
    lives: ref.watch(liveRepositoryProvider),
    displayName: () async {
      final profile = await ref.read(myProfileProvider.future);
      return profile?.displayName ?? '';
    },
  ),
);

/// 画面用: 記録 + 出演者名（allOshisProvider から引く）+ 写真の数 → [ShareContent]。
/// 記録が無ければ null。読み込み中・エラーは記録の状態のまま。
/// 出演者名は読めた分だけ（読み込み中・エラーのときは空）
final shareContentProvider = Provider.autoDispose
    .family<AsyncValue<ShareContent?>, String>((ref, performanceId) {
      final memory = ref.watch(memoryProvider(performanceId));
      final m = memory.value;
      if (m == null) {
        return memory.whenData((_) => null);
      }
      final live = ref.watch(liveProvider(m.liveId)).value;
      final all = ref.watch(allOshisProvider).value ?? const [];
      String? nameOf(OshiKind kind, String id) {
        for (final o in all) {
          if (o.kind == kind && o.id == id) return o.name;
        }
        return null;
      }

      final names = <String>[
        for (final id in live?.groupIds ?? const <String>[])
          ?nameOf(OshiKind.group, id),
        for (final id in live?.oshiIds ?? const <String>[])
          ?nameOf(OshiKind.person, id),
      ];
      return AsyncData(
        ShareContent.fromMemory(
          m,
          artist: names.isEmpty ? null : names.first,
          performerNames: names,
        ),
      );
    });
