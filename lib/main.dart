import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'oshiashi',
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = snapshot.data;
          return user == null ? const LoginPage() : HomePage(user: user);
        },
      ),
    );
  }
}

// ログインページ
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () async {
            try {
              await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
            } on FirebaseAuthException catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('ログインに失敗しました (${e.code})')),
              );
            }
          },
          child: const Text('Googleでログイン'),
        ),
      ),
    );
  }
}

// ログイン後のホームページ
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final testRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('test');

    return Scaffold(
      appBar: AppBar(
        title: Text('${user.displayName ?? 'ゲスト'} さん'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: testRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          return ListView(
            children: [
              for (final doc in docs)
                ListTile(title: Text(doc.data()['message'] as String? ?? '')),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => testRef.add({
          'message': 'テスト ${DateTime.now()}',
          'createdAt': FieldValue.serverTimestamp(),
        }),
        child: const Icon(Icons.add),
      ),
    );
  }
}