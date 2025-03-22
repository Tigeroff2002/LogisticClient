import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'header.dart';
import 'footer.dart';
import 'package:logist_client/widgets/lk_page.dart'; // Импорт страницы ЛК
import 'package:logist_client/widgets/auth_screen.dart';

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
  late GoogleMapController _mapController;
  Set<Marker> _markers = Set();
  LatLng? _startPoint;
  LatLng? _endPoint;

  double _vladimirWidth = 56.1296;
  double _vladimirHeight = 40.4093;

  bool _isMapVisible = false;
  bool _isCardVisible = true;
  bool _isCardHovered = false;

  // Метод для обработки клика по карте
  void _onMapTapped(LatLng position) {
    setState(() {
      // Если обе точки уже выбраны, очищаем маркеры и начинаем заново
      if (_startPoint != null && _endPoint != null) {
        _markers.clear();
        _startPoint = null;
        _endPoint = null;
      }

      // Если начальная точка еще не выбрана
      if (_startPoint == null) {
        _startPoint = position;
        _markers.add(Marker(
          markerId: MarkerId('start'),
          position: _startPoint!,
          infoWindow: InfoWindow(title: 'Начальная точка'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen), // Зеленый маркер
        ));
      }
      // Если конечная точка еще не выбрана
      else if (_endPoint == null) {
        _endPoint = position;
        _markers.add(Marker(
          markerId: MarkerId('end'),
          position: _endPoint!,
          infoWindow: InfoWindow(title: 'Конечная точка'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed), // Красный маркер
        ));
      }
    });
  }

  // Метод для закрытия карты
  void _closeMap() {
    setState(() {
      _isMapVisible = false;
      _isCardVisible = true;
      _markers.clear(); // Очистка маркеров при закрытии карты
      _startPoint = null;
      _endPoint = null;
    });
  }

  // Метод для создания запроса на маршрут с координатами
  Future<void> _createRouteRequest() async {
    if (_startPoint != null && _endPoint != null) {
      // Генерация GUID
      String guid = Uuid().v4();

      // Получаем токен из SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      String? jwtToken = prefs.getString('jwt_token');

      if (jwtToken == null) {
        debugPrint("Ошибка: Не найден токен.");
        return;
      }

      // Формирование тела запроса
      final Map<String, dynamic> requestBody = {
        "guid": guid,
        "coords_range": {
          "start_coord": {
            "width": _startPoint!.latitude,
            "heigth": _startPoint!.longitude,
          },
          "end_coord": {
            "width": _endPoint!.latitude,
            "heigth": _endPoint!.longitude,
          },
        },
      };

      try {
        final response = await http.post(
          Uri.parse('https://localhost:7247/Requests/create'),
          headers: {
            'Authorization': 'Bearer $jwtToken',
            'Content-Type': 'application/json',
          },
          body: json.encode(requestBody),
        );

        if (response.statusCode == 200) {
          final responseJson = json.decode(response.body);
          int requestId = responseJson['request_id'];
          debugPrint('Запрос успешно создан. Request ID: $requestId');

          // Теперь отправляем GET запрос с полученным requestId
          await _getRequestStatus(requestId);
        } else {
          debugPrint('Ошибка сервера: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Ошибка сети: $e');
      }
    } else {
      debugPrint('Ошибка: Нужно выбрать обе точки!');
    }
  }

  void _toggleMapVisibility() {
    setState(() {
      _isMapVisible = !_isMapVisible;
      _isCardVisible = !_isMapVisible; // Скрываем маленькую карточку
    });
  }

  Future<void> _getRequestStatus(int requestId) async {
    // Получаем токен из SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    String? jwtToken = prefs.getString('jwt_token');

    if (jwtToken == null) {
      debugPrint("Ошибка: Не найден токен.");
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://localhost:7247/Requests?requestId=${requestId}&isActive=false'),
          headers: {
            'Authorization': 'Bearer $jwtToken',
            'Content-Type': 'application/json',
          }
      );

      if (response.statusCode == 200) {
        debugPrint('Запрос обработан успешно.');
      } else if (response.statusCode == 400) {
        final responseJson = json.decode(response.body);
        String failureMessage = responseJson['failure_message'];
        debugPrint('Ошибка запроса: $failureMessage');
        _showFailureMessage(failureMessage);
      } else {
        debugPrint('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Ошибка сети: $e');
    }
  }

  void _showFailureMessage(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Ошибка'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  // Переход на страницу ЛК
  void _navigateToLK(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LkPage()),
    );
  }

  // Метод для выхода
  Future<void> _signOut(BuildContext context) async {
    await GoogleSignIn().signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthPage()),
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Стартовая анимированная карточка с кнопкой
                if (_isCardVisible)
                  MouseRegion(
                    onEnter: (_) {
                      setState(() {
                        _isCardHovered = true; // Карточка увеличивается при наведении
                      });
                    },
                    onExit: (_) {
                      setState(() {
                        _isCardHovered = false; // Карточка возвращается к нормальному состоянию
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _isCardHovered ? 380 : 350, // Увеличение карточки
                      height: _isCardHovered ? 220 : 200, // Увеличение карточки
                      decoration: BoxDecoration(
                        color: _isCardHovered ? Colors.blue.withOpacity(0.3) : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: ElevatedButton(
                          onPressed: _toggleMapVisibility,
                          child: const Text('Создать запрос на маршрут'),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // Если флаг _isMapVisible true, показываем большую карту с формой и кнопкой
                if (_isMapVisible)
                  Center(
                    child: Container(
                      width: 600, // Увеличиваем размеры карты
                      height: 800,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Крестик для закрытия карты
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _closeMap,
                            ),
                          ),
                          // Карта
                          Expanded(
                            child: GoogleMap(
                              onMapCreated: (GoogleMapController controller) {
                                _mapController = controller;
                              },
                              initialCameraPosition: CameraPosition(
                                target: LatLng(_vladimirWidth, _vladimirHeight),
                                zoom: 10,
                              ),
                              markers: _markers,
                              onTap: _onMapTapped,
                              trafficEnabled: true,
                              myLocationEnabled: true,
                            ),
                          ),
                          // Форма для начальной и конечной точки
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                // Начальная точка
                                Row(
                                  children: [
                                    Text(
                                      'Начальная точка: ',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                    Text(
                                      _startPoint != null
                                          ? '${_startPoint!.latitude}, ${_startPoint!.longitude}'
                                          : 'Пусто',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                    if (_startPoint != null)
                                      Icon(
                                        Icons.circle,
                                        color: Colors.green, // Зеленый цвет для начальной точки
                                        size: 15,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Конечная точка
                                Row(
                                  children: [
                                    Text(
                                      'Конечная точка: ',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                    Text(
                                      _endPoint != null
                                          ? '${_endPoint!.latitude}, ${_endPoint!.longitude}'
                                          : 'Пусто',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                    if (_endPoint != null)
                                      Icon(
                                        Icons.circle,
                                        color: Colors.red, // Красный цвет для конечной точки
                                        size: 15,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Кнопка для создания маршрута
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ElevatedButton(
                              onPressed: _startPoint != null && _endPoint != null ? _createRouteRequest : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _startPoint != null && _endPoint != null ? Colors.red : Colors.grey,
                              ),
                              child: const Text('Создать запрос на маршрут'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Профиль в правом верхнем углу
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
}
