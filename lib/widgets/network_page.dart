import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:logist_client/global_endpoints.dart';
import 'package:logist_client/models/host_model.dart';
import 'package:logist_client/shared_pref_cached_data.dart';
import 'package:logist_client/widgets/home_page.dart';
class NetworkPage extends StatefulWidget {
  @override
  NetworkPageState createState() {
    return new NetworkPageState();
  }
}

class NetworkPageState extends State<NetworkPage> {
  final TextEditingController ipController = TextEditingController();

  bool isIpValidated = true;

  @override
  void initState() {
    super.initState();

    ipController.text = GlobalEndpoints().mobileUri;
  }

  @override
  void dispose() {
    ipController.dispose();
    super.dispose();
  }

  final String pictureUrl =
      'https://cdn.icon-icons.com/icons2/3352/PNG/512/live_streaming_streaming_social_media_website_mobile_platform_video_icon_210300.png';

  @override
  Widget build(BuildContext context) {
    setState(() {
      var mySharedPreferences = new MySharedPreferences();

      var cachedData = mySharedPreferences.getDataIfNotExpired();

      cachedData.then((value) {
        var model = HostModel.fromJson(jsonDecode(value.toString()));

        ipController.text = model.currentHost;
      });
    });

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: new ThemeData(scaffoldBackgroundColor: Colors.cyanAccent),
      home: Scaffold(
          appBar: AppBar(
            title: Text(
              'Ручная настройка сети',
              style: TextStyle(fontSize: 16, color: Colors.deepPurple),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => HomePage()),
                );
              },
            ),
          ),
          body: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: ipController,
                  style: TextStyle(fontSize: 16, color: Colors.deepPurple),
                  decoration: InputDecoration(
                      labelText: 'IP адрес: ',
                      labelStyle:
                          TextStyle(fontSize: 16, color: Colors.deepPurple),
                      errorText:
                          !isIpValidated ? 'IP не может быть пустым' : null),
                ),
                SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      isIpValidated = !ipController.text.isEmpty;

                      if (isIpValidated) {
                        MySharedPreferences sharedPreferences =
                            new MySharedPreferences();
                        sharedPreferences.clearData();

                        var currentUri = ipController.text.toString();

                        var hostModel = new HostModel(currentHost: currentUri);

                        var json = hostModel.toJson();

                        sharedPreferences.saveDataWithExpiration(
                            jsonEncode(json), const Duration(days: 7));

                        ipController.text = currentUri;
                      }
                    });
                  },
                  child: Text(
                    'Изменить ip',
                    style: TextStyle(fontSize: 16, color: Colors.deepPurple),
                  ),
                ),
                GestureDetector(child: Image.network(pictureUrl)),
                SizedBox(height: 10.0)
              ],
            ),
          )),
    );
  }
}