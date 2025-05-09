import 'package:flutter/material.dart';
import 'package:logist_client/widgets/footer.dart';
import 'package:logist_client/widgets/header.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:js' as js;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_web/webview_flutter_web.dart'; // Для веба
import 'package:webview_flutter/webview_flutter.dart';   

class LkPage extends StatefulWidget {
  const LkPage({Key? key}) : super(key: key);

  @override
  _LkPageState createState() => _LkPageState();
}

class _LkPageState extends State<LkPage> {
  late HubConnection _hubConnection;
  Timer? _paymentStatusTimer;

  @override
  void initState() {
    super.initState();
    _initSignalRConnection();
  }

    String get apiBaseUrl {
      return js.context['env']['API_BASE_URL'] ?? 'https://localhost:7247';
    }

  @override
  void dispose() {
    _hubConnection.stop();
    _paymentStatusTimer?.cancel();
    super.dispose();
  }

  Future<void> _initiatePayment() async {
    try {
      String guid = Uuid().v4();

      final prefs = await SharedPreferences.getInstance();
      String? jwtToken = prefs.getString('jwt_token');

      if (jwtToken == null) {
        debugPrint("Ошибка: Не найден токен.");
        return;
      }

      final Map<String, dynamic> requestBody = {
        "guid": guid,
        "amount": 50,
      };

      final response = await http.post(
        Uri.parse('$apiBaseUrl/Payments/create'),
        headers: {
            'Authorization': 'Bearer $jwtToken',
            'Content-Type': 'application/json',
          },
          body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final paymentUrl = data['payment_url'];
        final paymentId = data['paument_id'];

        _openPaymentPage(paymentUrl);

        _startPaymentStatusChecker(paymentId);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Payment initiation error: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка при создании платежа')),
      );
    }
  }

    void _openPaymentPage(String url) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: Text('Оплата подписки')),
            body: WebViewWidget(
              controller: WebViewController()
                ..setJavaScriptMode(JavaScriptMode.unrestricted)
                ..loadRequest(Uri.parse(url)),
            ),
          ),
        ),
      );
    }

    Future<void> _initSignalRConnection() async {
      final prefs = await SharedPreferences.getInstance();
        String? jwtToken = prefs.getString('jwt_token');

        if (jwtToken == null) {
          debugPrint("Ошибка: Не найден токен.");
          return;
        }

      final options = HttpConnectionOptions(
        accessTokenFactory: () => Future.value('Bearer $jwtToken'),
      );

      _hubConnection = HubConnectionBuilder()
          .withUrl(
            '$apiBaseUrl/logistic',
            options: options)
          .build();

      _hubConnection.on('PaymentStatusUpdated', (List<dynamic>? message) {
        final status = message?[0] as String?;
        if (status == 'succeeded') {
          _redirectToReturnUrl();
        }
      });

      _hubConnection.start()?.catchError((error) {
        if (kDebugMode) {
          print('SignalR connection error: $error');
        }
      });
  }

  void _startPaymentStatusChecker(String paymentId) {
    _paymentStatusTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      try {
        final response = await http.get(
          Uri.parse('$apiBaseUrl/Payments/verify?paymentId=$paymentId'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['is_succeeded'] == true) {
            _redirectToReturnUrl();
            timer.cancel();
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Payment status check error: $e');
        }
      }
    });
  }

  void _redirectToReturnUrl() {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          settings: RouteSettings(name: '/lk'),
          builder: (context) => LkPage(),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Header(),
          
          // Виджет подписки
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 300,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Вы можете приобрести подписку',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Цена: 50 рублей',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _initiatePayment,
                      child: const Text('Оплатить'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Footer(),
        ],
      ),
    );
  }
}