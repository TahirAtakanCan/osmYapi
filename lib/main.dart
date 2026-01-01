import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
    return GetMaterialApp(
      title: 'OSM Yapı',
      debugShowCheckedModeBanner: false,
      // Performans optimizasyonu: Gereksiz rebuild'leri önle
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 200),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF47B20)),
        useMaterial3: true,
        // Performans için platform adaptive özelliklerini kapat
        platform: TargetPlatform.android,
      ),
      home: const HomeScreen(),
    );
  }
} 