import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logist_client/models/RequestStatus.dart';
import 'package:logist_client/widgets/user_page.location_track.dart';
import 'package:logist_client/widgets/user_page.status_manager.dart';
import 'package:logist_client/widgets/user_page.user_state_mixin.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'header.dart';
import 'footer.dart';
import 'package:logist_client/widgets/lk_page.dart';
import 'package:logist_client/widgets/auth_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

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

class _UserPageState extends State<UserPage> with UserPageLocationTrack, UserPageStatusManager, UserStateBaseMixin {

    late GoogleMapController _mapController;

    double _vladimirWidth = 56.1296;
    double _vladimirHeight = 40.4093;

    bool _isCardHovered = false;

    @override
    void initState() {
      super.initState();
      initLocation();
    }

    @override
    void dispose() {
      positionSubscription?.cancel();
      super.dispose();
    }

    void _onMapTapped(LatLng position) {
      setState(() {
        // Если обе точки уже выбраны, очищаем маркеры и начинаем заново
        if (startPoint != null && endPoint != null) {
          markers.clear();
          startPoint = null;
          endPoint = null;
          currentPoint = null;
        }

        // Если начальная точка еще не выбрана
        if (startPoint == null) {
          startPoint = position;
          markers.add(Marker(
            markerId: MarkerId('start'),
            position: startPoint!,
            infoWindow: InfoWindow(title: 'Начальная точка'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen), // Зеленый маркер
          ));
        }
        // Если конечная точка еще не выбрана
        else if (endPoint == null) {
          endPoint = position;
          markers.add(Marker(
            markerId: MarkerId('end'),
            position: endPoint!,
            infoWindow: InfoWindow(title: 'Конечная точка'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed), // Красный маркер
          ));
        }
      });
  }

    void _closeMap() {
      setState(() {
        isMapVisible = false;
        isCardVisible = true;
        markers.clear();
        startPoint = null;
        endPoint = null;
        currentPoint = null;
        currentPoint = null;

        requestStatus = RequestStatus.None;
      });
  }

  void _toggleMapVisibility() {
    setState(() {
      isMapVisible = !isMapVisible;
      isCardVisible = !isMapVisible; // Скрываем маленькую карточку
    });
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
              if (isCardVisible)
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

              if (isMapVisible)
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
                        if (requestStatus == RequestStatus.Created)
                          Text(
                            'Создание маршрута - выберите 2 точки',
                            style: TextStyle(color: Colors.blueAccent, fontSize: 18)),
                        if (requestStatus == RequestStatus.Accepted)
                          Text(
                            'Маршрут принят и сохранен в ЛК',
                            style: TextStyle(color: Colors.blueAccent, fontSize: 18)),
                        if (requestStatus == RequestStatus.Followed)
                          Text(
                            'Пользователь начал/возобновил следовать по маршруту',
                            style: TextStyle(color: Colors.blueAccent, fontSize: 18)),
                        if (requestStatus == RequestStatus.Unfollowed)
                          Text(
                            'Пользователь приостановил следование по маршруту',
                            style: TextStyle(color: Colors.blueAccent, fontSize: 18)),
                        if (requestStatus != RequestStatus.None && requestStatus != RequestStatus.Created && requestStatus != RequestStatus.Closed)
                          Text(
                            'Вы также можете отменить маршрут...',
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
                            markers: markers,
                            onTap: _onMapTapped,
                            myLocationEnabled: true,
                            polylines: polylines,
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
                                       startPoint != null
                                           ? '${startPoint!.latitude}, ${startPoint!.longitude}'
                                           : 'Пусто',
                                       style: TextStyle(color: Colors.black),
                                     ),
                                     if (startPoint != null)
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
                                       endPoint != null
                                           ? '${endPoint!.latitude}, ${endPoint!.longitude}'
                                           : 'Пусто',
                                       style: TextStyle(color: Colors.black),
                                     ),
                                     if (endPoint != null)
                                       Icon(
                                         Icons.circle,
                                         color: Colors.red, // Красный цвет для конечной точки
                                         size: 15,
                                       ),
                                   ],
                                 ),
                                SizedBox(height: 5.0),
                                if (requestStatus == RequestStatus.None)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ElevatedButton(
                                    onPressed: startPoint != null && endPoint != null ? createRouteRequest : null,
                                    child: const Text('Создать запрос на маршрут'))),
                                if (requestStatus == RequestStatus.Calculated)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ElevatedButton(
                                    onPressed: acceptRequest,
                                    child: const Text('Принять маршрут'))),
                                if (requestStatus == RequestStatus.Accepted)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ElevatedButton(
                                    onPressed: followRequest,
                                    child: const Text('Начать следовать по маршруту'))),
                                if (requestStatus == RequestStatus.Followed)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ElevatedButton(
                                    onPressed: unfollowRequest,
                                    child: const Text('Приостановить следование по маршруту'))),
                                if (requestStatus == RequestStatus.Unfollowed)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ElevatedButton(
                                    onPressed: followRequest,
                                    child: const Text('Возобновить следование по маршруту'))),
                                if (requestStatus != RequestStatus.None && requestStatus != RequestStatus.Created && requestStatus != RequestStatus.Closed)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ElevatedButton(
                                    onPressed: finalizeRequest,
                                    child: const Text('Закрыть запрос'))),                       
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