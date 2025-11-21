import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'header.dart';
import 'footer.dart';
import 'package:logist_client/widgets/lk_page.dart';
import 'package:logist_client/widgets/auth_screen.dart';
import 'package:logist_client/widgets/request_page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:js' as js;

class UserPage extends StatefulWidget {
    final String displayName;
    final String email;
    final String photoUrl;

    const UserPage({
      Key? key,
      required this.displayName,
      required this.email,
      required this.photoUrl,
    }) : super(key: key);

    @override
    _UserPageState createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {

    bool _isCardHovered = false;

    String get apiBaseUrl {
      return js.context['env']['API_BASE_URL'] ?? 'https://localhost:7247';
    }

    List<dynamic> userRequests = List.empty();

    @override
    void initState() {
      super.initState();
      getUserRequests();
    }

    @override
    void dispose() {
      super.dispose();
    }

    void _navigateToLK(BuildContext context) {
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: RouteSettings(name: '/lk'),
          builder: (context) => const LkPage()),
      );
    }

    Future<void> _signOut(BuildContext context) async {
      await GoogleSignIn().signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          settings: RouteSettings(name: '/login'),
          builder: (context) => const AuthPage()),
      );
    }

    Future<void> getUserRequests() async {
      final prefs = await SharedPreferences.getInstance();
      String? jwtToken = prefs.getString('jwt_token');

      if (jwtToken == null) {
        debugPrint("Ошибка: Не найден токен.");
      }

      try {
        final response = await http.get(
          Uri.parse('$apiBaseUrl/Requests/all'),
          headers: {
            'Authorization': 'Bearer $jwtToken',
            'Content-Type': 'application/json',
          }
        );

        if (response.statusCode == 200) {
          debugPrint('Запрос обработан успешно.');

          final responseJson = json.decode(response.body);
          List<dynamic> requests = responseJson['previews'];

          setState(() {
            userRequests = requests;
          });
        } 
        else if(response.statusCode == 400){
          debugPrint('Ошибка сервера: ${response.body}');
        }
        else {
          debugPrint('Ошибка сервера: ${response.body}');
        }
      } catch (e) {
        debugPrint('Ошибка сети: $e');
      }
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

        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              userRequests.length == 0
                  ? Text(
                      'Вы пока не создали ни одного маршрута',
                      style: TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                          fontSize: 20),
                      textAlign: TextAlign.center)
                  : Expanded(
                      child: ListView.builder(
                        itemCount: userRequests.length,
                        itemBuilder: (context, index) {
                          final request = userRequests[index];
                          
                          return Card(
                            margin: EdgeInsets.all(8.0),
                            elevation: 2.0,
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ID запроса: ${request['request_id']}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),

                                  ElevatedButton(
                                    child: Text(
                                      'Просмотреть запрос',
                                      style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.deepPurple),
                                    ),
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          settings: RouteSettings(name: '/request'),
                                          builder: (context) => RequestPage(requestId: request['request_id']),
                                        ),
                                      );
                                    },
                                  ),                              
                                  Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(request['status']),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Статус: ${request['status']}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Создан: ${request['creation_date']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    'Обновлен: ${request['last_update']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                MouseRegion(
                  onEnter: (_) {
                    setState(() {
                      _isCardHovered = true;
                    });
                  },
                  onExit: (_) {
                    setState(() {
                      _isCardHovered = false;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _isCardHovered ? 380 : 350,
                    height: _isCardHovered ? 220 : 200,
                    decoration: BoxDecoration(
                      color: _isCardHovered ? Colors.blue.withOpacity(0.3) : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, fixedSize: Size(270, 120)),
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              settings: RouteSettings(name: '/request'),
                              builder: (context) => RequestPage(requestId: 0),
                            ),
                          );
                        },
                        child: const Text('Создать новый маршрут', style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          top: 50,
          right: 20,
          child: Column(
            children: [
              CircleAvatar(
                backgroundImage: widget.photoUrl.isNotEmpty
                    ? NetworkImage(widget.photoUrl)
                    : const AssetImage('assets/default_avatar.png') as ImageProvider,
                radius: 30,
              ),
              const SizedBox(height: 10),
              Text(
                widget.displayName,
                style: const TextStyle(color: Colors.white),
              ),
              ElevatedButton(
                onPressed: () => _navigateToLK(context),
                child: const Text("Войти в ЛК"),
              ),
              SizedBox(height: 10.0),
              ElevatedButton(
                onPressed: () => _signOut(context),
                child: const Text("Выйти"),
              ),
            ],
          ),
        ),

        const Header(),
        const Footer(),
      ],
    ),
  );
  }

    Color _getStatusColor(String status) {
      switch (status) {
        case 'created':
          return Colors.tealAccent;
        case 'calculated':
          return Colors.cyan;
        case 'accepted':
          return Colors.lightGreen;
        case 'followed':
          return Colors.orange;
        case 'unfollowed':
          return Colors.orangeAccent;
        case 'closed':
          return Colors.black;
        default:
          return Colors.grey;
      }
  }
}