import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logist_client/global_endpoints.dart';
import 'package:logist_client/models/host_model.dart';
import 'package:logist_client/shared_pref_cached_data.dart';
import 'package:logist_client/widgets/home_page.dart';
import 'package:logist_client/widgets/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  MySharedPreferences sharedPreferences = new MySharedPreferences();

  var existedData = await sharedPreferences.getDataIfNotExpired();

  if (existedData == null) {
    var currentUri = GlobalEndpoints().mobileUri;

    var hostModel = new HostModel(currentHost: currentUri);

    var json = hostModel.toJson();

    await sharedPreferences.saveDataWithExpiration(
        jsonEncode(json), const Duration(days: 7));
  }

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
        '/login': (context) => AuthScreen()
      }
      );
  }
}