import 'package:flutter/material.dart';
import 'package:logist_client/widgets/user_page.dart';
import 'package:logist_client/widgets/user_page.user_state_mixin.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logist_client/models/RequestStatus.dart';
import 'package:http/http.dart' as http;

mixin UserPageStatusManager on State<UserPage> implements UserStateBaseMixin
{
  bool isMapVisible = false;
  bool isCardVisible = true;

  Future<void> createRouteRequest() async {
    if (startPoint != null && endPoint != null) {

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
        "to_be_visited_coords": [
          {
            "width": endPoint!.latitude,
            "heigth": endPoint!.longitude,
          }     
        ]
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
          debugPrint('Запрос успешно создан. Request ID: $requestId');

          setState(() {
            requestStatus = RequestStatus.Created;
          });

          var result = await waitForRequestData(requestId!);

          if (!result){
            debugPrint('Ошибка ожидания запроса');
          }

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

          setState(() {
            isMapVisible = false;

            requestStatus = RequestStatus.Closed;

            markers.clear();
            polylines.clear();
            startPoint = null;
            endPoint = null;
            currentPoint = null;
            isCardVisible = true;
          });
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
        debugPrint('Запрос обработан успешно.');

        final responseJson = json.decode(response.body);
        List<dynamic> parts = responseJson['parts'];
        Set<Polyline> newPolylines = {};

        var red = 0.0;
        var green = 0.0;
        var blue = 0.0;

        for (var part in parts){
          var color = Color.from(alpha: 10, red: red, green: green, blue: blue);

          var segments = part['segments'];

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
                polylineId: PolylineId(segment['number'].toString()),
                points: [start, end],
                color: color,
                width: 5,
              ),
            );
          }    
          red = (red + 64.0) % 256.0;
          green = (green + 64.0) % 256.0;
          blue = (blue + 64.0) % 256.0;      
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
}