import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_page.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as web;

class AuthPage extends StatelessWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SignIn(),
    );
  }
}

class SignIn extends StatefulWidget {
  const SignIn({Key? key}) : super(key: key);

  @override
  State<SignIn> createState() => _SignInState();
}

class CustomUser {
  final String id;
  final String displayName;
  final String email;
  final String photoUrl;

  CustomUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.photoUrl,
  });
}

class _SignInState extends State<SignIn> {
  bool loading = false;
  CustomUser? user;
  bool isTokenAvailable = false;

  GoogleSignIn googleSignIn = GoogleSignIn(
    clientId: "118733131205-uj4ulrnj7b9qjms7n8ba971nj2qn5hab.apps.googleusercontent.com",
  );

  @override
  void initState() {
    super.initState();
    _checkCachedToken();
    
    googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) async {
      if (account != null) {
        await _saveUserDataToCache(account);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => UserPage(
                displayName: account.displayName ?? 'Неизвестный пользователь',
                email: account.email,
                photoUrl: account.photoUrl ?? '',
              ),
            ),
          );
        }
      }
    });

    googleSignIn.signInSilently();
  }

  Future<void> _checkCachedToken() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedToken = prefs.getString('jwt_token');
    final cachedDisplayName = prefs.getString('displayName');
    final cachedEmail = prefs.getString('email');
    final cachedPhotoUrl = prefs.getString('photoUrl');

    if (cachedToken != null && cachedToken.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => UserPage(
            displayName: cachedDisplayName ?? 'Неизвестный пользователь',
            email: cachedEmail ?? 'Неизвестная почта',
            photoUrl: cachedPhotoUrl ?? '',
          ),
        ),
      );
    }
  }

  Future<void> _saveUserDataToCache(GoogleSignInAccount account) async {
    final prefs = await SharedPreferences.getInstance();
    var jwtToken = (await account.authentication).idToken ?? '';

    await prefs.setString('jwt_token', jwtToken);
    await prefs.setString('displayName', account.displayName ?? 'Неизвестный пользователь');
    await prefs.setString('email', account.email);
    await prefs.setString('photoUrl', account.photoUrl ?? '');
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 55,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade600),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.network(
              'https://upload.wikimedia.org/wikipedia/commons/2/2f/Google_2015_logo.svg',
              height: 24,
            ),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
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
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading) const LinearProgressIndicator(),
                if (user == null) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Войти с помощью Google',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        (GoogleSignInPlatform.instance as web.GoogleSignInPlugin)
                            .renderButton(configuration: web.GSIButtonConfiguration()),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}