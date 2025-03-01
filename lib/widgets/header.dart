import 'package:flutter/material.dart';

class Header extends StatelessWidget implements PreferredSizeWidget {
  @override
  final Size preferredSize;

  const Header({Key? key})
      : preferredSize = const Size.fromHeight(50.0), // Высота Header
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0, // Отступ сверху
      left: 0,
      right: 0,
      child: Container(
        height: 50, // Уменьшаем высоту Header
        decoration: BoxDecoration(
          color: Colors.deepPurple,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(15),
            bottomRight: Radius.circular(15),
          ),
        ),
        child: Center(
          child: const Text(
            'Сервис маршрутов',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
