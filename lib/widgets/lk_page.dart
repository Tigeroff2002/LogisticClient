import 'package:flutter/material.dart';
import 'package:logist_client/widgets/footer.dart';
import 'package:logist_client/widgets/header.dart';

class LkPage extends StatelessWidget {
  const LkPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Header(),

          const Footer()
        ],
      )
    );
  }
}
