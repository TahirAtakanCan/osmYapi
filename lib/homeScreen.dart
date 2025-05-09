import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'CalculateScreen.dart';
import 'HistoryScreen.dart';
import 'calculate_controller_base.dart';
import 'calculate_controller_winer.dart';
import 'calculate_controller_alfapen.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _loadCalculationHistory();
  }

  Future<void> _loadCalculationHistory() async {
    await CalculateControllerBase.loadHistoryFromStorage();
  }
  
  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 400;
    final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF3C3C3C),  
              Color(0xFFF47B20),  
              Color(0xFFFFFFFF),  
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  
                  // Logo ve Başlık
                  Hero(
                    tag: 'company-logo',
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 15,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'OSM Yapı',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                              shadows: [
                                Shadow(
                                  blurRadius: 8.0,
                                  color: Colors.black45,
                                  offset: Offset(2.0, 2.0),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.asset(
                              'assets/images/osmyapilogo.jpg',
                              width: isSmallScreen ? 120 : 180,
                              height: isSmallScreen ? 120 : 180,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Hoş Geldiniz ve Son Hesaplamalar alt alta ortada
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Hoş Geldiniz Yazısı
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 33),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            'Hoşgeldiniz',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(
                                  blurRadius: 5.0,
                                  color: Colors.black38,
                                  offset: Offset(1.5, 1.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 15),
                        
                        // Son Hesaplamalar Butonu
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                // Son Hesaplamalar ekranına git
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const HistoryScreen(),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(15),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.history_rounded,
                                      size: 28,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Son Hesaplamalar',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: isSmallScreen ? 25 : screenSize.height * 0.08),
                  
                  // Butonları her zaman alt alta göster
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: isSmallScreen ? double.infinity : screenSize.width * 0.7,
                        child: _buildButton(
                          context, 
                          'Alfa Pen - 4', 
                          const Color(0xFF3C3C3C),
                          isFullWidth: true
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 20 : 30),
                      Container(
                        width: isSmallScreen ? double.infinity : screenSize.width * 0.7,
                        child: _buildButton(
                          context, 
                          'Winer - 59', 
                          const Color(0xFFF47B20),
                          isFullWidth: true
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: screenSize.height * 0.05),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildButton(BuildContext context, String text, Color color, {bool isFullWidth = false}) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CalculateScreen(buttonType: text),
            ),
          ).then((_) {
            // HomeScreen'e geri dönüldüğünde ürünleri temizle
            final dynamic controller;
            if (text.contains('Alfa Pen')) {
              controller = Get.find<CalculateControllerAlfapen>(tag: text);
            } else if (text.contains('Winer')) {
              controller = Get.find<CalculateControllerWiner>(tag: text);
            } else {
              controller = Get.find<CalculateControllerBase>(tag: text);
            }
            
            controller.selectedProducts.clear();
            controller.profilBoyuControllers.forEach((_, controller) => controller.dispose());
            controller.paketControllers.forEach((_, controller) => controller.dispose());
            controller.profilBoyuControllers.clear();
            controller.paketControllers.clear();
            controller.calculateTotalPrice();
          });
        },
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: isFullWidth ? 20 : 15, 
            vertical: 20,
          ),
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              text.contains('Alfa Pen') ? Icons.document_scanner : Icons.document_scanner_outlined,
              size: 24,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}