import '../services/google_photos_service.dart';

/// Google フォトの失敗を、画面に出す日本語の文言にする（4.11）。
/// 例外の中身・コード・トークンは含めない（メールアドレスは、
/// 別のアカウントを選んだときの文言にだけ含める）。
/// 知らない例外は「Googleフォトを使えませんでした。しばらくしてからもう一度お試しください。」
String googlePhotosErrorMessage(Object error) {
  const fallback = 'Googleフォトを使えませんでした。しばらくしてからもう一度お試しください。';
  if (error is! GooglePhotosException) return fallback;
  switch (error.kind) {
    case GooglePhotosFailure.cancelled:
      return 'Googleフォトにつなぎませんでした。';
    case GooglePhotosFailure.popupBlocked:
      return 'ポップアップが止められました。ブラウザの設定で許可してから、もう一度お試しください。';
    case GooglePhotosFailure.accountMismatch:
      final email = error.email;
      return (email == null || email.isEmpty)
          ? 'ログイン中のアカウントを選んでください'
          : 'ログイン中のアカウント（$email）を選んでください';
    case GooglePhotosFailure.accountInUse:
      return 'この Google アカウントは、別のおしあしのアカウントで使われています。別の Google アカウントを選んでください';
    case GooglePhotosFailure.noToken:
      return 'Googleフォトの権限を取得できませんでした。';
    case GooglePhotosFailure.timeout:
      return '選ぶ時間が過ぎました。もう一度やり直してください。';
    case GooglePhotosFailure.noneSelected:
      return '写真が選ばれませんでした。';
    case GooglePhotosFailure.network:
      return '通信できませんでした。もう一度お試しください。';
    case GooglePhotosFailure.apiUnavailable:
    case GooglePhotosFailure.other:
      return fallback;
  }
}
