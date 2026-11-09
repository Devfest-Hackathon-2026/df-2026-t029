import 'package:firebase_ai/firebase_ai.dart';

/// アプリから Gemini を呼ぶときの入口（スクショ読み取り・写真えらび）。
///
/// Vertex AI 経由にする（Gemini Developer API の前払いクレジットが切れると止まるため）。
/// 請求は Functions のライブ情報の取得と同じく、Google Cloud の請求（Blaze）にまとまる。
/// リージョンは global（Functions の `live_fetch/gemini.js` と同じ。新しいモデルは global にある）。
FirebaseAI geminiBackend() => FirebaseAI.agentPlatform(location: 'global');
