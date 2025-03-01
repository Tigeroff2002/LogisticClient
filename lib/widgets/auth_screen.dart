import 'package:flutter/material.dart';
import 'package:logist_client/services/auth_service.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Аутентификация Google'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await authService.signInWithGoogle();
          },
          child: const Text('Войти через Google'),
        ),
      ),
    );
  }
}