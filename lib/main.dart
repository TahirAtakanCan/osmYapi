import 'package:flutter/material.dart';
import 'homeScreen.dart';

void main() {
  // Flutter'ın başlangıç optimizasyonunu sağlamak için eklendi
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OSM Yapı',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFFF47B20)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
