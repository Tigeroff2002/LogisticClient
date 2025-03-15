import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logist_client/widgets/auth_screen.dart';

class UserPage extends StatelessWidget {
  final String displayName;
  final String email;
  final String photoUrl;

  const UserPage({
    Key? key,
    required this.displayName,
    required this.email,
    required this.photoUrl,
  }) : super(key: key);

  Future<void> _signOut(BuildContext context) async {
    await GoogleSignIn().signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Возвращаем пользователя на страницу входа
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Профиль")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundImage: photoUrl.isNotEmpty
                  ? NetworkImage(photoUrl)
                  : const AssetImage('assets/default_avatar.png') as ImageProvider,
              radius: 50,
            ),
            const SizedBox(height: 16),
            Text(
              displayName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              email,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _signOut(context),
              child: const Text("Выйти"),
            ),
          ],
        ),
      ),
    );
  }
}