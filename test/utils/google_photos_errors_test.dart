// googlePhotosErrorMessage のテスト（4.11 の文言を一字一句確かめる）。
import 'package:flutter_test/flutter_test.dart';
import 'package:oshiashi/services/google_photos_service.dart';
import 'package:oshiashi/utils/google_photos_errors.dart';

const _fallback = 'Googleフォトを使えませんでした。しばらくしてからもう一度お試しください。';

String _msg(GooglePhotosFailure k, {String? email}) =>
    googlePhotosErrorMessage(GooglePhotosException(k, email: email));

void main() {
  test('種類ごとの文言（4.11）', () {
    expect(_msg(GooglePhotosFailure.cancelled), 'Googleフォトにつなぎませんでした。');
    expect(
      _msg(GooglePhotosFailure.popupBlocked),
      'ポップアップが止められました。ブラウザの設定で許可してから、もう一度お試しください。',
    );
    expect(
      _msg(GooglePhotosFailure.accountInUse),
      'この Google アカウントは、別のおしあしのアカウントで使われています。別の Google アカウントを選んでください',
    );
    expect(_msg(GooglePhotosFailure.noToken), 'Googleフォトの権限を取得できませんでした。');
    expect(_msg(GooglePhotosFailure.apiUnavailable), _fallback);
    expect(_msg(GooglePhotosFailure.timeout), '選ぶ時間が過ぎました。もう一度やり直してください。');
    expect(_msg(GooglePhotosFailure.noneSelected), '写真が選ばれませんでした。');
    expect(_msg(GooglePhotosFailure.network), '通信できませんでした。もう一度お試しください。');
    expect(_msg(GooglePhotosFailure.other), _fallback);
  });

  test('すべての種類に、空でない文言がある', () {
    for (final k in GooglePhotosFailure.values) {
      expect(_msg(k), isNotEmpty, reason: '$k');
    }
  });

  test('accountMismatch はメールを含む（全角のかっこ）', () {
    expect(
      _msg(GooglePhotosFailure.accountMismatch, email: 'me@example.com'),
      'ログイン中のアカウント（me@example.com）を選んでください',
    );
  });

  test('accountMismatch でメールが無い・空なら、メール抜きの文言', () {
    const want = 'ログイン中のアカウントを選んでください';
    expect(_msg(GooglePhotosFailure.accountMismatch), want);
    expect(_msg(GooglePhotosFailure.accountMismatch, email: ''), want);
  });

  test('メールは accountMismatch 以外の文言に出ない', () {
    for (final k in GooglePhotosFailure.values) {
      if (k == GooglePhotosFailure.accountMismatch) continue;
      expect(
        _msg(k, email: 'me@example.com'),
        isNot(contains('me@example.com')),
      );
    }
  });

  test('知らない例外は、例外の中身を出さずに既定の文言', () {
    expect(googlePhotosErrorMessage(Exception('secret-token-xyz')), _fallback);
    expect(
      googlePhotosErrorMessage(StateError('https://example.com/x')),
      _fallback,
    );
    expect(googlePhotosErrorMessage('ya29.fake-token'), _fallback);
    expect(googlePhotosErrorMessage(42), _fallback);
  });

  test('トークン・URL らしい文字列が文言に出ない', () {
    for (final k in GooglePhotosFailure.values) {
      final s = _msg(k);
      expect(s, isNot(contains('ya29')));
      expect(s, isNot(contains('http')));
      expect(s, isNot(contains('Exception')));
    }
  });
}
