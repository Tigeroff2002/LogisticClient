import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as web;

class SignIn extends StatefulWidget {
  const SignIn({Key? key}) : super(key: key);

  @override
  State<SignIn> createState() => _SignInState();
}

GoogleSignIn googleSignIn = GoogleSignIn(clientId: "118733131205-uj4ulrnj7b9qjms7n8ba971nj2qn5hab.apps.googleusercontent.com");

class _SignInState extends State<SignIn> {
  bool loading = false;
  GoogleSignInAccount? user;

  @override
  void initState() {
    super.initState();
    googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) async {
      debugPrint('User changed: $account');
      setState(() {
        user = account;
      });
    });

    googleSignIn.signInSilently();
  }

  Future<void> sendJWTToBackend(String? jwtToken) async {
    try {
      final response = await http.get(
        Uri.parse('https://localhost:7247/Users/me'),
        headers: {'Authorization': 'Bearer $jwtToken'},
      );

      if (response.statusCode != 200) {
        _showErrorAlert('Ошибка: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorAlert('Ошибка аутентификации: $e');
    }
  }

  void _showErrorAlert(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Ошибка"),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ОК'),
            ),
          ],
        );
      },
    );
  }

  Widget googleStyledButton({required String text, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: Colors.grey.shade400),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/google_logo.png',
              height: 24,
            ),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading) const LinearProgressIndicator(),
                if (user == null) ...[
                  const SizedBox(height: 16),
                  (GoogleSignInPlatform.instance as web.GoogleSignInPlugin).renderButton(configuration: web.GSIButtonConfiguration()),
                ] else ...[
                  const SizedBox(height: 16),
                  Text(
                    "Вы успешно вошли как ${user!.displayName ?? 'Неизвестный пользователь'}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          ListTile(
                            leading: GoogleUserCircleAvatar(identity: user!),
                            title: Text(user?.displayName ?? ''),
                            subtitle: Text(user?.email ?? ''),
                          ),
                          FutureBuilder<GoogleSignInAuthentication>(
                            future: user!.authentication,
                            builder: (context, auth) {
                              if (auth.connectionState == ConnectionState.done && auth.data != null) {
                                WidgetsBinding.instance.addPostFrameCallback((_) => sendJWTToBackend(auth.data!.idToken));
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  googleStyledButton(
                    text: 'Выйти из аккаунта',
                    onPressed: () async {
                      setState(() => loading = true);
                      await googleSignIn.signOut();
                      setState(() => loading = false);
                    },
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
