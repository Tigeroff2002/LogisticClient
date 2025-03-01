import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logist_client/shared_pref_cached_data.dart';
import 'package:logist_client/widgets/auth_screen.dart';

class HomePage extends StatelessWidget {
  final String pictureUrlPart1 =
      'https://ssl.gstatic.com/calendar/images/dynamiclogo_2020q4/calendar_';

  final String pictureUrlPart2 = '_2x.png';

  @override
  Widget build(BuildContext context) {

    var monthDayNumber = DateTime.now().day.toString();
    var pictureUrl = pictureUrlPart1 + monthDayNumber + pictureUrlPart2;

    return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(scaffoldBackgroundColor: Colors.white60),
        home: Scaffold(
          appBar: AppBar(
              title: Text(
                'Сервис маршрутов',
                style: TextStyle(fontSize: 16, color: Colors.deepPurple),
              ),
              backgroundColor: Colors.cyan,
              centerTitle: true),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => AuthPage()));
                  },
                  child: Text(
                    'Запуск приложения',
                    style: TextStyle(fontSize: 16, color: Colors.deepPurple),
                  ),
                ),
                SizedBox(height: 40.0),
                GestureDetector(
                    child: Image.network(
                  pictureUrl,
                  cacheWidth: 100,
                  cacheHeight: 100,
                )),
                SizedBox(height: 20.0)
              ],
            ),
          ),
        ));
  }
}
