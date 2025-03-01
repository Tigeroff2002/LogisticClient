import 'package:flutter/material.dart';
import 'package:logist_client/widgets/home_page.dart';
import 'package:logist_client/widgets/auth_screen.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

GoogleSignInPlatform.instance = GoogleSignInPlatform.instance;

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Сервис маршрутов',
      theme: ThemeData(
        primarySwatch: Colors.lightGreen,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => HomePage(),
        '/login': (context) => AuthPage()
      }
      );
  }
}