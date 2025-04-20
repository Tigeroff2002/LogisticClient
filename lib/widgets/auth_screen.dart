import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'user_page.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as web;
import 'header.dart';
import 'footer.dart';
import 'package:flutter/foundation.dart';

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

class _SignInState extends State<SignIn> {
  bool loading = false;
  bool isHovered = false;
  double scale = 1.0;

  GoogleSignIn googleSignIn = GoogleSignIn(
    clientId: "118733131205-uj4ulrnj7b9qjms7n8ba971nj2qn5hab.apps.googleusercontent.com",
    scopes: ['email', 'profile']
  );

  @override
  void initState() {
    super.initState();
    _checkCachedToken();

    googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) async {
      if (account != null) {
        await _handleAuth(account);
      }
    });

    googleSignIn.signInSilently();
  }

  String get apiBaseUrl {
    if (kIsWeb) {
      // В продакшене будет /api
      return const String.fromEnvironment(
        'API_BASE_URL', 
        defaultValue: '/api'  // Изменено на относительный путь
      );
    }
    return 'http://localhost:3500'; // Для локальной разработки
  }


  /// Проверяет, есть ли сохраненный токен
  Future<void> _checkCachedToken() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedToken = prefs.getString('jwt_token');
    final cachedDisplayName = prefs.getString('displayName');
    final cachedEmail = prefs.getString('email');
    final cachedPhotoUrl = prefs.getString('photoUrl');

    if (cachedToken != null && cachedToken.isNotEmpty) {
      final success = await _sendJWTToBackend(cachedToken);
      if (success) {
        _navigateToUserPage(cachedDisplayName, cachedEmail, cachedPhotoUrl);
      }
    }
  }

  /// Обрабатывает аутентификацию после получения аккаунта
  Future<void> _handleAuth(GoogleSignInAccount account) async {
    setState(() => loading = true);
    
    final jwtToken = (await account.authentication).idToken ?? '';
    final success = await _sendJWTToBackend(jwtToken);

    if (success) {
      await _saveUserDataToCache(account, jwtToken);
      _navigateToUserPage(account.displayName, account.email, account.photoUrl);
    } else {
      _showErrorAlert('Ошибка аутентификации');
    }
    
    setState(() => loading = false);
  }

  /// Отправляет JWT на бэкенд и проверяет статус ответа
  Future<bool> _sendJWTToBackend(String jwtToken) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/Users/me'),
        headers: {'Authorization': 'Bearer $jwtToken'},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint('Ошибка сервера: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Ошибка сети: $e');
      return false;
    }
  }

  /// Сохраняет данные пользователя в SharedPreferences
  Future<void> _saveUserDataToCache(GoogleSignInAccount account, String jwtToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', jwtToken);
    await prefs.setString('displayName', account.displayName ?? 'Неизвестный пользователь');
    await prefs.setString('email', account.email);
    await prefs.setString('photoUrl', account.photoUrl ?? '');
  }

  void _navigateToUserPage(String? displayName, String? email, String? photoUrl) {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          settings: RouteSettings(name: '/main'),
          builder: (context) => UserPage(
            displayName: displayName ?? 'Неизвестный пользователь',
            email: email ?? 'Неизвестная почта',
            photoUrl: photoUrl ?? '',
          ),
        ),
      );
    }
  }

  /// Показывает ошибку и перезагружает страницу
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
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const SignIn()),
                );
              },
              child: const Text('ОК'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Фон
          Positioned.fill(
            child: Image.asset(
              'assets/background.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),

          // Контент
          Center(
            child: MouseRegion(
              onEnter: (_) => setState(() {
                isHovered = true;
                scale = 1.1;
              }),
              onExit: (_) => setState(() {
                isHovered = false;
                scale = 1.0;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                transform: Matrix4.identity()..scale(scale),
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: isHovered ? Colors.blue.shade300 : Colors.black.withOpacity(0.2),
                      blurRadius: isHovered ? 20 : 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Добро пожаловать!',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Войдите с помощью Google',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    if (!loading)
                      (GoogleSignInPlatform.instance as web.GoogleSignInPlugin)
                          .renderButton(configuration: web.GSIButtonConfiguration())
                    else
                      const CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
          ),
       // Header
          const Header(),

          // Footer
          const Footer(),
        ],
      ),
    );
  }
}
