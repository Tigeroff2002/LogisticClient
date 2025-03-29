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

  Set<Polyline> _polylines = {};

  bool _isRequestCreated = false;  // Флаг для проверки, был ли создан запрос
  bool _isRequestRecreated = false;  // Флаг для проверки, был ли пересоздан запрос
  int? _requestId;  // ID запроса

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

    void _closeMap() {
    setState(() {
      _isMapVisible = false;
      _isCardVisible = true;
      _markers.clear(); // Очистка маркеров при закрытии карты
      _startPoint = null;
      _endPoint = null;
    });
  }


  // Метод для создания запроса на маршрут
  Future<void> _createRouteRequest() async {
    if (_startPoint != null && _endPoint != null) {
      // Генерация GUID
      String guid = Uuid().v4();

      final prefs = await SharedPreferences.getInstance();
      String? jwtToken = prefs.getString('jwt_token');

      if (jwtToken == null) {
        debugPrint("Ошибка: Не найден токен.");
        return;
      }

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
          _requestId = responseJson['request_id'];
          debugPrint('Запрос успешно создан. Request ID: $_requestId');

          // Убираем кнопку "Создать запрос" и показываем кнопку "Пересоздать запрос"
          setState(() {
            _isRequestCreated = true;
          });

          // Получаем информацию о запросе
          await _getRequestData(_requestId!);
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

   Future<void> _recreateRouteRequest() async {
    if (_requestId != null) {
      final prefs = await SharedPreferences.getInstance();
      String? jwtToken = prefs.getString('jwt_token');

      if (jwtToken == null) {
        debugPrint("Ошибка: Не найден токен.");
        return;
      }

      try {
        final response = await http.patch(
          Uri.parse('https://localhost:7247/Requests/recreate?requestId=$_requestId'),
          headers: {
            'Authorization': 'Bearer $jwtToken',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          debugPrint('Запрос успешно пересоздан');

          // Получаем информацию о пересозданном запросе
          await _getRequestData(_requestId!);

          setState(() {
            _isRequestRecreated = true;
            // Убираем кнопки пересоздать и создать запрос
          });
        } else {
          debugPrint('Ошибка пересоздания запроса: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Ошибка сети: $e');
      }
    }
  }

 Future<void> _cancelRequest() async {
    if (_requestId != null) {
      final prefs = await SharedPreferences.getInstance();
      String? jwtToken = prefs.getString('jwt_token');

      if (jwtToken == null) {
        debugPrint("Ошибка: Не найден токен.");
        return;
      }

      try {
        final response = await http.post(
          Uri.parse('https://localhost:7247/Requests/change_status'),
          headers: {
            'Authorization': 'Bearer $jwtToken',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'request_id': _requestId,
            'new_status': 'closed',
          }),
        );

        if (response.statusCode == 200) {
          debugPrint('Запрос успешно отменен');

          // Закрытие карты и сброс состояния
          setState(() {
            _isMapVisible = false;
            _isRequestCreated = false;
            _isRequestRecreated = false;
            _requestId = null;
            _markers.clear();
            _polylines.clear();
            _startPoint = null;
            _endPoint = null;
          });
        } else {
          debugPrint('Ошибка отмены запроса: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Ошибка сети: $e');
      }
    }
  }

    void _toggleMapVisibility() {
    setState(() {
      _isMapVisible = !_isMapVisible;
      _isCardVisible = !_isMapVisible; // Скрываем маленькую карточку
    });
  }

  // Метод для получения данных запроса (маршрута)
  Future<void> _getRequestData(int requestId) async {
    final prefs = await SharedPreferences.getInstance();
    String? jwtToken = prefs.getString('jwt_token');

    if (jwtToken == null) {
      debugPrint("Ошибка: Не найден токен.");
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://localhost:7247/Requests?requestId=$requestId&isActive=false'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        }
      );

      if (response.statusCode == 200) {
        debugPrint('Запрос обработан успешно.');

        final responseJson = json.decode(response.body);
        List<dynamic> segments = responseJson['initial_segments'];
        Set<Polyline> newPolylines = {};

        for (var segment in segments) {
          LatLng start = LatLng(
            segment['coords_range']['start_coord']['width'],
            segment['coords_range']['start_coord']['heigth'],
          );

          LatLng end = LatLng(
            segment['coords_range']['end_coord']['width'],
            segment['coords_range']['end_coord']['heigth'],
          );

          newPolylines.add(
            Polyline(
              polylineId: PolylineId(segment['id'].toString()),
              points: [start, end],
              color: Colors.blue,
              width: 5,
            ),
          );
        }

        setState(() {
          _polylines = newPolylines;
        });

      } else {
        debugPrint('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Ошибка сети: $e');
    }
  }

  // Переход на страницу ЛК
  void _navigateToLK(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LkPage()),
    );
  }

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
        SingleChildScrollView(
          child: Column(
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

              // Если запрос создан, показываем кнопки
              if (_isRequestCreated && !_isRequestRecreated)
                ElevatedButton(
                  onPressed: _recreateRouteRequest,
                  child: const Text('Пересоздать маршрут'),
                ),

              if (_isRequestRecreated)
                ElevatedButton(
                  onPressed: _cancelRequest,
                  child: const Text('Отменить запрос'),
                ),

              const SizedBox(height: 20),

              // Если карта видима, показываем контейнер с картой
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
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _closeMap,
                          ),
                        ),
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
                            myLocationEnabled: true,
                            polylines: _polylines,
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

