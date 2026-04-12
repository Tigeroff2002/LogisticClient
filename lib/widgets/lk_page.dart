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
import 'package:webview_flutter_web/webview_flutter_web.dart';
import 'package:webview_flutter/webview_flutter.dart';   
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;

class LkPage extends StatefulWidget {
  const LkPage({Key? key}) : super(key: key);

  @override
  _LkPageState createState() => _LkPageState();
}

class _LkPageState extends State<LkPage> {
  late HubConnection _hubConnection;
  Timer? _paymentStatusTimer;
  Map<String, dynamic>? _subscriptionData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSubscriptionData();
    _tryVerifyLastPendingPayment();
    //_initSignalRConnection();
  }

  String get apiBaseUrl {
    return js.context['env']['API_BASE_URL'] ?? 'http://logistic-api:80';
  }

  @override
  void didUpdateWidget(LkPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fetchSubscriptionData();
  }

  @override
  void dispose() {
    _hubConnection.stop();
    _paymentStatusTimer?.cancel();
    super.dispose();
  }

  Future<void> _tryVerifyLastPendingPayment() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        String? jwtToken = prefs.getString('jwt_token');

        if (jwtToken == null) {
          debugPrint("Ошибка: Не найден токен.");
          return;
        }

        final response = await http.get(
          Uri.parse('$apiBaseUrl/Payments/try_verify_last'),
          headers: {
            'Authorization': 'Bearer $jwtToken',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
            setState(() {    
              _fetchSubscriptionData();  
            });
        }
        else {
          // Выводим подробную информацию об ошибке
          print('Error details: ${response.body}');
          throw Exception('Failed to fin and verify last pending payment: ${response.body}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Payment status check error: $e');
        }
      }
  }

  Future<void> _fetchSubscriptionData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      String? jwtToken = prefs.getString('jwt_token');

      if (jwtToken == null) {
        debugPrint("Ошибка: Не найден токен.");
        return;
      }

      final response = await http.get(
        Uri.parse('$apiBaseUrl/Subscriptions/all'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _subscriptionData = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        throw Exception('Failed to load subscription data');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (kDebugMode) {
        print('Subscription data fetch error: $e');
      }
    }
  }

  Future<void> _initiatePayment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jwtToken = prefs.getString('jwt_token');

      if (jwtToken == null) {
        debugPrint("Ошибка: Не найден токен.");
        return;
      }

      final Map<String, dynamic> requestBody = {
        "return_url": "http://localhost:3000/lk",
        "amount": 50,
      };

try {
  final response = await http.post(
    Uri.parse('$apiBaseUrl/Payments/create'),
    headers: {
      'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
    },
    body: json.encode(requestBody),
  );

  print('Response status: ${response.statusCode}');
  print('Response body: ${response.body}');

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final paymentUrl = data['payment_url'];
    final paymentId = data['payment_id'];

    _openPaymentPage(paymentUrl);
    _startPaymentStatusChecker(paymentId);
        } else {
          // Выводим подробную информацию об ошибке
          print('Error details: ${response.body}');
          throw Exception('Failed to create payment: ${response.body}');
        }
      } catch (e) {
        print('Exception occurred: $e');
        // Здесь можно добавить дополнительную обработку ошибок
      }
    } catch (e) {
      print('Payment initiation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка при создании платежа')),
      );
    }
  }

  void _openPaymentPage(String url) {
    if (kIsWeb) {
      // Для веб-версии просто открываем URL в новой вкладке
      html.window.open(url, '_blank');
    } else {
      // Для мобильных платформ используем WebView
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Оплата подписки')),
            body: WebViewWidget(
              controller: WebViewController()
                ..setJavaScriptMode(JavaScriptMode.unrestricted)
                ..loadRequest(Uri.parse(url)),
            ),
          ),
        ),
      );
    }
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
    _paymentStatusTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        String? jwtToken = prefs.getString('jwt_token');

        if (jwtToken == null) {
          debugPrint("Ошибка: Не найден токен.");
          return;
        }

        final response = await http.get(
          Uri.parse('$apiBaseUrl/Payments/verify?paymentId=$paymentId'),
          headers: {
            'Authorization': 'Bearer $jwtToken',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['is_succeeded'] == true) {
            setState(() {      
            });
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Payment status check error: $e');
        }
      }
      timer.cancel();     
    });
  }

  void _redirectToReturnUrl() {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: '/lk'),
        builder: (context) => LkPage(),
      ),
    );
  }

  Widget _buildSubscriptionInfo() {
    if (_isLoading) {
      return const CircularProgressIndicator();
    }

    if (_subscriptionData == null || _subscriptionData!['subscription'] == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Поддержите автора, у вас еще нет активной подписки',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Цена подписки за месяц: 50 рублей',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _initiatePayment,
            child: const Text('Оплатить подписку'),
          ),
        ],
      );
    } else {
      final subscription = _subscriptionData!['subscription'];
      final endDate = DateTime.parse(subscription['end_date']);
      final formattedDate = '${endDate.day}.${endDate.month}.${endDate.year}';

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Ваша подписка активна, благодарим вас! Далее будем добавлять премиум функции',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Действует до: $formattedDate',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      );
    }
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
                child: _buildSubscriptionInfo(),
              ),
            ),
          ),

          const Footer(),
        ],
      ),
    );
  }
}