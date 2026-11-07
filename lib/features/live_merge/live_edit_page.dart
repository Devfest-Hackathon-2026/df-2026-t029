import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/live_providers.dart';
import '../../providers/oshi_providers.dart';
import '../../repositories/live_repository.dart';
import '../live_form/live_draft_to_models.dart';
import '../live_form/live_form_page.dart';

/// ライブの編集（/lives/:liveId/edit。計画書 3.7）。
/// 既存の一式を読み、内容を入れた入力画面を開く。保存すると照合を飛ばして
/// そのライブとの差分の確認へ進む
class LiveEditPage extends ConsumerStatefulWidget {
  const LiveEditPage({super.key, required this.liveId});

  final String liveId;

  @override
  ConsumerState<LiveEditPage> createState() => _LiveEditPageState();
}

class _LiveEditPageState extends ConsumerState<LiveEditPage> {
  /// 読み込めたら1回だけ作る（作り直すと入力中の内容が消えるため）
  LiveEditSeed? _seed;
  ExistingLive? _base;

  @override
  Widget build(BuildContext context) {
    final seed = _seed;
    final base = _base;
    if (seed != null && base != null) {
      return LiveFormPage(initial: seed.draft, editSeed: seed, editBase: base);
    }

    final existing = ref.watch(existingLiveProvider(widget.liveId));
    final oshis = ref.watch(allOshisProvider);
    final Widget body;
    if (existing.hasError || oshis.hasError) {
      body = _Message(
        key: const Key('live_edit_error'),
        text: 'ライブを読み込めませんでした',
        action: OutlinedButton(
          onPressed: () {
            ref.invalidate(existingLiveProvider(widget.liveId));
            ref.invalidate(allOshisProvider);
          },
          child: const Text('もう一度読み込む'),
        ),
      );
    } else if (!existing.hasValue || !oshis.hasValue) {
      body = const Center(
        key: Key('live_edit_loading'),
        child: CircularProgressIndicator(),
      );
    } else if (existing.requireValue case final live?) {
      // build 中に setState しないよう、作った値をそのまま使い、次から使い回す
      final newSeed = liveDraftFromExisting(live, oshis.requireValue);
      _seed = newSeed;
      _base = live;
      return LiveFormPage(
        initial: newSeed.draft,
        editSeed: newSeed,
        editBase: live,
      );
    } else {
      body = const _Message(
        key: Key('live_edit_not_found'),
        text: 'このライブは見つかりませんでした',
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('ライブ情報の編集')),
      body: SafeArea(child: body),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ],
      ),
    ),
  );
}
