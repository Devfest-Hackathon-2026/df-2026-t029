import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/common/photo_items.dart';
import '../services/google_photos_service.dart';
import '../services/photo_pick_ai.dart';
import '../utils/google_photos_errors.dart';
import '../utils/memory_ticket.dart';
import '../utils/photo_picker.dart';

enum PhotoPickStage {
  idle,
  authorizing,
  waitingPicker,
  fetching,
  analyzing,
  done,
  failed,
}

/// 候補の写真1枚（縮小版だけを持つ。保存しない）
class PickCandidate {
  const PickCandidate({
    required this.item,
    required this.thumb,
    this.judgement,
  });

  final PickedItem item;
  final Uint8List thumb;
  final PhotoJudgement? judgement;
}

/// 選ぶ流れを始めるときに渡す、ライブの情報（Gemini に送る）
class PhotoPickRequestInfo {
  const PhotoPickRequestInfo({
    required this.title,
    required this.startAt,
    required this.venue,
    this.artist,
  });

  final String title;
  final DateTime startAt;
  final String venue;
  final String? artist;
}

class PhotoPickState {
  const PhotoPickState({
    this.stage = PhotoPickStage.idle,
    this.session,
    this.candidates = const [],
    this.selected = const [],
    this.aiFailed = false,
    this.error,
  });

  final PhotoPickStage stage;

  /// waitingPicker のとき
  final PickerSession? session;

  /// done のとき
  final List<PickCandidate> candidates;

  /// 選んだ候補の番号（表紙が先頭）。上限は「8枚から既存の枚数を引いた数」
  final List<int> selected;

  /// Gemini が失敗した（全部「ほかの候補」）
  final bool aiFailed;

  /// 4.11 の文言（googlePhotosErrorMessage の結果）
  final String? error;

  /// authorizing・waitingPicker・fetching・analyzing のとき true
  bool get busy =>
      stage == PhotoPickStage.authorizing ||
      stage == PhotoPickStage.waitingPicker ||
      stage == PhotoPickStage.fetching ||
      stage == PhotoPickStage.analyzing;

  PhotoPickState copyWith({
    PhotoPickStage? stage,
    PickerSession? session,
    bool clearSession = false,
    List<PickCandidate>? candidates,
    List<int>? selected,
    bool? aiFailed,
    String? error,
    bool clearError = false,
  }) => PhotoPickState(
    stage: stage ?? this.stage,
    session: clearSession ? null : (session ?? this.session),
    candidates: candidates ?? this.candidates,
    selected: selected ?? this.selected,
    aiFailed: aiFailed ?? this.aiFailed,
    error: clearError ? null : (error ?? this.error),
  );
}

/// 時刻（タイムアウトの判定用）。テストで差し替える
final photoPickClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

const _thumbFailedMessage = '写真を取り込めませんでした。もう一度お試しください。';

/// 縮小版・大きい写真を同時に取る数
const _fetchConcurrency = 4;

/// 中身から画像の形式を判定する。分からなければ null
String? _sniffImageType(Uint8List b) {
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (b.length >= 4 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4E &&
      b[3] == 0x47) {
    return 'image/png';
  }
  if (b.length >= 4 &&
      b[0] == 0x47 &&
      b[1] == 0x49 &&
      b[2] == 0x46 &&
      b[3] == 0x38) {
    return 'image/gif';
  }
  if (b.length >= 12 &&
      b[0] == 0x52 &&
      b[1] == 0x49 &&
      b[2] == 0x46 &&
      b[3] == 0x46 &&
      b[8] == 0x57 &&
      b[9] == 0x45 &&
      b[10] == 0x42 &&
      b[11] == 0x50) {
    return 'image/webp';
  }
  return null;
}

const _extensionOf = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/gif': 'gif',
};

/// [tasks] を、同時に [_fetchConcurrency] 個まで実行する。結果は同じ順
Future<List<T?>> _mapLimited<S, T>(
  List<S> inputs,
  Future<T?> Function(S) task,
) async {
  final results = List<T?>.filled(inputs.length, null);
  var next = 0;
  Future<void> worker() async {
    while (true) {
      final i = next++;
      if (i >= inputs.length) return;
      results[i] = await task(inputs[i]);
    }
  }

  await Future.wait([
    for (var k = 0; k < min(_fetchConcurrency, inputs.length); k++) worker(),
  ]);
  return results;
}

/// Google フォトで写真を選び、Gemini で選んでもらう流れの状態機械。
/// トークン・baseUrl・写真は、ログ・例外・画面に出さない
class PhotoPickNotifier extends Notifier<PhotoPickState> {
  // 古い処理に state を書かせないための世代番号
  int _gen = 0;
  // ポーリングを始めた世代（同じ世代で二重に始めないため）
  int _pollingGen = -1;
  int _remainingSlots = maxPhotosPerItem;
  PhotoPickRequestInfo? _info;
  String? _sessionId;
  late GooglePhotosApi _api;

  @override
  PhotoPickState build() {
    _api = ref.read(googlePhotosApiProvider);
    ref.onDispose(() {
      _gen++;
      _deleteSession();
    });
    return const PhotoPickState();
  }

  bool _alive(int gen) => ref.mounted && gen == _gen;

  void _deleteSession() {
    final id = _sessionId;
    _sessionId = null;
    if (id != null) unawaited(_api.deleteSession(id));
  }

  void _fail(Object error) {
    _deleteSession();
    state = PhotoPickState(
      stage: PhotoPickStage.failed,
      error: googlePhotosErrorMessage(error),
    );
  }

  /// **つなぐボタンの処理の最初に呼ぶ**（ポップアップ。同意は ui が先に取る）。
  /// authorize → createSession → waitingPicker。busy のときは何もしない
  Future<void> begin({
    required PhotoPickRequestInfo info,
    required int remainingSlots,
  }) async {
    if (state.busy) return;
    final gen = ++_gen;
    _info = info;
    _remainingSlots = max(0, remainingSlots);
    _deleteSession();
    state = const PhotoPickState(stage: PhotoPickStage.authorizing);
    try {
      // await の前に呼ぶ（ブラウザにポップアップを止められないため）
      await _api.authorize();
      if (!_alive(gen)) return;
      final session = await _api.createSession(maxItemCount: maxPickCandidates);
      if (!_alive(gen)) {
        unawaited(_api.deleteSession(session.id));
        return;
      }
      _sessionId = session.id;
      state = PhotoPickState(
        stage: PhotoPickStage.waitingPicker,
        session: session,
      );
    } catch (e) {
      if (!_alive(gen)) return;
      _fail(e);
    }
  }

  /// waitingPicker のあと: ポーリング → 一覧 → 縮小版 → Gemini → done。
  /// ui が「Googleフォトを開く」を押して pickerUri を開いた直後に呼ぶ
  Future<void> waitForSelection() async {
    var session = state.session;
    if (state.stage != PhotoPickStage.waitingPicker || session == null) return;
    final gen = _gen;
    if (_pollingGen == gen) return; // すでに選び終わるのを待っている
    final info = _info;
    if (info == null) return;
    _pollingGen = gen;
    final clock = ref.read(photoPickClockProvider);
    try {
      // 選び終わるまで待つ
      while (!session!.mediaItemsSet) {
        if (!clock().isBefore(session.timeoutAt)) {
          throw const GooglePhotosException(GooglePhotosFailure.timeout);
        }
        await Future<void>.delayed(session.pollInterval);
        if (!_alive(gen)) return;
        if (!clock().isBefore(session.timeoutAt)) {
          throw const GooglePhotosException(GooglePhotosFailure.timeout);
        }
        session = await _api.getSession(session.id);
        if (!_alive(gen)) return;
      }

      state = state.copyWith(
        stage: PhotoPickStage.fetching,
        clearSession: true,
      );
      final items = await _api.listPickedItems(session.id);
      if (!_alive(gen)) return;
      if (items.isEmpty) {
        throw const GooglePhotosException(GooglePhotosFailure.noneSelected);
      }

      // 縮小版を取る（取れなかった写真は飛ばす）
      final thumbs = await _mapLimited<PickedItem, Uint8List>(items, (
        item,
      ) async {
        try {
          return await _api.fetchImage(item, maxSide: pickThumbSide);
        } catch (_) {
          return null;
        }
      });
      if (!_alive(gen)) return;
      final got = <PickCandidate>[
        for (var i = 0; i < items.length; i++)
          if (thumbs[i] != null)
            PickCandidate(item: items[i], thumb: thumbs[i]!),
      ];
      if (got.isEmpty) {
        state = PhotoPickState(
          stage: PhotoPickStage.failed,
          error: _thumbFailedMessage,
        );
        _deleteSession();
        return;
      }

      // Gemini に選んでもらう（失敗したら全部「ほかの候補」）
      state = state.copyWith(stage: PhotoPickStage.analyzing);
      var aiFailed = false;
      List<PhotoJudgement> judgements = const [];
      try {
        judgements = await ref
            .read(photoPickAiProvider)
            .choose(
              PhotoPickRequest(
                title: info.title,
                startAt: info.startAt,
                venue: info.venue,
                artist: info.artist,
                candidates: [
                  for (final c in got)
                    PhotoPickCandidate(
                      c.thumb,
                      _sniffImageType(c.thumb) ?? c.item.mimeType,
                      createTime: c.item.createTime,
                    ),
                ],
              ),
            );
      } catch (_) {
        aiFailed = true;
      }
      if (!_alive(gen)) return;

      final candidates = <PickCandidate>[];
      for (var i = 0; i < got.length; i++) {
        PhotoJudgement? j;
        if (!aiFailed) {
          for (final x in judgements) {
            if (x.index == i) {
              j = x;
              break;
            }
          }
        }
        candidates.add(
          PickCandidate(item: got[i].item, thumb: got[i].thumb, judgement: j),
        );
      }
      // 既定の選択: pick を rank の小さい順（無ければ番号順）に
      final picks =
          [
            for (var i = 0; i < candidates.length; i++)
              if (candidates[i].judgement?.decision == PhotoDecision.pick) i,
          ]..sort((a, b) {
            final ra = candidates[a].judgement?.rank ?? 1 << 30;
            final rb = candidates[b].judgement?.rank ?? 1 << 30;
            return ra != rb ? ra.compareTo(rb) : a.compareTo(b);
          });
      state = PhotoPickState(
        stage: PhotoPickStage.done,
        candidates: candidates,
        selected: picks.take(_remainingSlots).toList(),
        aiFailed: aiFailed,
      );
    } catch (e) {
      if (!_alive(gen)) return;
      _fail(e);
    }
  }

  /// やめる／シートを閉じる。ポーリングを止め、セッションを消し、idle に戻す。
  /// 世代番号で、古い処理の結果は捨てる
  void cancel() {
    _gen++;
    _deleteSession();
    if (ref.mounted) state = const PhotoPickState();
  }

  /// 選ぶ／外す。選べる上限を超える選択は無視する
  void toggle(int candidateIndex) {
    if (state.stage != PhotoPickStage.done) return;
    if (candidateIndex < 0 || candidateIndex >= state.candidates.length) return;
    final selected = [...state.selected];
    if (!selected.remove(candidateIndex)) {
      if (selected.length >= _remainingSlots) return;
      selected.add(candidateIndex);
    }
    state = state.copyWith(selected: selected);
  }

  /// 「決定」: 選んだ候補の大きい写真（長辺 [photoMaxSide]）を取り、[NewPhoto] にして返す。
  /// 取れなかったら例外（ui が 4.11 の文言を出す）。5MB を超えたら再圧縮はせず例外
  Future<List<NewPhoto>> materializeSelected() async {
    final items = [
      for (final i in state.selected)
        if (i >= 0 && i < state.candidates.length) state.candidates[i].item,
    ];
    final side = photoMaxSide.toInt();
    final bytes = await _mapLimited<PickedItem, Uint8List>(items, (item) async {
      try {
        return await _api.fetchImage(item, maxSide: side);
      } catch (_) {
        return null;
      }
    });
    final out = <NewPhoto>[];
    for (var i = 0; i < items.length; i++) {
      final b = bytes[i];
      if (b == null || b.length >= maxPhotoBytes) {
        throw StateError('写真を取り込めませんでした');
      }
      final type = _sniffImageType(b) ?? items[i].mimeType;
      final ext = _extensionOf[type];
      if (ext == null) throw StateError('写真を取り込めませんでした');
      out.add(
        NewPhoto(PickedPhoto(bytes: b, contentType: type, extension: ext)),
      );
    }
    // セッションはもう要らない（大きい写真を取り終えた）
    _deleteSession();
    return out;
  }
}

final photoPickProvider =
    NotifierProvider.autoDispose<PhotoPickNotifier, PhotoPickState>(
      PhotoPickNotifier.new,
    );

/// 同意のダイアログを、このタブで出したか（保存しない。4.4.2）
class ConsentNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markConsented() => state = true;
}

final googlePhotosConsentedProvider = NotifierProvider<ConsentNotifier, bool>(
  ConsentNotifier.new,
);
