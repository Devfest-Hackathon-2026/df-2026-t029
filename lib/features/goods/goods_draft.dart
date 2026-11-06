import '../../models/goods.dart';
import '../../models/oshi.dart';
import '../../utils/goods_search.dart';
import '../../utils/text_normalizer.dart';

/// 入力中の種類
class VariantDraft {
  VariantDraft({this.name = '', this.oshiId});

  String name;
  String? oshiId;
}

/// 登録画面で入力中のグッズ
class GoodsDraft {
  GoodsDraft({
    this.name = '',
    this.aliases = '',
    this.category = GoodsCategory.other,
    this.price = '',
    this.officialUrl = '',
    List<VariantDraft>? variants,
  }) : variants = variants ?? [];

  // 上限はセキュリティルールと同じ
  static const int maxNameLength = 100;
  static const int maxAliases = 10;
  static const int maxAliasLength = 50;
  static const int maxVariants = 100;
  static const int maxPrice = 1000000;
  static const int maxUrlLength = 200;

  /// 種類を入力しなかったときの種類の名前（DB 設計案 5章）
  static const String defaultVariantName = '通常';

  String name;

  /// 別名（「、」または「,」区切り）
  String aliases;
  GoodsCategory category;
  String price;
  String officialUrl;
  final List<VariantDraft> variants;

  List<String> get cleanedAliases => aliases
      .split(RegExp('[、,，]'))
      .map((a) => a.trim())
      .where((a) => a.isNotEmpty)
      .toList();

  /// 名前が入っている種類（空の行は無視する）
  List<VariantDraft> get filledVariants =>
      variants.where((v) => v.name.trim().isNotEmpty).toList();

  int? get _priceValue => int.tryParse(price.trim().replaceAll(',', ''));

  /// 入力を検査し、エラー文の一覧を返す（空なら保存できる）。
  /// [existing] は同じ推しの既存のグッズ（重複の確認に使う）
  List<String> validate(List<Goods> existing) {
    final errors = <String>[];

    final n = name.trim();
    if (normalizeName(n).isEmpty) {
      errors.add('グッズ名を入力してください');
    } else if (n.length > maxNameLength) {
      errors.add('グッズ名は$maxNameLength文字以内で入力してください');
    }

    final as = cleanedAliases;
    if (as.length > maxAliases) {
      errors.add('別名は$maxAliases個までです');
    } else if (as.any((a) => a.length > maxAliasLength)) {
      errors.add('別名は1つ$maxAliasLength文字以内で入力してください');
    }

    if (price.trim().isNotEmpty) {
      final p = _priceValue;
      if (p == null || p < 0 || p > maxPrice) {
        errors.add('定価は0〜$maxPrice円の数字で入力してください');
      }
    }

    final url = officialUrl.trim();
    if (url.isNotEmpty &&
        (!RegExp(r'^https://\S+$').hasMatch(url) ||
            url.length > maxUrlLength)) {
      errors.add('公式の販売ページは https:// で始まる URL を入力してください');
    }

    final vs = filledVariants;
    if (vs.length > maxVariants) {
      errors.add('種類は$maxVariants個までです');
    }
    final keys = [for (final v in vs) normalizeName(v.name)];
    if (keys.toSet().length != keys.length) {
      errors.add('同じ名前の種類が重複しています');
    }

    if (normalizeName(n).isNotEmpty) {
      final dup = findExactGoodsDuplicates(existing, name: n, aliases: as);
      if (dup.isNotEmpty) {
        errors.add('同じ名前のグッズが既にあります'
            '（${dup.map((g) => g.name).join('、')}）。'
            '検索画面から既存のグッズを使ってください');
      }
    }
    return errors;
  }

  /// 保存用のモデルに変換する（[validate] の結果が空のときだけ呼ぶ）。
  /// 種類には v1, v2…の ID を振る。種類が1つもなければ「通常」を1つ作る
  Goods toGoods(OshiSummary target) {
    String? orNull(String s) => s.trim().isEmpty ? null : s.trim();
    final filled = filledVariants;
    return Goods(
      name: name.trim(),
      aliases: cleanedAliases,
      category: category,
      groupIds: target.kind == OshiKind.group ? [target.id] : const [],
      oshiIds: target.kind == OshiKind.person ? [target.id] : const [],
      price: price.trim().isEmpty ? null : _priceValue,
      officialUrl: orNull(officialUrl),
      variants: filled.isEmpty
          ? const [GoodsVariant(id: 'v1', name: defaultVariantName)]
          : [
              for (final (i, v) in filled.indexed)
                GoodsVariant(
                  id: 'v${i + 1}',
                  name: v.name.trim(),
                  oshiId: v.oshiId,
                ),
            ],
    );
  }
}