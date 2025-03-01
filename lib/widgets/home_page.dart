import 'package:flutter/material.dart';
import 'package:logist_client/widgets/auth_screen.dart';
import 'header.dart';
import 'footer.dart';

class HomePage extends StatelessWidget {

   final String pictureUrlPart1 =
      'https://ssl.gstatic.com/calendar/images/dynamiclogo_2020q4/calendar_';

  final String pictureUrlPart2 = '_2x.png';

  @override
  Widget build(BuildContext context) {

    var monthDayNumber = DateTime.now().day.toString();
    var pictureUrl = pictureUrlPart1 + monthDayNumber + pictureUrlPart2;

    return Scaffold(
      body: Stack(
        children: [
          // Ваш контент
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () 
                  {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => AuthPage()));                    
                  },
                  child: const Text(
                    'Запуск приложения',
                    style: TextStyle(fontSize: 16, color: Colors.deepPurple),
                  ),
                ),
                const SizedBox(height: 40.0),
                GestureDetector(
                    child: Image.network(
                  pictureUrl,
                  cacheWidth: 100,
                  cacheHeight: 100,
                )),
                SizedBox(height: 20.0)
                // Дополнительный контент
              ],
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

