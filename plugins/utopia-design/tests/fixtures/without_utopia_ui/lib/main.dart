import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Without Utopia UI Fixture',
      home: Scaffold(
        body: Center(child: Text('without_utopia_ui fixture')),
      ),
    );
  }
}
