import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/auth_repository.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () async {
            try {
              await ref.read(authRepositoryProvider).signInWithGoogle();
            } on FirebaseAuthException catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('ログインに失敗しました（${e.code}）')),
              );
            }
          },
          child: const Text('Google でログイン'),
        ),
      ),
    );
  }
}