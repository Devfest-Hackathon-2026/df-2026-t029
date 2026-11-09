import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gemini_backend.dart';

class GeminiService {
  final _extractModel = geminiBackend().generativeModel(
    model: 'gemini-3.5-flash-lite',
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: _scanSchema,
    ),
  );

  /// 告知画像から、ライブ・公演・受付の情報を抽出する
  Future<Map<String, dynamic>> extractLiveInfo(
    Uint8List imageBytes,
    String mimeType,
  ) async {
    final today = DateTime.now();
    final prompt = '''
添付画像（ライブの告知画像やチケットサイトのスクリーンショット）から、ライブ・公演・チケット受付の情報を抽出してください。
- 画像に書かれていない情報は推測せず、null または空の配列にしてください。
- 年が書かれていない日付は、今日（${today.year}年${today.month}月${today.day}日）以降で最も近い年としてください。
- 日時は日本時間（+09:00）で出力してください。時刻が書かれていない期限は 23:59 としてください。
''';

    final text = await _withRetry(() => _extractModel.generateContent([
          Content.multi([TextPart(prompt), InlineDataPart(mimeType, imageBytes)]),
        ]));
    return jsonDecode(text) as Map<String, dynamic>;
  }

  /// 混雑などで失敗したとき、間隔をあけて最大3回まで試す
  Future<String> _withRetry(
    Future<GenerateContentResponse> Function() call,
  ) async {
    for (var attempt = 1; ; attempt++) {
      try {
        final response = await call().timeout(const Duration(seconds: 60));
        return response.text ?? '';
      } on FirebaseAIException {
        if (attempt >= 3) rethrow;
        await Future.delayed(Duration(seconds: 2 * attempt));
      }
    }
  }
}

final geminiServiceProvider = Provider<GeminiService>((ref) => GeminiService());

/// 日時の項目（不明なら null）
Schema _dateTime(String description) => Schema.string(
      description: '$description。ISO 8601 形式（例：2026-12-01T18:00:00+09:00）',
      nullable: true,
    );

/// Gemini に返させる JSON の形
final _scanSchema = Schema.object(
  properties: {
    'performers': Schema.array(
      description: '出演するグループ名・個人名',
      items: Schema.string(),
    ),
    'liveTitle': Schema.string(
      description: 'ライブ名（ツアー名・イベント名）',
      nullable: true,
    ),
    'officialUrl': Schema.string(
      description: '画像内に書かれた公式ページの URL',
      nullable: true,
    ),
    'performances': Schema.array(
      description: '公演（日時と会場の組）の一覧',
      items: Schema.object(properties: {
        'startAt': _dateTime('開演日時'),
        'openAt': _dateTime('開場日時'),
        'venue': Schema.string(description: '会場名', nullable: true),
        'prefecture': Schema.string(description: '会場の都道府県', nullable: true),
      }),
    ),
    'receptions': Schema.array(
      description: 'チケットの申込受付の一覧',
      items: Schema.object(properties: {
        'type': Schema.enumString(
          enumValues: ['fc', 'general', 'upgrade', 'other'],
          description: 'fc=FC先行、general=一般、upgrade=アプグレ（当選者向けの座席アップグレード）、other=その他（プレイガイド先行など）',
        ),
        'name': Schema.string(description: '受付の表示名（例：FC1次先行）'),
        'applyStartAt': _dateTime('申込開始日時'),
        'applyEndAt': _dateTime('申込期限'),
        'resultAt': _dateTime('当落発表日時'),
        'paymentDeadline': _dateTime('入金期限'),
        'prices': Schema.array(
          description: '席種と料金',
          items: Schema.object(properties: {
            'seat': Schema.string(description: '席種'),
            'amount': Schema.integer(description: '料金（円）'),
          }),
        ),
        'winnersOnly': Schema.boolean(
          description: '当選者のみが対象の受付か（アプグレなど）',
        ),
      }),
    ),
  },
);