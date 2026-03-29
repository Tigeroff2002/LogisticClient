import 'package:flutter/material.dart';
import 'package:logist_client/widgets/request_page.dart';
import 'package:logist_client/widgets/request_page.user_state_mixin.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logist_client/models/RequestStatus.dart';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;
import 'package:signalr_netcore/signalr_client.dart';

mixin RequestPageRequestManager on State<RequestPage> implements RequestStateBaseMixin
{
  bool isMapVisible = false;
  bool isCardVisible = true;
  HubConnection? _hubConnection;
  int? _currentRequestId;

  Future<void> initializeSignalR() async {
    final prefs = await SharedPreferences.getInstance();
    String? jwtToken = prefs.getString('jwt_token');
    
    if (jwtToken == null) {
      debugPrint("Ошибка: Не найден токен для SignalR");
      return;
    }

    _hubConnection = HubConnectionBuilder()
        .withUrl('https://localhost:7247/logistic',
            options: HttpConnectionOptions(
              accessTokenFactory: () => Future.value(jwtToken),
              transport: HttpTransportType.LongPolling, // <-- ключевое изменение
              skipNegotiation: false,
            ))
        .build();
        
    // _hubConnection!.onclose(({Exception? exception}) {
    //   debugPrint('SignalR соединение закрыто: $exception');
    // });

    try {
      await _hubConnection!.start();
      debugPrint('SignalR подключен! Connection ID: ${_hubConnection!.connectionId}');
      
      _setupSignalRHandlers();
    } catch (e) {
      debugPrint('Ошибка подключения SignalR: $e');
    }
  }

  void _setupSignalRHandlers() {
    debugPrint('Настройка обработчиков SignalR...');
    
      _hubConnection!.on('RequestPartCalculated', (arguments) {
        debugPrint('Получено событие RequestPartCalculated, arguments: $arguments');

        if (arguments != null && arguments.isNotEmpty) {
          final raw = arguments[0];

          try {
            Map<String, dynamic> eventData;

            if (raw is String) {
              // 👉 если это JSON строка
              eventData = json.decode(raw);
            } else if (raw is Map) {
              // 👉 если это уже Map (бывает в SignalR)
              eventData = Map<String, dynamic>.from(raw);
            } else {
              debugPrint('Неожиданный тип данных: ${raw.runtimeType}');
              return;
            }

            _handleRequestPartCalculated(eventData);
          } catch (e) {
            debugPrint('Ошибка парсинга: $e');
          }
        }
      });

      _hubConnection!.on('RequestCalculated', (arguments) {
        debugPrint('Получено событие RequestCalculated, arguments: $arguments');

        if (arguments != null && arguments.isNotEmpty) {
          final raw = arguments[0];

          try {
            Map<String, dynamic> eventData;

            if (raw is String) {
              // 👉 если это JSON строка
              eventData = json.decode(raw);
            } else if (raw is Map) {
              // 👉 если это уже Map (бывает в SignalR)
              eventData = Map<String, dynamic>.from(raw);
            } else {
              debugPrint('Неожиданный тип данных: ${raw.runtimeType}');
              return;
            }

            _handleRequestCalculated(eventData);
          } catch (e) {
            debugPrint('Ошибка парсинга: $e');
          }
        }
      });
    
    // Добавьте тестовый обработчик для всех сообщений
    _hubConnection!.on('*', (arguments) {
      debugPrint('Получено неизвестное событие: ${arguments?[0]}');
    });
  }

  void _handleRequestPartCalculated(Map<String, dynamic> eventData) async {

    debugPrint('Обработка события RequestPartCalculated');

    final int requestId = eventData['request_id'];
    
    if (requestId != this.requestId) {
      return;
    }

    final part = Map<String, dynamic>.from(eventData['part']);
    
    debugPrint('Получена часть маршрута #${part['number']}');
    
    await _addRoutePartToMap(part);
  }

  void _handleRequestCalculated(Map<String, dynamic> eventData) async {
    debugPrint('Обработка события RequestCalculated');

    // final int requestId = eventData['request_id'];
    
    // if (requestId != this.requestId) {
    //   return;
    // }

    // final Map<String, dynamic> request = eventData['request'];
    
    debugPrint('Маршрут полностью вычислен!');
    
    if (mounted) {
      setState(() {
        requestStatus = RequestStatus.Calculated;
      });
    }
  }

  Future<void> _addRoutePartToMap(Map<String, dynamic> part) async {
    try {
      final int partNumber = part['number'];
      final Map<String, dynamic> coordsRange = part['coords_range'];
      final List<dynamic> segments = part['segments'];
      
      Set<Polyline> newPolylines = Set.from(polylines);
      
      var hue = (partNumber * 12.0) % 360.0;
      var color = HSLColor.fromAHSL(1.0, hue, 0.8, 0.6).toColor();
      
      if (partNumber == 1) {
        markers.add(Marker(
          markerId: MarkerId('start'),
          position: LatLng(
            coordsRange['start_coord']['width'],
            coordsRange['start_coord']['heigth'],
          ),
          infoWindow: InfoWindow(title: 'Начальная точка'),
          icon: await createMarkerWithLabel('Start', Colors.red)
        ));
      }
      
      markers.add(Marker(
        markerId: MarkerId('visited_point_$partNumber'),
        position: LatLng(
          coordsRange['end_coord']['width'],
          coordsRange['end_coord']['heigth'],
        ),
        infoWindow: InfoWindow(title: 'Точка посещения $partNumber'),
        icon: await createMarkerWithLabel('Point $partNumber', Colors.green)
      ));
      
      for (var segment in segments) {
        LatLng start = LatLng(
          segment['coords_range']['start_coord']['width'],
          segment['coords_range']['start_coord']['heigth'],
        );
        
        LatLng end = LatLng(
          segment['coords_range']['end_coord']['width'],
          segment['coords_range']['end_coord']['heigth'],
        );
        
        var polylineId = 'part_${partNumber}_segment_${segment['number']}';
        
        newPolylines.add(
          Polyline(
            polylineId: PolylineId(polylineId),
            points: [start, end],
            color: color,
            width: 2,
            zIndex: newPolylines.length
          ),
        );
      }
      
      if (mounted) {
        setState(() {
          polylines = newPolylines;
        });
      }
      
      debugPrint('Часть маршрута #$partNumber успешно добавлена на карту');
      
    } catch (e) {
      debugPrint('Ошибка при добавлении части маршрута на карту: $e');
    }
  }

  Future<void> createRouteRequest() async {
    if (startPoint != null && visitedPointsCount >= 1) {

      String guid = Uuid().v4();

      final prefs = await SharedPreferences.getInstance();
      String? jwtToken = prefs.getString('jwt_token');

      if (jwtToken == null) {
        debugPrint("Ошибка: Не найден токен.");
        return;
      }

      final Map<String, dynamic> requestBody = {
        "guid": guid,
        "start_coord": {
          "width": startPoint!.latitude,
          "heigth": startPoint!.longitude,
        },
        "to_be_visited_coords": visitedPoints
            .where((point) => point != null)
            .map((point) => {
                  "width": point!.latitude,
                  "heigth": point.longitude,
                })
            .toList(),
      };

      try {
        final response = await http.post(
          Uri.parse('$apiBaseUrl/Requests/create'),
          headers: {
            'Authorization': 'Bearer $jwtToken',
            'Content-Type': 'application/json',
          },
          body: json.encode(requestBody),
        );

        if (response.statusCode == 200) {
          final responseJson = json.decode(response.body);
          requestId = responseJson['request_id'];
          _currentRequestId = requestId;
          debugPrint('Запрос успешно создан. Request ID: $requestId');

          await initializeSignalR();

          await Future.delayed(Duration(milliseconds: 500));

          setState(() {
            requestStatus = RequestStatus.Created;
          });

          // var result = await waitForRequestData(requestId!);

          // if (!result){
          //   debugPrint('Ошибка ожидания запроса');
          // }

        } else {
          debugPrint('Ошибка сервера: ${response.body}');
        }
      } catch (e) {
        debugPrint('Ошибка сети: $e');
      }
    } else {
      debugPrint('Ошибка: Нужно выбрать обе точки!');
    }
  }

    Future<bool> waitForRequestData(int requestId, {int maxAttempts = 40}) async {
      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        final success = await tryGetRequestData(requestId);
        if (success) {
          return true;
        }
        await Future.delayed(Duration(seconds: 1));
      }
      return false;
    }

   Future<void> acceptRequest() async {
    if (requestId != null) {
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
            'request_id': requestId,
            'new_status': 'accepted',
          }),
        );

        if (response.statusCode == 200) {
          debugPrint('Запрос успешно принят');

          setState(() {
            requestStatus = RequestStatus.Accepted;
          });
        } else {
          debugPrint('Ошибка принятия запроса: ${response.body}');
        }
      } catch (e) {
        debugPrint('Ошибка сети: $e');
      }
    }
  }

   Future<void> followRequest() async {
    if (requestId != null) {
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
            'request_id': requestId,
            'new_status': 'followed',
          }),
        );

        if (response.statusCode == 200) {
          debugPrint('Следование по машруту запущено');

          setState(() {
            requestStatus = RequestStatus.Followed;
          });
        } else {
          debugPrint('Ошибка follow действия запроса: ${response.body}');
        }
      } catch (e) {
        debugPrint('Ошибка сети: $e');
      }
    }
  }

   Future<void> unfollowRequest() async {
    if (requestId != null) {
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
            'request_id': requestId,
            'new_status': 'unfollowed',
          }),
        );

        if (response.statusCode == 200) {
          debugPrint('Следование по машруту приостановлено');

          setState(() {
            requestStatus = RequestStatus.Unfollowed;
          });
        } else {
          debugPrint('Ошибка unfollowed действия запроса: ${response.body}');
        }
      } catch (e) {
        debugPrint('Ошибка сети: $e');
      }
    }
  }

 Future<void> finalizeRequest() async {
    if (requestId != null) {
      final prefs = await SharedPreferences.getInstance();
      String? jwtToken = prefs.getString('jwt_token');

      if (jwtToken == null) {
        debugPrint("Ошибка: Не найден токен.");
        return;
      }

      try {
        final response = await http.patch(
          Uri.parse('$apiBaseUrl/Requests/finalize?requestId=$requestId'),
          headers: {
            'Authorization': 'Bearer $jwtToken',
            'Content-Type': 'application/json',
          }
        );

        if (response.statusCode == 200) {
          debugPrint('Запрос успешно отменен');
          
          await _hubConnection?.stop();

          setState(() {
            isMapVisible = false;

            requestStatus = RequestStatus.Closed;

            markers.clear();
            polylines.clear();
            startPoint = null;
            visitedPoints = List.filled(RequestStateBaseMixin.limitVisitedPoints, null);
            visitedPointsCount = 0;
            currentPoint = null;
            isCardVisible = true;
          });

          await Future.delayed(Duration(seconds: 3));

          Navigator.of(context).pop();
        } else {
          debugPrint('Ошибка финализации запроса: ${response.body}');
        }
      } catch (e) {
        debugPrint('Ошибка сети: $e');
      }
    }
  }  

  Future<bool> tryGetRequestData(int requestId) async {
    final prefs = await SharedPreferences.getInstance();
    String? jwtToken = prefs.getString('jwt_token');

    if (jwtToken == null) {
      debugPrint("Ошибка: Не найден токен.");
      return false;
    }

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/Requests?requestId=$requestId'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        }
      );

      if (response.statusCode == 200) {
        debugPrint('Запрос на получение маршрута обработан успешно.');

        final responseJson = json.decode(response.body);
        List<dynamic> parts = responseJson['parts'];
        Set<Polyline> newPolylines = {};

        var hue = 0.0;
        final double hueStep = 360.0 / 30.0;

        markers.clear();

        debugPrint('Добавлен стартовый маркер.');

        markers.add(Marker(
          markerId: MarkerId('start'),
          position: LatLng(
              parts[0]['coords_range']['start_coord']['width'],
              parts[0]['coords_range']['start_coord']['heigth'],
            ),
          infoWindow: InfoWindow(title: 'Начальная точка'),
          icon: await createMarkerWithLabel('Start', Colors.red)
        ));

        var visitedPointsCounter = 1;

        for (var part in parts){
          hue = (hue + hueStep) % 360.0;

          debugPrint('Добавление $visitedPointsCounter части маршрута...');

          var color = HSLColor.fromAHSL(1.0, hue, 0.8, 0.6).toColor();

          var segments = part['segments'];

          markers.add(Marker(
            markerId: MarkerId('visited point $visitedPointsCounter'),
            position: LatLng(
              part['coords_range']['end_coord']['width'],
              part['coords_range']['end_coord']['heigth'],
            ),
            infoWindow: InfoWindow(title: 'Точка посещения $visitedPointsCounter'),
            icon: await createMarkerWithLabel('Point $visitedPointsCounter', Colors.green)
          )); 

          for (var segment in segments) {
            LatLng start = LatLng(
              segment['coords_range']['start_coord']['width'],
              segment['coords_range']['start_coord']['heigth'],
            );

            LatLng end = LatLng(
              segment['coords_range']['end_coord']['width'],
              segment['coords_range']['end_coord']['heigth'],
            );

            var polylineId = 'Part ' + part['number'].toString() + ', segment ' + segment['number'].toString();

            debugPrint('New segment added $polylineId');

            newPolylines.add(
              Polyline(
                polylineId: PolylineId(polylineId),
                points: [start, end],
                color: color,
                width: 2,
                zIndex: newPolylines.length
              ),
            );
          }  
             
          visitedPointsCounter++;
        }

        setState(() {
          requestStatus = RequestStatus.Calculated;
          polylines = newPolylines;
        });

        return true;
      } 
      else if(response.statusCode == 400){
        debugPrint('Маршрут еще не построен. Надо дождаться построения..');
        debugPrint('Ошибка сервера: ${response.body}');
      }
      else {
        debugPrint('Ошибка сервера: ${response.body}');
      }
    } catch (e) {
      debugPrint('Ошибка сети: $e');
    }

    return false;
  }

  Future<BitmapDescriptor> createMarkerWithLabel(String label, Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    
    // Увеличиваем размер холста для текста
    const double markerRadius = 8;
    const double textPadding = 1;
    const double textBottomMargin = 4;
    
    // Создаем TextPainter для расчета размеров текста
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 9,
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    // Рассчитываем размеры холста
    final double canvasWidth = textPainter.width + textPadding * 2;
    final double canvasHeight = markerRadius * 2 + textPainter.height + textBottomMargin + textPadding * 2;
    
    final Canvas canvas = Canvas(pictureRecorder, Rect.fromLTWH(0, 0, canvasWidth, canvasHeight));
    
    final Paint markerPaint = Paint()..color = color;
    final Paint textBackgroundPaint = Paint()..color = Colors.white;
    
    // Центр маркера по горизонтали, сверху холста
    final double centerX = canvasWidth / 2;
    final double markerCenterY = markerRadius;
    
    // Рисуем маркер (круг)
    canvas.drawCircle(Offset(centerX, markerCenterY), markerRadius, markerPaint);
    
    // Фон под текст
    final double textY = markerRadius * 2 + textBottomMargin;
    final backgroundRect = Rect.fromLTWH(
      centerX - textPainter.width / 2 - textPadding,
      textY,
      textPainter.width + textPadding * 2,
      textPainter.height + textPadding * 2
    );
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(backgroundRect, Radius.circular(4)),
      textBackgroundPaint
    );
    
    // Текст
    textPainter.paint(canvas, Offset(centerX - textPainter.width / 2, textY + textPadding));
    
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(canvasWidth.toInt(), canvasHeight.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }
}