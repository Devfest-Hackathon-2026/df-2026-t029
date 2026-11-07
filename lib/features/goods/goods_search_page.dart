import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/goods.dart';
import '../../../models/oshi.dart';
import '../../../providers/goods_providers.dart';
import '../../../providers/oshi_providers.dart';
import '../../../theme/brand_colors.dart';
import '../../../theme/hako_app_widgets.dart';
import '../../../theme/hako_fonts.dart';
import '../../../utils/goods_search.dart';

class GoodsSearchPage extends ConsumerStatefulWidget {
  const GoodsSearchPage({super.key});

  @override
  ConsumerState<GoodsSearchPage> createState() => _GoodsSearchPageState();
}

class _GoodsSearchPageState extends ConsumerState<GoodsSearchPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final following = ref.watch(followingOshisProvider);
    final target = ref.watch(goodsTargetProvider);

    return HakoPageScaffold(
      title: 'グッズを探す',
      showBack: true,
      backFallback: '/trade',
      floatingActionButton: target == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/goods/new'),
              icon: const Icon(Icons.add),
              label: const Text('グッズを登録'),
            ),
      body: Padding(
        padding: HakoPageScaffold.padding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            following.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('推しを読み込めませんでした: $e'),
              data: (oshis) => _OshiSelector(
                oshis: oshis,
                selected: target,
                onChanged: (oshi) =>
                    ref.read(goodsTargetProvider.notifier).select(oshi),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: 'グッズ名で絞り込む',
                floatingLabelBehavior: FloatingLabelBehavior.never,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: _searchBorder(2),
                enabledBorder: _searchBorder(2),
                focusedBorder: _searchBorder(3),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildResults(target)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(OshiSummary? target) {
    if (target == null) {
      return const HakoEmpty('推しを選んでください');
    }
    final goods = ref.watch(goodsForTargetProvider);
    return goods.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => HakoEmpty('グッズを読み込めませんでした: $e'),
      data: (all) {
        final results = searchGoods(all, _query);
        if (results.isEmpty) {
          return const HakoEmpty('グッズが見つかりません');
        }
        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) => _GoodsTile(goods: results[index]),
        );
      },
    );
  }
}

OutlineInputBorder _searchBorder(double width) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(10),
  borderSide: BorderSide(color: BrandColors.ink, width: width),
);

/// フォロー中の推しから1つ選ぶ
class _OshiSelector extends StatelessWidget {
  const _OshiSelector({
    required this.oshis,
    required this.selected,
    required this.onChanged,
  });

  final List<OshiSummary> oshis;
  final OshiSummary? selected;
  final ValueChanged<OshiSummary?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (oshis.isEmpty) {
      return const Text('フォロー中の推しがいません。先に推しをフォローしてください');
    }
    // 承認などで中身が変わっても同じ推しとして扱えるよう、key で選ぶ
    final byKey = {for (final o in oshis) o.key: o};
    final selectedKey = byKey.containsKey(selected?.key) ? selected!.key : null;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BrandColors.ink, width: 2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedKey,
          hint: const Text('推しを選ぶ'),
          items: [
            for (final o in oshis)
              DropdownMenuItem(
                value: o.key,
                child: Text('${o.name}（${o.kind.label}）'),
              ),
          ],
          onChanged: (key) => onChanged(byKey[key]),
        ),
      ),
    );
  }
}

/// 検索結果の1件
class _GoodsTile extends StatelessWidget {
  const _GoodsTile({required this.goods});

  final Goods goods;

  @override
  Widget build(BuildContext context) {
    final variants = goods.variants.map((v) => v.name).join('・');
    return ListTile(
      title: Text(goods.name),
      subtitle: Text(
        '${goods.category.label}　$variants',
        style: HakoFonts.jp(size: 12, color: BrandColors.sub),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: goods.price == null ? null : Text('${goods.price}円'),
      onTap: () => context.push('/goods/${goods.id}/edit'),
    );
  }
}
