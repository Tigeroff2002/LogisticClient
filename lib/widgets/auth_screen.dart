import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logist_client/widgets/footer.dart';
import 'package:logist_client/widgets/header.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as web;

class AuthPage extends StatelessWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const SignIn(),
      ),
    );
  }
}

class SignIn extends StatefulWidget {
  const SignIn({Key? key}) : super(key: key);

  @override
  State<SignIn> createState() => _SignInState();
}

GoogleSignIn googleSignIn = GoogleSignIn(clientId: "118733131205-uj4ulrnj7b9qjms7n8ba971nj2qn5hab.apps.googleusercontent.com");

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

  bool isServerRequested = false; // Запрос был отправлен
  bool isServerOk = false; // Ответ сервера был успешным
  bool isPageReloaded = false; // Проверяем, была ли уже перезагружена страница
  bool isTokenAvailable = false; // Проверка, есть ли токен в SharedPreferences

  @override
  void initState() {
    super.initState();
    _checkCachedToken(); // Check if there's a cached token

    googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) async {
      debugPrint('User changed: $account');
      if (account != null) {
        setState(() {
          user = CustomUser(
            id: account.id,
            displayName: account.displayName ?? 'Неизвестный пользователь',
            email: account.email,
            photoUrl: account.photoUrl ?? '',
          );
        });

        // After user logs in, save data to cache
        _saveUserDataToCache(account);
      } else {
        setState(() {
          user = null;
        });
      }
    });

    googleSignIn.signInSilently(); // Attempt silent sign-in
  }

  Future<void> _checkCachedToken() async {
    // Check if the JWT token is already cached
    final prefs = await SharedPreferences.getInstance();
    final cachedToken = prefs.getString('jwt_token');
    final cachedDisplayName = prefs.getString('displayName');
    final cachedEmail = prefs.getString('email');
    final cachedPhotoUrl = prefs.getString('photoUrl');

    if (cachedToken != null && cachedToken.isNotEmpty) {
      setState(() {
        isTokenAvailable = true;
        // Load user data from cache
        user = CustomUser(
          id: cachedToken,
          displayName: cachedDisplayName ?? 'Неизвестный пользователь',
          email: cachedEmail ?? 'Неизвестная почта',
          photoUrl: cachedPhotoUrl ?? '',
        );
      });
    }
  }

  Future<void> _saveUserDataToCache(GoogleSignInAccount account) async {
    final prefs = await SharedPreferences.getInstance();

    var jwtToken = (await account.authentication).idToken ?? '';

    print('Bearer ' + jwtToken);
    
    await prefs.setString('jwt_token', jwtToken);
    await prefs.setString('displayName', account.displayName ?? 'Неизвестный пользователь');
    await prefs.setString('email', account.email);
    await prefs.setString('photoUrl', account.photoUrl ?? '');
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('displayName');
    await prefs.remove('email');
    await prefs.remove('photoUrl');
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
              onPressed: () {
                Navigator.of(context).pop();
                if (!isPageReloaded) {
                  // Перезагружаем страницу один раз
                  isPageReloaded = true; // Устанавливаем флаг, чтобы не перезагружать страницу снова
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const SignIn()),
                  );
                }
              },
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
      body: Stack(
        children: [
          // Основной контент
          Center(
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
                            (GoogleSignInPlatform.instance as web.GoogleSignInPlugin).renderButton(configuration: web.GSIButtonConfiguration()),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      Text(
                        "Вы успешно вошли как ${user!.displayName}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade400),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundImage: user!.photoUrl.isEmpty
                                  ? const AssetImage('assets/default_avatar.png') // Добавьте дефолтное изображение
                                  : NetworkImage(user!.photoUrl) as ImageProvider,
                              radius: 30,
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user!.displayName,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  user!.email,
                                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      googleStyledButton(
                        text: 'Выйти из аккаунта',
                        onPressed: () async {
                          setState(() => loading = true);
                          await googleSignIn.signOut();
                          await _clearCache();

                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => AuthPage()));  
                          setState(() {
                            loading = false;
                            user = null; // Reset user to null on sign out
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Добавляем Header
          const Header(),

          // Добавляем Footer
          const Footer(),
        ],
      ),
    );
  }
}