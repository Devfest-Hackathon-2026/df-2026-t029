import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/user_profile.dart';
import '../../providers/oshi_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/public_profile_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import 'notification_switch.dart';
import 'profile_icon_editor.dart';
import 'theme_color_picker.dart';

/// プロフィールの作成・編集画面（G-8・add_I 3.2）。未作成なら初回作成として開く
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  /// ハンドルネームの上限（文字数）
  static const int maxNameLength = 20;

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _x = TextEditingController();
  bool _filled = false;
  bool _saving = false;

  /// 初回作成として開いたか
  bool _creating = false;

  @override
  void dispose() {
    _name.dispose();
    _x.dispose();
    super.dispose();
  }

  /// 読み込んだプロフィールを、最初の1回だけ入力欄に入れる
  void _fill(UserProfile? profile) {
    if (_filled) return;
    _filled = true;
    _creating = profile == null;
    _name.text = profile?.displayName ?? '';
    _x.text = profile?.xAccount ?? '';
  }

  /// 前後の空白と先頭の @ を外す
  static String _normalizeX(String value) {
    final t = value.trim();
    return t.startsWith('@') ? t.substring(1) : t;
  }

  String? _validateName(String? value) {
    if ((value ?? '').trim().isEmpty) return 'ハンドルネームを入力してください';
    return null;
  }

  String? _validateX(String? value) {
    final t = _normalizeX(value ?? '');
    if (t.isEmpty) return null;
    if (!RegExp(r'^[A-Za-z0-9_]{1,15}$').hasMatch(t)) {
      return '英数字と _ の15文字以内で入力してください';
    }
    return null;
  }

  Future<void> _save({required bool isInitial}) async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .save(uid, displayName: _name.text, xAccount: _normalizeX(_x.text));
      // 公開プロフィールにも名前を書く（add_I 3.2）。失敗してもプロフィールの保存は終わっている
      try {
        await ref
            .read(publicProfileRepositoryProvider)
            .saveName(uid, _name.text);
      } catch (e) {
        debugPrint('公開プロフィールの名前を保存できませんでした: $e');
      }
      if (!mounted) return;
      // 初回作成は、プロフィールが届いた時点で build の ref.listen がホームへ移す
      if (isInitial) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存に失敗しました：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 初回作成を保存したら、プロフィールが届いてからホームへ移す
    // （先に移ると、ルーターがまだ未作成と判定して作成画面へ戻すため）
    ref.listen(myProfileProvider, (_, next) {
      if (_creating && next.value != null) {
        _creating = false;
        context.go('/');
      }
    });
    return ref
        .watch(myProfileProvider)
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => HakoPageScaffold(
            title: 'プロフィール',
            showBack: true,
            showAccount: false,
            barColor: Theme.of(context).colorScheme.primaryContainer,
            body: Center(child: Text('読み込みに失敗しました：$e')),
          ),
          data: (profile) {
            _fill(profile);
            final isInitial = profile == null;
            return HakoPageScaffold(
              title: isInitial ? 'プロフィールを作成' : 'プロフィールを編集',
              showBack: !isInitial,
              backFallback: '/',
              showAccount: false,
              barColor: Theme.of(context).colorScheme.primaryContainer,
              body: Form(
                key: _formKey,
                child: Builder(
                  builder: (context) {
                    final pad = HakoPageScaffold.padding(context);
                    return ListView(
                      padding: pad.copyWith(bottom: 48),
                      children: [
                        // アイコン（add_I 3.2）
                        ProfileIconEditor(name: profile?.displayName ?? ''),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            isInitial
                                ? 'グッズ交換の投稿・返信・チャットで表示される名前を決めてください。あとから変更できます。'
                                : '変更した名前は、これから書く投稿・返信から反映されます。',
                            style: HakoFonts.jp(
                              size: 13,
                              color: BrandColors.sub,
                              height: 1.6,
                            ),
                          ),
                        ),
                        TextFormField(
                          controller: _name,
                          enabled: !_saving,
                          maxLength: maxNameLength,
                          decoration: const InputDecoration(
                            labelText: 'ハンドルネーム（必須）',
                          ),
                          validator: _validateName,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _x,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                            labelText: 'X アカウント（任意）',
                            prefixText: '@',
                            helperText: '投稿の連絡先の初期値に使います',
                          ),
                          validator: _validateX,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _saving
                              ? null
                              : () => _save(isInitial: isInitial),
                          child: Text(_saving ? '保存中…' : '保存'),
                        ),
                        // テーマカラーと通知は編集のときだけ（初回の作成は短く保つ）
                        if (!isInitial) ...[
                          const SizedBox(height: 26),
                          const Divider(
                            thickness: 2,
                            height: 2,
                            color: BrandColors.ink,
                          ),
                          const SizedBox(height: 22),
                          const ThemeColorPicker(),
                          const SizedBox(height: 16),
                          const Divider(),
                          const NotificationSwitch(),
                        ],
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
  }
}