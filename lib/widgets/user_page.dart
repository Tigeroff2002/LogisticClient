import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'header.dart';
import 'footer.dart';
import 'package:logist_client/widgets/lk_page.dart';
import 'package:logist_client/widgets/auth_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
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
  late GoogleMapController _mapController;
  Set<Marker> _markers = Set();
  LatLng? _startPoint;
  LatLng? _endPoint;

  LatLng? _currentPoint;

  Position? _currentPosition;
  Stream<Position>? _positionStream;
  StreamSubscription<Position>? _positionSubscription;

  double _vladimirWidth = 56.1296;
  double _vladimirHeight = 40.4093;

  bool _isMapVisible = false;
  bool _isCardVisible = true;
  bool _isCardHovered = false;

  Set<Polyline> _polylines = {};

  bool _isRequestCreated = false; 
  bool _isRequestRecreated = false;
  bool _isRequestAccepted = false;
  bool _isRequestFollowed = false;
  bool _isRequestUnfollowed = false;
  int? _requestId;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

      String get apiBaseUrl {
      return js.context['env']['API_BASE_URL'] ?? 'https://localhost:7247';
    }


  Future<void> _initLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    _currentPosition = await Geolocator.getCurrentPosition();
    print("Текущая позиция: $_currentPosition");

    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Обновлять каждые 10 метров
      ),
    );

    _positionSubscription = _positionStream!.listen((Position position) async {
      setState((){
        _currentPosition = position;
      });

      if (_isRequestFollowed){
        await _handlePositionChange(position);
        print("Текущая позиция обновлена по следованию: $position");        
      }
      else{
        print("Текущая позиция необновлена - так как пользователь не на маршруте: $position");  
      }     
    });
}

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

    Future<void> _handlePositionChange(Position position) async {
      print("Отправка координат на сервер: ${position.latitude}, ${position.longitude}");

      final prefs = await SharedPreferences.getInstance();
      String? jwtToken = prefs.getString('jwt_token');

      if (jwtToken == null) {
        debugPrint("Ошибка: Не найден токен.");
        return;
      }

      final Map<String, dynamic> requestBody = {
        "request_id": _requestId!,
        "old_coord": {
            "width": _currentPoint == null ? _startPoint!.latitude : _currentPoint!.latitude,
            "heigth": _currentPoint == null ? _startPoint!.longitude : _currentPoint!.longitude,
        },
        "new_coord": {
            "width": position.latitude,
            "heigth": position.longitude,
        }
      };

      try {
        final response = await http.post(
          Uri.parse('$apiBaseUrl/Requests/move_user'),
          headers: {
            'Authorization': 'Bearer $jwtToken',
            'Content-Type': 'application/json',
          },
          body: json.encode(requestBody)
        );

        if (response.statusCode == 200) {
          debugPrint('Сервер воспринял обновление координат');

          setState(() {
            _currentPoint = LatLng(position.latitude, position.longitude);

            _markers.clear();

            _markers.add(Marker(
              markerId: MarkerId('current'),
              position: _currentPoint!,
              infoWindow: InfoWindow(title: 'Текущая точка'),
              icon: BitmapDescriptor.defaultMarker, // Красный маркер
            ));

            _markers.add(Marker(
              markerId: MarkerId('end'),
              position: _endPoint!,
              infoWindow: InfoWindow(title: 'Конечная точка'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed), // Красный маркер
            ));
          });
        } else {
          debugPrint('Ошибка отмены запроса: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Ошибка сети: $e');
      }
    }

    void _onMapTapped(LatLng position) {
      setState(() {
        // Если обе точки уже выбраны, очищаем маркеры и начинаем заново
        if (_startPoint != null && _endPoint != null) {
          _markers.clear();
          _startPoint = null;
          _endPoint = null;
          _currentPoint = null;
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
        _currentPoint = null;
        _currentPoint = null;
        _isRequestCreated = false;
        _isRequestRecreated = false;
        _isRequestAccepted = false;
        _isRequestFollowed = false;
        _isRequestUnfollowed = false;
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
          Uri.parse('$apiBaseUrl/Requests/create/simple'),
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
          Uri.parse('$apiBaseUrl/Requests/recreate?requestId=$_requestId'),
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

   Future<void> _acceptRequest() async {
    if (_requestId != null) {
      final prefs = await SharedPreferences.getInstance();
      String? jwtToken = prefs.getString('jwt_token');

      if (jwtToken == null) {
        debugPrint("Ошибка: Не найден токен.");
        return;
      }

      try {
        final response = await http.post(
          Uri.parse('$apiBaseUrl/Requests/change_status'),
          headers: {
            'Authorization': 'Bearer $jwtToken',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'request_id': _requestId,
            'new_status': 'accepted',
          }),
        );

        if (response.statusCode == 200) {
          debugPrint('Запрос успешно принят');

          setState(() {
            _isRequestAccepted = true;
          });
        } else {
          debugPrint('Ошибка отмены запроса: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Ошибка сети: $e');
      }
    }
  }

   Future<void> _followRequest() async {
    if (_requestId != null) {
      final prefs = await SharedPreferences.getInstance();
      String? jwtToken = prefs.getString('jwt_token');

      if (jwtToken == null) {
        debugPrint("Ошибка: Не найден токен.");
        return;
      }

      try {
        final response = await http.post(
          Uri.parse('$apiBaseUrl/Requests/change_status'),
          headers: {
            'Authorization': 'Bearer $jwtToken',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'request_id': _requestId,
            'new_status': 'followed',
          }),
        );

        if (response.statusCode == 200) {
          debugPrint('Следование по машруту запущено');

          setState(() {
            _isRequestFollowed = true;
          });
        } else {
          debugPrint('Ошибка отмены запроса: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Ошибка сети: $e');
      }
    }
  }

   Future<void> _unfollowRequest() async {
    if (_requestId != null) {
      final prefs = await SharedPreferences.getInstance();
      String? jwtToken = prefs.getString('jwt_token');

      if (jwtToken == null) {
        debugPrint("Ошибка: Не найден токен.");
        return;
      }

      try {
        final response = await http.post(
          Uri.parse('$apiBaseUrl/Requests/change_status'),
          headers: {
            'Authorization': 'Bearer $jwtToken',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'request_id': _requestId,
            'new_status': 'unfollowed',
          }),
        );

        if (response.statusCode == 200) {
          debugPrint('Следование по машруту приостановлено');

          setState(() {
            _isRequestFollowed = false;
            _isRequestUnfollowed = true;
          });
        } else {
          debugPrint('Ошибка отмены запроса: ${response.statusCode}');
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
          Uri.parse('$apiBaseUrl/Requests/change_status'),
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

          setState(() {
            _isMapVisible = false;
            _isRequestCreated = false;
            _isRequestRecreated = false;
            _isRequestAccepted = false;
            _isRequestFollowed = false;
            _isRequestUnfollowed = false;
            _requestId = null;
            _markers.clear();
            _polylines.clear();
            _startPoint = null;
            _endPoint = null;
            _currentPoint = null;
            _isCardVisible = true;
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
        Uri.parse('$apiBaseUrl/Requests?requestId=$requestId&isActive=false'),
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
              if (_isCardVisible)
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
                        onPressed: _toggleMapVisibility,
                        child: const Text('Создать запрос на маршрут', style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ),
                ),

              if (_isMapVisible)
                Center(
                  child: Container(
                    width: 600, 
                    height: 700,
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
                        SizedBox(height: 10.0),
                        if (!_isRequestCreated)
                          Text(
                            'Создание маршрута - выберите 2 точки',
                            style: TextStyle(color: Colors.blueAccent, fontSize: 18)),
                        if (_isRequestAccepted && !_isRequestFollowed && !_isRequestUnfollowed)
                          Text(
                            'Маршрут принят и сохранен в ЛК',
                            style: TextStyle(color: Colors.blueAccent, fontSize: 18)),
                        if (_isRequestFollowed && !_isRequestUnfollowed)
                          Text(
                            'Пользователь начал следовать по маршруту',
                            style: TextStyle(color: Colors.blueAccent, fontSize: 18)),
                        if (!_isRequestFollowed && _isRequestUnfollowed)
                          Text(
                            'Пользователь приостановил следование по маршруту',
                            style: TextStyle(color: Colors.blueAccent, fontSize: 18)),
                        if (_isRequestFollowed && _isRequestUnfollowed)
                          Text(
                            'Пользователь возобновил следование по маршруту',
                            style: TextStyle(color: Colors.blueAccent, fontSize: 18)),
                        if (_isRequestCreated && !_isRequestRecreated && !_isRequestAccepted)
                          Text(
                            'Маршрут создан - можете пересоздать',
                            style: TextStyle(color: Colors.blueAccent, fontSize: 18)),
                        if (_isRequestRecreated)
                          Text(
                            'Маршрут пересоздан - можете отменить',
                            style: TextStyle(color: Colors.blueAccent, fontSize: 18)),
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
                              zoom: 13,
                            ),
                            markers: _markers,
                            onTap: _onMapTapped,
                            myLocationEnabled: true,
                            polylines: _polylines,
                          ),
                        ),
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
                                 const SizedBox(height: 5),
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
                                SizedBox(height: 5.0),
                                if (!_isRequestCreated)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ElevatedButton(
                                    onPressed: _startPoint != null && _endPoint != null ? _createRouteRequest : null,
                                    child: const Text('Создать запрос на маршрут'))),
                                if (_isRequestCreated && !_isRequestAccepted)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ElevatedButton(
                                    onPressed: _acceptRequest,
                                    child: const Text('Принять маршрут'))),
                                if (_isRequestAccepted && !_isRequestFollowed && !_isRequestUnfollowed)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ElevatedButton(
                                    onPressed: _followRequest,
                                    child: const Text('Начать следовать по маршруту'))),
                                if (_isRequestFollowed)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ElevatedButton(
                                    onPressed: _unfollowRequest,
                                    child: const Text('Приостановить следование по маршруту'))),
                                if (!_isRequestFollowed && _isRequestUnfollowed)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ElevatedButton(
                                    onPressed: _followRequest,
                                    child: const Text('Возобновить следование по маршруту'))),
                                if (_isRequestCreated && !_isRequestRecreated && !_isRequestAccepted)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ElevatedButton(
                                    onPressed: _startPoint != null && _endPoint != null ? _recreateRouteRequest : null,
                                    child: const Text('Пересоздать маршрут'))),
                                SizedBox(height: 8.0),
                                if (_isRequestCreated && (_isRequestRecreated || _isRequestAccepted))
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ElevatedButton(
                                    onPressed: _cancelRequest,
                                    child: const Text('Отменить запрос'))),                       
                               ],
                             ))                       
                      ],
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
}