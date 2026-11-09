import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/google_photos_service.dart';
import '../../services/photo_pick_ai.dart';
import '../../utils/google_photos_errors.dart';
import '../../utils/memory_ticket.dart';

/// Google フォトの接続テスト（G0。`/photos-test`）。本番の導線には出さない。
/// 認可 → セッション → 選択画面 → 一覧 → 縮小版 → Gemini を、1画面で順に試す。
/// 画面には、件数・バイト数・所要時間・結果の判定だけを出す
/// （トークン・写真そのもの・URL・例外の中身は出さない）
class PhotosTestPage extends ConsumerStatefulWidget {
  const PhotosTestPage({super.key});

  @override
  ConsumerState<PhotosTestPage> createState() => _PhotosTestPageState();
}

class _PhotosTestPageState extends ConsumerState<PhotosTestPage> {
  final List<String> _log = [];
  bool _busy = false;
  PickerSession? _session;
  List<PickedItem> _items = const [];
  final List<Uint8List> _thumbs = [];

  void _add(String line) {
    if (!mounted) return;
    setState(() => _log.add(line));
  }

  /// 処理を1つ実行し、所要時間と成功・失敗（日本語の文言）を記録する
  Future<void> _step(String name, Future<String> Function() run) async {
    if (_busy) return;
    setState(() => _busy = true);
    final sw = Stopwatch()..start();
    try {
      final result = await run();
      _add('OK  $name（${sw.elapsedMilliseconds}ms）$result');
    } catch (e) {
      _add(
        'NG  $name（${sw.elapsedMilliseconds}ms）${googlePhotosErrorMessage(e)}',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ポップアップは、ボタンの処理の最初に呼ぶ
  void _authorize() {
    final api = ref.read(googlePhotosApiProvider);
    _step('1. 認可', () async {
      await api.authorize();
      return '';
    });
  }

  void _createSession() {
    final api = ref.read(googlePhotosApiProvider);
    _step('2. セッション作成', () async {
      final s = await api.createSession();
      _session = s;
      return ' 確認間隔 ${s.pollInterval.inSeconds}秒・'
          '制限 ${s.timeoutAt.difference(DateTime.now()).inSeconds}秒';
    });
  }

  // 新しいタブを開くのは、利用者の2回目のボタン（ポップアップ止めを避ける）
  void _openPicker() {
    final s = _session;
    if (s == null) return;
    launchUrl(
      s.pickerUri.replace(path: '${s.pickerUri.path}/autoclose'),
      webOnlyWindowName: '_blank',
    );
    _add('選択画面を開きました');
  }

  void _waitAndList() {
    final api = ref.read(googlePhotosApiProvider);
    final s = _session;
    if (s == null) return;
    _step('3. 選択待ち・一覧', () async {
      var cur = s;
      while (!cur.mediaItemsSet) {
        if (!mounted) return '';
        if (DateTime.now().isAfter(s.timeoutAt)) {
          throw const GooglePhotosException(GooglePhotosFailure.timeout);
        }
        await Future<void>.delayed(s.pollInterval);
        cur = await api.getSession(s.id);
      }
      final items = await api.listPickedItems(s.id);
      _items = items;
      final withTime = items.where((i) => i.createTime != null).length;
      final withSize = items.where((i) => i.width != null).length;
      return ' ${items.length}枚（撮影日時あり $withTime・大きさあり $withSize）';
    });
  }

  void _fetchThumbs() {
    final api = ref.read(googlePhotosApiProvider);
    final items = _items;
    if (items.isEmpty) return;
    _step('4. 縮小版の取得', () async {
      _thumbs.clear();
      var failed = 0;
      var bytes = 0;
      for (var i = 0; i < items.length; i += 4) {
        final chunk = items.skip(i).take(4);
        final results = await Future.wait([
          for (final it in chunk)
            api
                .fetchImage(it, maxSide: pickThumbSide)
                .then<Uint8List?>((b) => b)
                .catchError((_) => null),
        ]);
        for (final r in results) {
          if (r == null) {
            failed++;
          } else {
            _thumbs.add(r);
            bytes += r.length;
          }
        }
      }
      final sid = _session?.id;
      if (sid != null) await api.deleteSession(sid);
      return ' 取得 ${_thumbs.length}枚・失敗 $failed枚・計 ${(bytes / 1024).round()}KB';
    });
  }

  void _gemini() {
    final ai = ref.read(photoPickAiProvider);
    final thumbs = [..._thumbs];
    if (thumbs.isEmpty) return;
    _step('5. Gemini の写真えらび', () async {
      final result = await ai.choose(
        PhotoPickRequest(
          title: '接続テスト',
          startAt: DateTime.now(),
          venue: 'テスト会場',
          candidates: [
            for (final t in thumbs) PhotoPickCandidate(t, 'image/jpeg'),
          ],
        ),
      );
      int count(PhotoDecision d) => result.where((j) => j.decision == d).length;
      return ' 選ぶ ${count(PhotoDecision.pick)}・候補 ${count(PhotoDecision.candidate)}・'
          '選ばない ${count(PhotoDecision.skip)}';
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget button(String label, VoidCallback onPressed, {Key? key}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        key: key,
        onPressed: _busy ? null : onPressed,
        child: Text(label),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Googleフォト接続テスト')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          button('1. つなぐ（認可）', _authorize),
          button('2. セッションを作る', _createSession),
          button('3. Googleフォトを開く', _openPicker),
          button('4. 選び終わるのを待って、一覧を取る', _waitAndList),
          button('5. 縮小版を取る', _fetchThumbs),
          button('6. Gemini に選んでもらう', _gemini),
          const SizedBox(height: 8),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          for (final line in _log) SelectableText(line),
        ],
      ),
    );
  }
}
