import 'package:flutter/material.dart';
import 'package:logist_client/widgets/request_page.dart';

import 'dart:async';
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logist_client/models/RequestStatus.dart';
import 'package:logist_client/widgets/request_page.user_state_mixin.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

mixin RequestPageLocationTrack on State<RequestPage> implements RequestStateBaseMixin
{
    Position? currentPosition;
    Stream<Position>? positionStream;
    StreamSubscription<Position>? positionSubscription;

    Future<void> initLocation() async {
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

      currentPosition = await Geolocator.getCurrentPosition();
      print("Текущая позиция: $currentPosition");

      positionStream = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Обновлять каждые 10 метров
        ),
      );

      positionSubscription = positionStream!.listen((Position position) async {
        setState((){
          currentPosition = position;
        });

        if (requestStatus == RequestStatus.Followed){
          await _handlePositionChange(position);
          print("Текущая позиция обновлена по следованию: $position");        
        }
        else{
          print("Текущая позиция необновлена - так как пользователь не на маршруте: $position");  
        }     
      });
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
          "request_id": requestId!,
          "old_coord": {
              "width": currentPoint == null ? startPoint!.latitude : currentPoint!.latitude,
              "heigth": currentPoint == null ? startPoint!.longitude : currentPoint!.longitude,
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
              currentPoint = LatLng(position.latitude, position.longitude);

              markers.clear();

              markers.add(Marker(
                markerId: MarkerId('current'),
                position: currentPoint!,
                infoWindow: InfoWindow(title: 'Текущая точка'),
                icon: BitmapDescriptor.defaultMarker, // Красный маркер
              ));

              markers.add(Marker(
                markerId: MarkerId('end'),
                position: visitedPoints[0]!,
                infoWindow: InfoWindow(title: 'Конечная точка'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed), // Красный маркер
              ));
            });
          } else {
            debugPrint('Ошибка просчета запроса: ${response.body}');
          }
        } catch (e) {
          debugPrint('Ошибка сети: $e');
        }
      }
}