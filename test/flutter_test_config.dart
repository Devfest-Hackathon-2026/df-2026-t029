import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// すべてのテストの前に実行される。
/// 書体（BIZ UDPGothic など）をネットワークで取りに行かないようにする。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
