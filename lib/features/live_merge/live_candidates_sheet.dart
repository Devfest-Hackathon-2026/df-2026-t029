import 'package:flutter/material.dart';

import '../../repositories/live_repository.dart';
import '../../utils/live_match.dart';
import '../live_form/date_time_field.dart';

/// 候補の選択シートで選んだもの（閉じたら null）
sealed class CandidateChoice {
  const CandidateChoice();
}

/// 既存のライブに反映する
final class UseExistingLive extends CandidateChoice {
  const UseExistingLive(this.existing);

  final ExistingLive existing;
}

/// 別のライブとして新しく登録する
final class CreateNewLive extends CandidateChoice {
  const CreateNewLive();
}

const _strengthLabels = {
  MatchStrength.sure: 'ほぼ同じライブ',
  MatchStrength.possible: '同じライブかもしれません',
};

/// 同じライブの候補を示し、反映先を選んでもらう（計画書 6章）。
/// 閉じたら null（何もしない。入力は残す）
Future<CandidateChoice?> showLiveCandidatesSheet(
  BuildContext context,
  List<LiveCandidate> candidates,
) => showModalBottomSheet<CandidateChoice>(
  context: context,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: ListView(
        key: const Key('merge_candidates_sheet'),
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '同じライブが登録されているかもしれません',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text('同じライブなら、登録済みのライブに反映すると、ほかの人の申込状況もそのまま使えます。'),
          for (final c in candidates) _CandidateCard(candidate: c),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const Key('merge_candidate_new_button'),
            onPressed: () => Navigator.of(context).pop(const CreateNewLive()),
            child: const Text('別のライブとして新しく登録する'),
          ),
        ],
      ),
    ),
  ),
);

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate});

  final LiveCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final live = candidate.existing.live;
    final first = candidate.existing.firstPerformance;
    return Card(
      key: Key('merge_candidate_${live.id}'),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _strengthLabels[candidate.strength]!,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Text(live.title, style: Theme.of(context).textTheme.titleSmall),
            if (first != null)
              Text('${formatDateTime(first.startAt)} ${first.venue}'),
            Text(
              '公演 ${candidate.existing.performances.length}件・'
              '受付 ${candidate.existing.receptions.length}件',
            ),
            const SizedBox(height: 4),
            for (final r in candidate.reasons)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check, size: 16),
                  const SizedBox(width: 4),
                  Expanded(child: Text(r)),
                ],
              ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                key: Key('merge_candidate_use_${live.id}'),
                onPressed: () =>
                    Navigator.of(context)
                        .pop(UseExistingLive(candidate.existing)),
                child: const Text('このライブに反映する'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
