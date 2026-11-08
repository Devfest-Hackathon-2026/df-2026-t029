// Google フォト・Gemini の写真えらびの偽物（Q2 以降で共有）。
// 本物の Google・Gemini・ネットワークは呼ばない。トークン・URL は架空の値。
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:oshiashi/services/google_photos_service.dart';
import 'package:oshiashi/services/photo_pick_ai.dart';

/// 先頭が JPEG の印のバイト列（形式の判定に通る）
Uint8List fakeJpeg([int extra = 0]) =>
    Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(extra, 7)]);

/// 1x1 の本物の PNG（画面のテストで Image.memory が読める画像）
final Uint8List validPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// 架空の候補1枚
PickedItem fakeItem(String id, {DateTime? createTime}) => PickedItem(
  id: id,
  baseUrl: 'https://img.example.com/$id',
  mimeType: 'image/jpeg',
  createTime: createTime,
);

/// 偽の [GooglePhotosApi]。呼ばれた順を [calls] に残す
class FakeGooglePhotosApi implements GooglePhotosApi {
  FakeGooglePhotosApi({
    this.items = const [],
    this.pollInterval = const Duration(milliseconds: 1),
    this.timeoutIn = const Duration(minutes: 30),
    this.pollsBeforeSet = 0,
    required this.clock,
  });

  /// session.timeoutAt の計算に使う時刻（photoPickClockProvider と同じ関数を渡す）
  final DateTime Function() clock;

  List<PickedItem> items;
  Duration pollInterval;
  Duration timeoutIn;

  /// getSession を何回呼ぶと mediaItemsSet が true になるか。null なら永遠に false
  int? pollsBeforeSet;

  /// 設定すると、その呼び出しで投げる
  Object? authorizeError;
  Object? createError;
  Object? listError;

  /// 設定すると、その呼び出しが終わるまで待つ
  Completer<void>? authorizeGate;
  Completer<void>? listGate;

  /// 取れない写真の ID（縮小版・大きい写真）
  final Set<String> failThumbIds = {};
  final Set<String> failLargeIds = {};

  /// 設定すると、縮小版・大きい写真のどちらもこのバイト列を返す（画面のテスト用）
  Uint8List? imageBytes;

  /// 大きい写真（maxSide が 768 より大きい）のバイト列。無ければ [fakeJpeg]
  Uint8List Function(PickedItem item)? largeBytes;

  final List<String> calls = [];
  final List<String> deletedSessions = [];
  final List<({String id, int side})> fetched = [];
  bool _hasToken = false;
  int _polls = 0;

  @override
  bool get hasToken => _hasToken;

  PickerSession _session({required bool set}) => PickerSession(
    id: 's1',
    pickerUri: Uri.parse('https://photos.example.com/picker/s1'),
    pollInterval: pollInterval,
    timeoutAt: clock().add(timeoutIn),
    mediaItemsSet: set,
  );

  @override
  Future<void> authorize() async {
    calls.add('authorize');
    await authorizeGate?.future;
    if (authorizeError != null) throw authorizeError!;
    _hasToken = true;
  }

  @override
  Future<PickerSession> createSession({int maxItemCount = 30}) async {
    calls.add('createSession');
    if (createError != null) throw createError!;
    return _session(set: pollsBeforeSet == 0);
  }

  @override
  Future<PickerSession> getSession(String sessionId) async {
    calls.add('getSession');
    _polls++;
    final n = pollsBeforeSet;
    return _session(set: n != null && _polls >= n);
  }

  @override
  Future<List<PickedItem>> listPickedItems(String sessionId) async {
    calls.add('listPickedItems');
    await listGate?.future;
    if (listError != null) throw listError!;
    return items;
  }

  @override
  Future<Uint8List> fetchImage(PickedItem item, {required int maxSide}) async {
    calls.add('fetchImage');
    fetched.add((id: item.id, side: maxSide));
    final large = maxSide > 768;
    if ((large ? failLargeIds : failThumbIds).contains(item.id)) {
      throw const GooglePhotosException(GooglePhotosFailure.network);
    }
    if (large && largeBytes != null) return largeBytes!(item);
    return imageBytes ?? fakeJpeg();
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    calls.add('deleteSession');
    deletedSessions.add(sessionId);
  }
}

/// 偽の [PhotoPickAi]。渡された依頼を [requests] に残す
class FakePhotoPickAi implements PhotoPickAi {
  /// 返す判定。null なら、依頼の枚数ぶんの candidate
  List<PhotoJudgement>? judgements;
  Object? error;
  Completer<void>? gate;
  final List<PhotoPickRequest> requests = [];

  @override
  Future<List<PhotoJudgement>> choose(PhotoPickRequest request) async {
    requests.add(request);
    await gate?.future;
    if (error != null) throw error!;
    return judgements ??
        [
          for (var i = 0; i < request.candidates.length; i++)
            PhotoJudgement(i, PhotoDecision.candidate),
        ];
  }
}
