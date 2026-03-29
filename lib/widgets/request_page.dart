import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logist_client/models/RequestStatus.dart';
import 'package:logist_client/widgets/request_page.location_track.dart';
import 'package:logist_client/widgets/request_page.request_manager.dart';
import 'package:logist_client/widgets/request_page.user_state_mixin.dart';
import 'header.dart';
import 'footer.dart';

class RequestPage extends StatefulWidget {
    final int requestId;

    const RequestPage({
      Key? key,
      required this.requestId
    }) : super(key: key);

    @override
    _RequestPageState createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage> 
  with RequestPageLocationTrack, RequestPageRequestManager, RequestStateBaseMixin {

    late GoogleMapController _mapController;

    double _vladimirWidth = 56.1296;
    double _vladimirHeight = 40.4093;

    bool _isCardHovered = false;

    @override
    void initState() {
      super.initState();
      initLocation();

      if (widget.requestId != 0){
        waitForRequestData(widget.requestId).then((value) => {
          requestId = widget.requestId
        });
      }

      isCardVisible = false;
      isMapVisible = true;
    }

    @override
    void dispose() {
      positionSubscription?.cancel();
      super.dispose();
    }

    void _onMapTapped(LatLng position) {
      if (requestStatus != RequestStatus.None) {
        return;
      }

      setState(() {
        if (startPoint != null && visitedPointsCount == RequestStateBaseMixin.limitVisitedPoints) {
          markers.clear();
          startPoint = null;
          visitedPoints = List.filled(RequestStateBaseMixin.limitVisitedPoints, null);
          visitedPointsCount = 0;
          currentPoint = null;
        }

        if (startPoint == null) {
          startPoint = position;
          visitedPointsCount = 0;

          createMarkerWithLabel('Start', Colors.red).then((icon) => {
            markers.add(Marker(
              markerId: MarkerId('start'),
              position: startPoint!,
              infoWindow: InfoWindow(title: 'Начальная точка'),
              icon: icon
            ))
          });
        }

        else if (visitedPoints.any((a) => a == null)) {
          visitedPoints[visitedPointsCount++] = position;

          createMarkerWithLabel('Point $visitedPointsCount', Colors.green).then((icon) => {
            markers.add(Marker(
              markerId: MarkerId('Point $visitedPointsCount'),
              position: position,
              infoWindow: InfoWindow(title: 'Точка для посещения $visitedPointsCount'),
              icon: icon
            ))
          });
        }
      });
  }

    void _closeMap() {
      setState(() {
        isMapVisible = false;
        isCardVisible = true;
        markers.clear();
        startPoint = null;
        visitedPoints = List.filled(RequestStateBaseMixin.limitVisitedPoints, null);
        visitedPointsCount = 0;
        currentPoint = null;
        currentPoint = null;

        requestStatus = RequestStatus.None;
      });
  }

  void _toggleMapVisibility() {
    setState(() {
      isMapVisible = !isMapVisible;
      isCardVisible = !isMapVisible;
    });
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Stack(
      children: [
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
                  child: requestId == 0
                    ? AnimatedContainer(
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
                          child: const Text('Сгенерировать маршрут', style: TextStyle(color: Colors.white, fontSize: 16)),
                        ),
                      ),
                    )
                    : SizedBox(),
                ),

              if (isMapVisible)
                Center(
                  child: Container(
                    width: 2000, 
                    height: 860,
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
                            'Маршрут создается, ожидайте...',
                            style: TextStyle(color: Colors.blueAccent, fontSize: 18)),
                        if (requestStatus == RequestStatus.Calculated)
                          Text(
                            'Маршрут создан, можете его принять',
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
                              tilt: 45,
                              bearing: 0,
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
                                    //  Text(
                                    //    'Конечная точка: ',
                                    //    style: TextStyle(color: Colors.black),
                                    //  ),
                                    //  Text(
                                    //    endPoint != null
                                    //        ? '${endPoint!.latitude}, ${endPoint!.longitude}'
                                    //        : 'Пусто',
                                    //    style: TextStyle(color: Colors.black),
                                    //  ),
                                    //  if (endPoint != null)
                                    //    Icon(
                                    //      Icons.circle,
                                    //      color: Colors.red, // Красный цвет для конечной точки
                                    //      size: 15,
                                    //    ),
                                   ],
                                 ),
                                SizedBox(height: 5.0),
                                if (requestStatus == RequestStatus.None)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ElevatedButton(
                                    onPressed: startPoint != null && visitedPointsCount >= 1 ? createRouteRequest : null,
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
        const Header(),
        const Footer(),
      ],
    ),
  );
  }
}