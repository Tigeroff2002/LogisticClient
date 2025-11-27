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
        height: 40, // Уменьшаем высоту Header
        decoration: BoxDecoration(
          color: Colors.deepPurple,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
        ),
        child: Row(
          children: [
            // Кнопка назад
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            // Заголовок по центру
            Expanded(
              child: Center(
                child: const Text(
                  'Сервис маршрутов',
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 18, 
                    color: Colors.white
                  ),
                ),
              ),
            ),
            // Пустое место для балансировки (такой же размер как кнопка назад)
            SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}