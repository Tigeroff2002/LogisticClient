import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logist_client/models/RequestStatus.dart';
import 'package:logist_client/widgets/user_page.dart';

import 'dart:js' as js;

mixin UserStateBaseMixin on State<UserPage>
{
    RequestStatus requestStatus = RequestStatus.None;

    int? requestId;

    LatLng? currentPoint;

    LatLng? startPoint;

    static const int limitVisitedPoints = 20;

    List<LatLng?> visitedPoints = List.filled(limitVisitedPoints, null);

    int visitedPointsCount = 0;

    Set<Polyline> polylines = {};

    Set<Marker> markers = Set();    

    String get apiBaseUrl {
      return js.context['env']['API_BASE_URL'] ?? 'https://localhost:7247';
    }
}