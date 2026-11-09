import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/memory_ticket.dart';
import 'gemini_backend.dart';

enum PhotoDecision { pick, candidate, skip }

enum SkipKind { duplicate, blurry, screenshot, unrelated, other }

/// 写真1枚への判定
class PhotoJudgement {
  const PhotoJudgement(
    this.index,
    this.decision, {
    this.rank,
    this.label,
    this.skipKind,
  });

  final int index;
  final PhotoDecision decision;

  /// pick のときの順位（1が表紙）
  final int? rank;

  /// 10文字までの短い言葉
  final String? label;

  /// skip のときの理由の種類
  final SkipKind? skipKind;
}

/// Gemini に渡す写真1枚（縮小版）
class PhotoPickCandidate {
  const PhotoPickCandidate(this.bytes, this.mimeType, {this.createTime});

  final Uint8List bytes;
  final String mimeType;
  final DateTime? createTime;
}

/// Gemini に渡すもの。縮小版の写真と、ライブ名・日時・会場・アーティスト名だけ
/// （元の写真・位置情報・利用者の名前・メールアドレスは送らない）
class PhotoPickRequest {
  const PhotoPickRequest({
    required this.title,
    required this.startAt,
    required this.venue,
    this.artist,
    required this.candidates,
  });

  final String title;
  final DateTime startAt;
  final String venue;
  final String? artist;
  final List<PhotoPickCandidate> candidates;
}

/// ラベルの最大文字数
const _maxLabelChars = 10;

int? _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

PhotoDecision? _decisionOf(Object? v) {
  if (v is! String) return null;
  for (final d in PhotoDecision.values) {
    if (d.name == v.trim()) return d;
  }
  return null;
}

SkipKind _skipKindOf(Object? v) {
  if (v is String) {
    for (final k in SkipKind.values) {
      if (k.name == v.trim()) return k;
    }
  }
  return SkipKind.other;
}

String? _labelOf(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  if (t.isEmpty) return null;
  final runes = t.runes.toList();
  return runes.length <= _maxLabelChars
      ? t
      : String.fromCharCodes(runes.take(_maxLabelChars));
}

/// Gemini の返り値の後処理（4.5）。どんな [json] でも例外を投げず、
/// [count] 個すべてに判定を返す。範囲外・重複した番号は捨てる／返ってこなかった
/// 番号は candidate／pick は [maxPicks] 枚まで（rank の小さい順、無ければ番号順）／
/// skip の理由が無い・不明なら other／label は10文字まで
List<PhotoJudgement> parsePhotoPick(
  Object? json,
  int count, {
  int maxPicks = maxAiPicks,
}) {
  if (count <= 0) return const [];
  try {
    final list = switch (json) {
      Map() => json['items'],
      List() => json,
      _ => null,
    };
    final byIndex = <int, PhotoJudgement>{};
    if (list is List) {
      for (final raw in list) {
        if (raw is! Map) continue;
        final index = _asInt(raw['index']);
        if (index == null || index < 0 || index >= count) continue;
        if (byIndex.containsKey(index)) continue;
        final decision =
            _decisionOf(raw['decision']) ?? PhotoDecision.candidate;
        byIndex[index] = PhotoJudgement(
          index,
          decision,
          rank: decision == PhotoDecision.pick ? _asInt(raw['rank']) : null,
          label: _labelOf(raw['label']),
          skipKind: decision == PhotoDecision.skip
              ? _skipKindOf(raw['skipKind'])
              : null,
        );
      }
    }

    // pick が多すぎるときは、順位の小さい順（無ければ番号順）に残す
    final picks =
        byIndex.values.where((j) => j.decision == PhotoDecision.pick).toList()
          ..sort((a, b) {
            final ra = a.rank ?? 1 << 30;
            final rb = b.rank ?? 1 << 30;
            return ra != rb ? ra.compareTo(rb) : a.index.compareTo(b.index);
          });
    for (final j in picks.skip(maxPicks < 0 ? 0 : maxPicks)) {
      byIndex[j.index] = PhotoJudgement(
        j.index,
        PhotoDecision.candidate,
        label: j.label,
      );
    }

    return [
      for (var i = 0; i < count; i++)
        byIndex[i] ?? PhotoJudgement(i, PhotoDecision.candidate),
    ];
  } catch (_) {
    return [
      for (var i = 0; i < count; i++)
        PhotoJudgement(i, PhotoDecision.candidate),
    ];
  }
}

/// 固定の理由の文（4.5）。Gemini の自由な文は画面に出さない
String skipReasonText(SkipKind? kind) => switch (kind) {
  SkipKind.duplicate => '似ているため',
  SkipKind.blurry => 'ピントがずれているため',
  SkipKind.screenshot => 'スクリーンショットのため',
  SkipKind.unrelated => 'ライブと関係なさそうなため',
  SkipKind.other || null => '今回は選ばなかったため',
};

abstract class PhotoPickAi {
  /// 失敗（再試行のあとも）は例外を投げる。呼び出し側が「AIが選べなかった」にする
  Future<List<PhotoJudgement>> choose(PhotoPickRequest request);
}

/// 日本時間の「2026/12/19 18:30」
String _jstDateTime(DateTime t) {
  final d = t.toUtc().add(const Duration(hours: 9));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}/${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

/// Gemini に渡す指示（座席・利用者の名前・メールアドレスは含めない）
String buildPhotoPickPrompt(PhotoPickRequest r) {
  final artist = r.artist;
  return '''
ライブの記録のカバーにする写真を選んでください。あとに続く写真には「写真 0」「写真 1」…と番号が付いています。

ライブ名：${r.title}
開演：${_jstDateTime(r.startAt)}
会場：${r.venue}
${artist == null || artist.isEmpty ? '' : 'アーティスト：$artist\n'}
選びかた:
- 最大$maxAiPicksまで、decision を pick にします。pick には rank（1が表紙、小さいほど優先）を付けます。
- 構図・ピント・明るさ・ライブらしさ（ステージ・客席・会場の外観・チケット・グッズ）で選びます。
- 似た写真は1枚だけ pick にし、ほかは skip（skipKind は duplicate）にします。
- ピントが大きくずれた写真は skip（blurry）、スクリーンショットは skip（screenshot）、ライブと関係なさそうな写真は skip（unrelated）にします。
- どちらでもない写真は candidate にします。
- 人物を特定しません。顔の名前を書きません。label は10文字までの短い言葉（例：ステージ）で、書けなければ省きます。
- 撮影日時は参考にしますが、決め手にはしません。
- すべての写真の番号について、1つずつ判定を返します。
''';
}

/// Gemini に返させる JSON の形
final _pickSchema = Schema.object(
  properties: {
    'items': Schema.array(
      description: '写真ごとの判定',
      items: Schema.object(
        properties: {
          'index': Schema.integer(description: '写真の番号'),
          'decision': Schema.enumString(
            enumValues: ['pick', 'candidate', 'skip'],
            description: 'pick=選ぶ、candidate=ほかの候補、skip=選ばない',
          ),
          'rank': Schema.integer(description: 'pick のときの順位（1が表紙）'),
          'label': Schema.string(description: '10文字までの短い言葉'),
          'skipKind': Schema.enumString(
            enumValues: [
              'duplicate',
              'blurry',
              'screenshot',
              'unrelated',
              'other',
            ],
            description: 'skip のときの理由の種類',
          ),
        },
        optionalProperties: ['rank', 'label', 'skipKind'],
      ),
    ),
  },
);

/// Gemini（`GeminiService` と同じ作り）で写真を選ぶ。最大3回・60秒
class GeminiPhotoPickAi implements PhotoPickAi {
  GenerativeModel? _model;

  GenerativeModel get _m => _model ??= geminiBackend().generativeModel(
    model: 'gemini-3.5-flash-lite',
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: _pickSchema,
    ),
  );

  /// 送る内容を組み立てる（番号つきの順序。画像と、ライブ名などだけ）
  List<Content> buildContents(PhotoPickRequest r) {
    final parts = <Part>[TextPart(buildPhotoPickPrompt(r))];
    for (final (i, c) in r.candidates.indexed) {
      final t = c.createTime;
      parts.add(TextPart(t == null ? '写真 $i' : '写真 $i（撮影 ${_jstDateTime(t)}）'));
      parts.add(InlineDataPart(c.mimeType, c.bytes));
    }
    return [Content.multi(parts)];
  }

  @override
  Future<List<PhotoJudgement>> choose(PhotoPickRequest request) async {
    final count = request.candidates.length;
    final contents = buildContents(request);
    for (var attempt = 1; ; attempt++) {
      try {
        final response = await _m
            .generateContent(contents)
            .timeout(const Duration(seconds: 60));
        Object? json;
        try {
          json = jsonDecode(response.text ?? '');
        } catch (_) {
          json = null; // 壊れた JSON は、全部「ほかの候補」にする
        }
        return parsePhotoPick(json, count);
      } on FirebaseAIException {
        if (attempt >= 3) rethrow;
        await Future.delayed(Duration(seconds: 2 * attempt));
      }
    }
  }
}

final photoPickAiProvider = Provider<PhotoPickAi>((ref) => GeminiPhotoPickAi());
