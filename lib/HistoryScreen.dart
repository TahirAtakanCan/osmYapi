import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'calculate_controller.dart';
import 'CalculateScreen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {

  final RxList<CalculationHistory> selectedCalculations = <CalculationHistory>[].obs;

  @override
  void initState() {
    super.initState();
    _loadCalculationHistory();
  }

  Future<void> _loadCalculationHistory() async {
    await CalculateController.loadHistoryFromStorage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Son Hesaplamalarım',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF3C3C3C),
        elevation: 0,
        actions: [
          Obx(() {
            if (selectedCalculations.isNotEmpty) {

              return IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Seçilenleri Sil',
                onPressed: () {

                  _showDeleteConfirmationDialog();
                },
              );
            } else if (CalculateController.calculationHistory.isNotEmpty) {

              return IconButton(
                icon: const Icon(Icons.select_all),
                tooltip: 'Tümünü Seç',
                onPressed: () {

                  selectedCalculations.assignAll(
                    CalculateController.calculationHistory
                  );
                },
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
      body: Column(
        children: [

          Obx(() => selectedCalculations.isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF3C3C3C).withOpacity(0.05),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${selectedCalculations.length} hesaplama seçildi',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextButton(
                      onPressed: () => selectedCalculations.clear(),
                      child: const Text('Seçimi Temizle'),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink()
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

                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: isSelected,
                              activeColor: calculation.excelType.contains('Alfa Pen')
                                  ? const Color(0xFF3C3C3C)
                                  : const Color(0xFFF47B20),
                              onChanged: (bool? value) {
                                if (value == true) {
                                  selectedCalculations.add(calculation);
                                } else {
                                  selectedCalculations.remove(calculation);
                                }
                              },
                            ),
                            CircleAvatar(
                              backgroundColor: calculation.excelType.contains('Alfa Pen')
                                  ? const Color(0xFF3C3C3C)
                                  : const Color(0xFFF47B20),
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [

                            IconButton(
                              icon: Icon(
                                Icons.edit,
                                color: calculation.excelType.contains('Alfa Pen')
                                    ? const Color(0xFF3C3C3C) 
                                    : const Color(0xFFF47B20),
                              ),
                              onPressed: () {
                                
                                CalculateController.calculationToEdit = calculation;
                                CalculateController.calculationToEditIndex = index;
                                
                                
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => CalculateScreen(buttonType: calculation.excelType),
                                  ),
                                ).then((_) {
                                  
                                  final controller = Get.find<CalculateController>(tag: calculation.excelType);
                                  controller.selectedProducts.clear();
                                  controller.profilBoyuControllers.forEach((_, controller) => controller.dispose());
                                  controller.paketControllers.forEach((_, controller) => controller.dispose());
                                  controller.profilBoyuControllers.clear();
                                  controller.paketControllers.clear();
                                  controller.calculateTotalPrice();
                                  
                                  
                                  CalculateController.calculationToEdit = null;
                                  CalculateController.calculationToEditIndex = null;
                                });
                              },
                              tooltip: 'Düzenle',
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.picture_as_pdf,
                                color: calculation.excelType.contains('Alfa Pen')
                                    ? const Color(0xFF3C3C3C)
                                    : const Color(0xFFF47B20),
                              ),
                              onPressed: () async {
                                
                                await _generatePdf(calculation);
                              },
                              tooltip: 'PDF İndir',
                            ),
                          ],
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
        ],
      ),
      floatingActionButton: Obx(() => CalculateController.calculationHistory.isNotEmpty && selectedCalculations.isNotEmpty
        ? FloatingActionButton(
            backgroundColor: const Color(0xFF3C3C3C),
            onPressed: () {
              _showDeleteConfirmationDialog();
            },
            tooltip: 'Seçilenleri Sil',
            child: const Icon(Icons.delete),
          )
        : const SizedBox.shrink()
      ),
    );
  }

  // PDF oluşturmak için yardımcı fonksiyon
  Future<void> _generatePdf(CalculationHistory calculation) async {
    
    bool hasPermission = await CalculateController.requestStoragePermission(context);
    
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PDF indirmek için depolama izni gereklidir.'),
          backgroundColor: Colors.red.shade300,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    
    if (!mounted) return;
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
                color: calculation.excelType.contains('Alfa Pen')
                  ? const Color(0xFF3C3C3C)
                  : const Color(0xFFF47B20),
              ),
              const SizedBox(height: 20),
              const Text(
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF indirme işlemi sırasında bir hata oluştu: $e'),
          backgroundColor: Colors.red.shade300,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      // Yükleniyor göstergesini kapat
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  
  void _showDeleteConfirmationDialog() {
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
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () async {
                
                Navigator.of(context).pop();
                
                await CalculateController.deleteSelectedCalculations(
                  selectedCalculations.toList()
                );
                
                selectedCalculations.clear();
              },
            ),
          ],
        );
      },
    );
  }
}