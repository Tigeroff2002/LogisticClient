import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:js' as js;

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'openid']
  );

  Future<void> signInWithGoogle() async {
    try {
      // Ensure Google API client is initialized
      await _initializeGapiClient();

      // Start Google Sign-In process
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // User canceled sign-in

      print('Google User: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      print('Access token: ${googleAuth.accessToken}');

      print('Id token: ${googleAuth.idToken}');

      // Send JWT token to server
      final response = await http.get(
        Uri.parse('https://localhost:7247/Users/me'),
        headers: {
          'Authorization': 'Bearer ${googleAuth.idToken}',
        },
      );

      // Handle server response
      if (response.statusCode == 200) {
        final Map<String, dynamic> userData = json.decode(response.body);
        final int id = userData['id'];
        final String email = userData['email'];
        final String role = userData['role'];

        print('Успешный вход: ID=$id, Email=$email, Role=$role');
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String failureMessage = errorData['failure_message'];
        print('Ошибка: $failureMessage');
        _showErrorAlert(failureMessage);
      } else {
        print('Неизвестная ошибка: ${response.statusCode}');
        _showErrorAlert('Неизвестная ошибка: ${response.statusCode}');
      }
    } catch (e) {
      print('Ошибка аутентификации: $e');
      _showErrorAlert('Ошибка аутентификации: $e');
    }
  }

  Future<void> _initializeGapiClient() async {
    Completer<void> completer = Completer<void>();

    js.context.callMethod('gapi.load', [
      'auth2',
      js.allowInterop(() {
        js.context.callMethod('gapi.auth2.init', [
          {
            'client_id': '666431505457-ca1mgtqrli0nqv9r87ek40elo4bqe0lk.apps.googleusercontent.com',
          }
        ]);
        completer.complete();
      })
    ]);

    return completer.future;
  }

  void _showErrorAlert(String message) {
    print('Показать алерт: $message');
  }
}