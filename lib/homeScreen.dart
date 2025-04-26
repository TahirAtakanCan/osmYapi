import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'CalculateScreen.dart';
import 'calculate_controller.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Seçilen hesaplamaları takip etmek için liste
  final RxList<CalculationHistory> selectedCalculations = <CalculationHistory>[].obs;
  
  @override
  void initState() {
    super.initState();
    _loadCalculationHistory();
  }

  
  Future<void> _loadCalculationHistory() async {
    await CalculateController.loadHistoryFromStorage();
  }
  
  
  void _showCalculationHistoryPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF3C3C3C), // Koyu gri/siyah (logo)
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      const Text(
                        'Son Hesaplamalarım',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      Obx(() {
                        // Seçilen hesaplamalar varsa Sil butonu göster
                        if (selectedCalculations.isNotEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: TextButton.icon(
                              onPressed: () {
                                // Seçilen hesaplamaları silme onayı iste
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('Seçilenleri Sil'),
                                      content: Text(
                                        '${selectedCalculations.length} hesaplamayı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'
                                      ),
                                      actions: [
                                        TextButton(
                                          child: const Text('İptal'),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        TextButton(
                                          child: const Text(
                                            'Sil',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold
                                            ),
                                          ),
                                          onPressed: () async {
                                            // Önce dialog'u kapat
                                            Navigator.of(context).pop();
                                            // Seçilen hesaplamaları sil
                                            await CalculateController.deleteSelectedCalculations(
                                              selectedCalculations.toList()
                                            );
                                            // Seçimleri temizle
                                            selectedCalculations.clear();
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.white70,
                                size: 18,
                              ),
                              label: Text(
                                '${selectedCalculations.length} Hesaplamayı Sil',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.red.withOpacity(0.2),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          );
                        }
                        
                        // Hiç hesaplama yoksa veya hiç hesaplama seçili değilse boş döndür
                        if (CalculateController.calculationHistory.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        
                        // Hesaplamalar var ama hiçbiri seçili değil, tümünü sil butonu göster
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Tümünü Seç butonu
                              TextButton.icon(
                                onPressed: () {
                                  // Tüm hesaplamaları seç
                                  selectedCalculations.assignAll(
                                    CalculateController.calculationHistory
                                  );
                                },
                                icon: const Icon(
                                  Icons.select_all,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Tümünü Seç',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.blue.withOpacity(0.2),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                Expanded(
                  child: Obx(() {
                    final calculations = CalculateController.calculationHistory;
                    
                    if (calculations.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Henüz kaydedilmiş hesaplama bulunmuyor.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shrinkWrap: true,
                      itemCount: calculations.length,
                      itemBuilder: (context, index) {
                        final calculation = calculations[index];
                        final dateFormatter = DateFormat('dd.MM.yyyy HH:mm');
                        final formattedDate = dateFormatter.format(calculation.date);
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 3,
                          child: Obx(() {
                            final isSelected = selectedCalculations.contains(calculation);
                            return ExpansionTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              title: calculation.customerName.isNotEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        'Müşteri: ${calculation.customerName}',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : const Text(''),
                              
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tarih: $formattedDate',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                '${calculation.excelType} - ${calculation.productCount} Ürün',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Tutar: ${calculation.netAmount.toStringAsFixed(2)} TL',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              // Hesaplamayı seçmek için checkbox ekliyorum
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: calculation.excelType.contains('58')
                                        ? Color(0xFF3C3C3C) // Koyu gri/siyah (logo)
                                        : Color(0xFFF47B20), // Turuncu (logo)
                                    onChanged: (bool? value) {
                                      if (value == true) {
                                        selectedCalculations.add(calculation);
                                      } else {
                                        selectedCalculations.remove(calculation);
                                      }
                                    },
                                  ),
                                  CircleAvatar(
                                    backgroundColor: calculation.excelType.contains('58')
                                        ? Color(0xFF3C3C3C) // Koyu gri/siyah (logo)
                                        : Color(0xFFF47B20), // Turuncu (logo)
                                    child: Text(
                                      '${calculation.productCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.picture_as_pdf,
                                  color: calculation.excelType.contains('58')
                                      ? Color(0xFF3C3C3C) // Koyu gri/siyah (logo)
                                      : Color(0xFFF47B20), // Turuncu (logo)
                                ),
                                onPressed: () async {
                                  // Önce depolama izinlerini kontrol et
                                  bool hasPermission = await CalculateController.requestStoragePermission(context);
                                  
                                  if (!hasPermission) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'PDF indirmek için depolama izni gereklidir.'
                                        ),
                                        backgroundColor: Colors.red.shade300,
                                        duration: Duration(seconds: 4),
                                      ),
                                    );
                                    return;
                                  }

                                  // PDF oluşturma işlemi başladığında yükleniyor göster
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        backgroundColor: Colors.white.withOpacity(0.9),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(
                                              color: calculation.excelType.contains('58')
                                                ? Color(0xFF3C3C3C) // Koyu gri/siyah (logo)
                                                : Color(0xFFF47B20), // Turuncu (logo)
                                            ),
                                            SizedBox(height: 20),
                                            Text(
                                              'PDF hazırlanıyor...',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );

                                  // PDF oluştur ve indir
                                  try {
                                    await CalculateController.generateCalculationPdf(calculation);
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('PDF indirme işlemi sırasında bir hata oluştu: $e'),
                                        backgroundColor: Colors.red.shade300,
                                        duration: Duration(seconds: 4),
                                      ),
                                    );
                                  } finally {
                                    // Yükleniyor göstergesini kapat
                                    Navigator.of(context, rootNavigator: true).pop();
                                  }
                                },
                                tooltip: 'PDF İndir',
                              ),
                              expandedCrossAxisAlignment: CrossAxisAlignment.start,
                              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              children: [
                                const Divider(),
                                const Text(
                                  'Ürünler:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...calculation.products.take(5).map((product) {
                                  String productName = '';
                                  if (product.containsKey('ÜRÜN KODU') && product.containsKey('ÜRÜN ADI')) {
                                    productName = '${product['ÜRÜN KODU']} - ${product['ÜRÜN ADI']}';
                                  } else if (product.containsKey('ÜRÜN KODU')) {
                                    productName = product['ÜRÜN KODU'].toString();
                                  } else {
                                    productName = 'Ürün';
                                  }
                                  
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      productName,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  );
                                }).toList(),
                                if (calculation.products.length > 5)
                                  Text(
                                    '...ve ${calculation.products.length - 5} ürün daha',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Toplam Tutar:',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    Text(
                                      '${calculation.totalAmount.toStringAsFixed(2)} TL',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Net Tutar:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade800,
                                      ),
                                    ),
                                    Text(
                                      '${calculation.netAmount.toStringAsFixed(2)} TL',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }),
                        );
                      },
                    );
                  }),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue.shade800,
                        ),
                        child: const Text('Kapat'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 400;
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF3C3C3C),  // Koyu gri/siyah (logo)
              Color(0xFFF47B20),  // Turuncu (logo)
              Color(0xFFFFFFFF),  // Beyaz
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
                              width: isSmallScreen ? 150 : 200,
                              height: isSmallScreen ? 150 : 200,
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
                              onTap: () => _showCalculationHistoryPopup(context),
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
                  
                  SizedBox(height: screenSize.height * 0.08),
                  
                  
                  isSmallScreen 
                    ? Column(
                        children: [
                          _buildButton(
                            context, 
                            '58 nolu', 
                            Color(0xFF3C3C3C), // Koyu gri/siyah (logo) 
                            isFullWidth: true
                          ),
                          const SizedBox(height: 20),
                          _buildButton(
                            context, 
                            '59 nolu', 
                            Color(0xFFF47B20), // Turuncu (logo)
                            isFullWidth: true
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildButton(context, '58 nolu', Color(0xFF3C3C3C)), // Koyu gri/siyah (logo)
                          _buildButton(context, '59 nolu', Color(0xFFF47B20)), // Turuncu (logo)
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
            final controller = Get.find<CalculateController>(tag: text);
            controller.selectedProducts.clear();
            controller.profilBoyuControllers.forEach((_, controller) => controller.dispose());
            controller.paketControllers.forEach((_, controller) => controller.dispose());
            controller.profilBoyuControllers.clear();
            controller.paketControllers.clear();
            controller.calculateTotalPrice();
            print("HomeScreen'e dönüldü: ${text} hesaplama verileri temizlendi.");
          });
        },
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: isFullWidth ? 20 : 35, 
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
              text.contains('58') ? Icons.document_scanner : Icons.document_scanner_outlined,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}