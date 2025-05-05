import 'package:flutter/material.dart';
import 'homeScreen.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  // Flutter'ın başlangıç optimizasyonunu sağlamak için eklendi
  WidgetsFlutterBinding.ensureInitialized();
  
  // Android 13+ için izinlerin kontrol edilmesi
  _checkAndRequestPermissions();
  
  runApp(const MyApp());
}

// İzinlerin kontrolü ve gerekirse talep edilmesi
Future<void> _checkAndRequestPermissions() async {
  if (await Permission.storage.isDenied) {
    await Permission.storage.request();
  }
  
  // Android 13+ için özel izinler
  if (await Permission.photos.isDenied) {
    await Permission.photos.request();
  }
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

//-> Yapılacaklar yeni alfa pen 
// ECO70 PROFİT /BEYAZ ÇİFT YÜZ LAMİNE 
//7000 sürme seri 
// YARDIMCI PROFİLLER 70 LİK SERİ / ORTAK KULLANIM 