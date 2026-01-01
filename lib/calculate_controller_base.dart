import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';

class CalculationHistory {
  final DateTime date;
  final String excelType;
  final int productCount;
  final double totalAmount;
  final double netAmount;
  final List<Map<String, dynamic>> products;
  final String customerName;

  CalculationHistory({
    required this.date,
    required this.excelType,
    required this.productCount,
    required this.totalAmount,
    required this.netAmount,
    required this.products,
    required this.customerName,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'excelType': excelType,
      'productCount': productCount,
      'totalAmount': totalAmount,
      'netAmount': netAmount,
      'products': products,
      'customerName': customerName,
    };
  }

  factory CalculationHistory.fromJson(Map<String, dynamic> json) {
    return CalculationHistory(
      date: DateTime.parse(json['date']),
      excelType: json['excelType'],
      productCount: json['productCount'],
      totalAmount: json['totalAmount'],
      netAmount: json['netAmount'],
      products: List<Map<String, dynamic>>.from(json['products']),
      customerName: json['customerName'] ?? '',
    );
  }
}

class CalculateControllerBase extends GetxController {
  static RxList<CalculationHistory> calculationHistory =
      <CalculationHistory>[].obs;

  static CalculationHistory? calculationToEdit;
  static int? calculationToEditIndex;

  static const int maxHistoryCount = 100;

  String excelType = '';

  // Performans: Normal List kullan, sadece UI güncellemesi gerektiğinde RxList
  final RxList<Map<String, dynamic>> excelData = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredExcelData = <Map<String, dynamic>>[].obs;
  final RxString selectedGroup = "Tüm Ürünler".obs;

  final RxList<Map<String, dynamic>> selectedProducts = <Map<String, dynamic>>[].obs;

  final RxDouble toplamTutar = 0.0.obs;
  final RxDouble netTutar = 0.0.obs;
  final RxDouble iskontoTutar = 0.0.obs;
  final RxDouble kdvTutar = 0.0.obs;

  final iskontoController = TextEditingController(text: '');
  final kdvController = TextEditingController(text: '');

  final Map<int, TextEditingController> profilBoyuControllers = {};
  final Map<int, TextEditingController> paketControllers = {};

  final RxBool isLoading = true.obs;

  String codeColumn = '';
  String nameColumn = '';
  String profilBoyuColumn = 'PROFİL BOYU (metre)';
  String paketColumn = 'PAKET';
  String fiyatColumn = '';

  // Debounce için timer - gereksiz hesaplamaları önler
  Worker? _calculateDebouncer;

  // Controller'ın başlatılması
  @override
  void onInit() {
    super.onInit();

    // Debounced listener kullan - çok hızlı değişikliklerde gereksiz hesaplamaları önle
    iskontoController.addListener(_onIskontoKdvChanged);
    kdvController.addListener(_onIskontoKdvChanged);
  }

  // Debounced hesaplama - 300ms bekle
  void _onIskontoKdvChanged() {
    _calculateDebouncer?.dispose();
    _calculateDebouncer = debounce(
      0.obs,
      (_) => calculateNetTutar(),
      time: const Duration(milliseconds: 300),
    );
    // Hemen bir değişiklik tetikle
    calculateNetTutar();
  }

  @override
  void onClose() {
    _calculateDebouncer?.dispose();
    iskontoController.dispose();
    kdvController.dispose();
    // Batch dispose for better performance
    for (final controller in profilBoyuControllers.values) {
      controller.dispose();
    }
    for (final controller in paketControllers.values) {
      controller.dispose();
    }
    profilBoyuControllers.clear();
    paketControllers.clear();
    super.onClose();
  }

  // Grupları filtrele - alt sınıflar tarafından override edilebilir
  void filterByGroup(String groupName) {
    selectedGroup.value = groupName;

    if (groupName == "Tüm Ürünler") {
      filteredExcelData.assignAll(excelData);
      return;
    }

    filteredExcelData.assignAll(excelData);
  }

  // Ürün ekleme fonksiyonu - optimized
  void addProduct(Map<String, dynamic> product) {
    // Early return pattern for better readability
    if (codeColumn.isEmpty || nameColumn.isEmpty) {
      _addProductInternal(product);
      return;
    }

    final isAlreadyAdded = selectedProducts.any((existingProduct) =>
        existingProduct[codeColumn] == product[codeColumn] &&
        existingProduct[nameColumn] == product[nameColumn]);

    if (isAlreadyAdded) {
      Get.snackbar('Uyarı', 'Bu ürün zaten eklenmiş!',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2));
      return;
    }

    _addProductInternal(product);
  }

  void _addProductInternal(Map<String, dynamic> product) {
    final newProductIndex = selectedProducts.length;

    selectedProducts.add(Map<String, dynamic>.from(product));

    // Controller'ları oluştur
    final profilController = TextEditingController(text: '');
    final paketController = TextEditingController(text: '');
    
    profilBoyuControllers[newProductIndex] = profilController;
    paketControllers[newProductIndex] = paketController;

    // Debounced listener ekle - performans için
    profilController.addListener(() => _debouncedCalculate());
    paketController.addListener(() => _debouncedCalculate());

    calculateTotalPrice();
  }

  // Debounced hesaplama için yardımcı
  DateTime? _lastCalculateTime;
  void _debouncedCalculate() {
    final now = DateTime.now();
    if (_lastCalculateTime == null || 
        now.difference(_lastCalculateTime!).inMilliseconds > 100) {
      _lastCalculateTime = now;
      calculateTotalPrice();
    }
  }

  // Ürün silme fonksiyonu
  void removeProduct(int index) {
    if (index >= 0 && index < selectedProducts.length) {
      profilBoyuControllers[index]?.dispose();
      paketControllers[index]?.dispose();
      selectedProducts.removeAt(index);

      final Map<int, TextEditingController> updatedProfileControllers = {};
      final Map<int, TextEditingController> updatedPaketControllers = {};

      for (int i = 0; i < selectedProducts.length; i++) {
        if (i >= index) {
          updatedProfileControllers[i] = profilBoyuControllers[i + 1]!;
          updatedPaketControllers[i] = paketControllers[i + 1]!;
        } else {
          updatedProfileControllers[i] = profilBoyuControllers[i]!;
          updatedPaketControllers[i] = paketControllers[i]!;
        }
      }

      profilBoyuControllers.clear();
      paketControllers.clear();
      profilBoyuControllers.addAll(updatedProfileControllers);
      paketControllers.addAll(updatedPaketControllers);

      calculateTotalPrice();
    }
  }

  // Toplam tutarı hesaplama fonksiyonu - alt sınıflar tarafından override edilmeli
  void calculateTotalPrice() {}

  // Net tutarı hesaplama fonksiyonu - alt sınıflar tarafından çağrılabilmesi için public yapıldı
  void calculateNetTutar() {
    final iskonto = double.tryParse(iskontoController.text) ?? 0.0;

    final kdvText = kdvController.text.trim();
    final double? kdv = kdvText.isEmpty ? null : double.tryParse(kdvText);

    final iskontoMiktar = toplamTutar.value * iskonto / 100;
    final aratutar = toplamTutar.value - iskontoMiktar;

    final kdvMiktar = kdv != null ? aratutar * kdv / 100 : 0.0;

    iskontoTutar.value = iskontoMiktar;
    kdvTutar.value = kdvMiktar;
    netTutar.value = aratutar + kdvMiktar;
  }

  // Ürün kodunun sütun adını belirle
  void setColumnNames() {
    if (excelData.isNotEmpty) {
      if (excelData[0].containsKey('ÜRÜN KODU')) {
        codeColumn = 'ÜRÜN KODU';
      } else {
        for (var key in excelData[0].keys) {
          if (key.toLowerCase().contains('kod') ||
              key.toLowerCase().contains('code')) {
            codeColumn = key;
            break;
          }
        }
        if (codeColumn.isEmpty && excelData[0].keys.isNotEmpty) {
          codeColumn = excelData[0].keys.first;
        }
      }

      if (excelData[0].containsKey('ÜRÜN ADI')) {
        nameColumn = 'ÜRÜN ADI';
      } else {
        for (var key in excelData[0].keys) {
          if (key.toLowerCase().contains('ad') ||
              key.toLowerCase().contains('name') ||
              key.toLowerCase().contains('ürün') ||
              key.toLowerCase().contains('product')) {
            nameColumn = key;
            break;
          }
        }
        var keys = excelData[0].keys.toList();
        if (nameColumn.isEmpty && keys.length > 1) {
          nameColumn = keys[1];
        }
      }

      if (excelData[0].containsKey('PROFİL BOYU (metre)')) {
        profilBoyuColumn = 'PROFİL BOYU (metre)';
      } else {
        for (var key in excelData[0].keys) {
          if (key.toLowerCase().contains('profil') &&
              key.toLowerCase().contains('boy')) {
            profilBoyuColumn = key;
            break;
          }
        }
      }

      if (excelData[0].containsKey('PAKET (Metre)')) {
        paketColumn = 'PAKET (Metre)';
      } else if (excelData[0].containsKey('PAKET')) {
        paketColumn = 'PAKET';
      } else {
        for (var key in excelData[0].keys) {
          // Önce "paket" ve "metre" içeren sütunu ara
          if (key.toLowerCase().contains('paket') &&
              key.toLowerCase().contains('metre')) {
            paketColumn = key;
            break;
          }
        }
        // Bulunamadıysa sadece "paket" içeren sütunu ara (ama "adet" içermeyeni)
        if (paketColumn.isEmpty || paketColumn == 'PAKET') {
          for (var key in excelData[0].keys) {
            if (key.toLowerCase().contains('paket') &&
                !key.toLowerCase().contains('adet')) {
              paketColumn = key;
              break;
            }
          }
        }
      }

      if (excelData[0].containsKey('FİYAT (Metre)')) {
        fiyatColumn = 'FİYAT (Metre)';
      } else {
        for (var key in excelData[0].keys) {
          if (key.toLowerCase().contains('fiyat') ||
              key.toLowerCase().contains('ucret') ||
              key.toLowerCase().contains('tutar') ||
              key.toLowerCase().contains('price')) {
            fiyatColumn = key;
            break;
          }
        }
        if (fiyatColumn.isEmpty) {
          List<String> numericColumns = [];
          for (var key in excelData[0].keys) {
            if (excelData[0][key] is double) {
              numericColumns.add(key);
            }
          }
          if (numericColumns.isNotEmpty) {
            fiyatColumn = numericColumns.last;
          }
        }
      }

      // Debug: Bulunan sütun isimlerini yazdır
      print('=== Bulunan Sütun İsimleri ===');
      print('Kod Sütunu: $codeColumn');
      print('Ad Sütunu: $nameColumn');
      print('Profil Boyu Sütunu: $profilBoyuColumn');
      print('Paket Sütunu: $paketColumn');
      print('Fiyat Sütunu: $fiyatColumn');
      print('Tüm Sütunlar: ${excelData[0].keys.toList()}');
      print('==============================');
    }
  }

  // Excel verisini ayarla
  void setExcelData(List<Map<String, dynamic>> data) {
    excelData.assignAll(data);
    filteredExcelData.assignAll(data);
    setColumnNames();
    isLoading.value = false;
  }

  // Excel dosya tipini ayarla (58 nolu, 60 nolu)
  void setExcelType(String type) {
    excelType = type;
  }

  // Hesaplamayı kaydet
  Future<void> saveCalculation(String customerName) async {
    if (selectedProducts.length >= 1) {
      final List<Map<String, dynamic>> productCopies = [];

      final iskontoValue = double.tryParse(iskontoController.text) ?? 0.0;
      final kdvValue = double.tryParse(kdvController.text) ?? 0.0;

      for (var product in selectedProducts) {
        Map<String, dynamic> copy = Map<String, dynamic>.from(product);

        if (!copy.containsKey('FİYAT (Metre)') &&
            copy.containsKey(fiyatColumn)) {
          copy['FİYAT (Metre)'] = copy[fiyatColumn];
        }

        if (!copy.containsKey('FİYAT (Metre)') &&
            copy.containsKey('fiyatDegeri')) {
          copy['FİYAT (Metre)'] = copy['fiyatDegeri'];
        }

        copy['iskontoOrani'] = iskontoValue;
        copy['kdvOrani'] = kdvValue;

        productCopies.add(copy);
      }

      final calculation = CalculationHistory(
        date: DateTime.now(),
        excelType: excelType,
        productCount: productCopies.length,
        totalAmount: toplamTutar.value,
        netAmount: netTutar.value,
        products: productCopies,
        customerName: customerName,
      );

      calculationHistory.insert(0, calculation);

      if (calculationHistory.length > maxHistoryCount) {
        calculationHistory.removeRange(
            maxHistoryCount, calculationHistory.length);
      }

      await saveHistoryToStorage();
    }
  }

  // Geçmişi kalıcı depolamaya kaydet
  static Future<void> saveHistoryToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJsonList =
          calculationHistory.map((calc) => calc.toJson()).toList();
      await prefs.setString('calculation_history', jsonEncode(historyJsonList));
    } catch (e) {}
  }

  // Geçmişi kalıcı depolamadan yükle
  static Future<void> loadHistoryFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('calculation_history');

      if (historyJson != null && historyJson.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(historyJson);
        calculationHistory.value =
            jsonList.map((json) => CalculationHistory.fromJson(json)).toList();
      }
    } catch (e) {}
  }

  // Tüm hesaplama geçmişini silme
  static Future<void> clearAllHistory() async {
    try {
      calculationHistory.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('calculation_history');

      Get.snackbar(
        'Başarılı',
        'Tüm hesaplama geçmişi silindi',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar(
        'Hata',
        'Hesaplama geçmişi silinirken bir hata oluştu: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
      );
    }
  }

  // Seçilen hesaplamaları silme
  static Future<void> deleteSelectedCalculations(
      List<CalculationHistory> selectedCalculations) async {
    try {
      if (selectedCalculations.isEmpty) return;

      calculationHistory
          .removeWhere((calc) => selectedCalculations.contains(calc));

      await saveHistoryToStorage();

      Get.snackbar(
        'Başarılı',
        '${selectedCalculations.length} hesaplama silindi',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar(
        'Hata',
        'Hesaplamalar silinirken bir hata oluştu: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
      );
    }
  }

  // Hesaplama geçmişi için PDF oluştur
  static Future<File?> generateCalculationPdf(CalculationHistory calculation,
      {String? fiyatColumn}) async {
    try {
      bool hasProfilBoyu = false;
      bool hasPaket = false;

      if (calculation.products.isNotEmpty) {
        for (var product in calculation.products) {
          if (product.containsKey('profilBoyuDegeri')) {
            final value = product['profilBoyuDegeri'];
            if (value != null && (value is num) && value > 0) {
              hasProfilBoyu = true;
            }
          }

          if (product.containsKey('paketDegeri')) {
            final value = product['paketDegeri'];
            if (value != null && (value is num) && value > 0) {
              hasPaket = true;
            }
          }
        }

        bool containsPrice = false;
        String usedPriceColumn = "";

        List<String> possiblePriceColumns = [
          'FİYAT (Metre)',
          'fiyatDegeri',
          'FIYAT',
          'fiyat',
          'METER_PRICE'
        ];

        for (var priceCol in possiblePriceColumns) {
          if (calculation.products[0].containsKey(priceCol)) {
            containsPrice = true;
            usedPriceColumn = priceCol;
            break;
          }
        }

        if (!containsPrice) {
          for (var key in calculation.products[0].keys) {
            if (calculation.products[0][key] is num) {
              var value = calculation.products[0][key];
              if (value is num && value > 10) {
                containsPrice = true;
                usedPriceColumn = key;
                break;
              }
            }
          }
        }

        if (containsPrice) {
          fiyatColumn = usedPriceColumn;
        }
      }

      bool needsPermission = false;
      if (Platform.isAndroid) {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        int sdkVersion = androidInfo.version.sdkInt;

        if (sdkVersion < 30) {
          needsPermission = true;
        }
      }

      if (needsPermission) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            Get.snackbar(
              'Hata',
              'PDF indirmek için depolama izni gereklidir',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.red.shade100,
              colorText: Colors.red.shade800,
            );
            return null;
          }
        }
      }

      final pdf = pw.Document(
        compress: true,
        version: PdfVersion.pdf_1_5,
        pageMode: PdfPageMode.outlines,
      );

      final ByteData logoData =
          await rootBundle.load('assets/images/osmyapilogo.jpg');
      final Uint8List logoBytes = logoData.buffer.asUint8List();

      final dateFormatter = DateFormat('dd.MM.yyyy HH:mm');
      final formattedDate = dateFormatter.format(calculation.date);

      double iskontoOrani = 0.0;
      double kdvOrani = 0.0;
      bool hasIskonto = false;
      bool hasKdv = false;

      if (calculation.products.isNotEmpty) {
        if (calculation.products[0].containsKey('iskontoOrani')) {
          var iskontoValue = calculation.products[0]['iskontoOrani'];
          if (iskontoValue is num && iskontoValue > 0) {
            iskontoOrani = iskontoValue.toDouble();
            hasIskonto = true;
          }
        }

        if (calculation.products[0].containsKey('kdvOrani')) {
          var kdvValue = calculation.products[0]['kdvOrani'];
          if (kdvValue is num && kdvValue > 0) {
            kdvOrani = kdvValue.toDouble();
            hasKdv = true;
          }
        }
      }

      if (!hasIskonto &&
          calculation.totalAmount > 0 &&
          calculation.netAmount > 0) {
        if (calculation.totalAmount != calculation.netAmount) {
          hasIskonto = true;
          hasKdv = true;
          if (calculation.totalAmount > calculation.netAmount) {
            iskontoOrani =
                100 * (1 - calculation.netAmount / calculation.totalAmount);
          } else {
            kdvOrani =
                100 * (calculation.netAmount / calculation.totalAmount - 1);
          }
        }
      }

      String fixTurkishChars(String text) {
        return text
            .replaceAll('ı', 'i')
            .replaceAll('İ', 'I')
            .replaceAll('ğ', 'g')
            .replaceAll('Ğ', 'G')
            .replaceAll('ü', 'u')
            .replaceAll('Ü', 'U')
            .replaceAll('ş', 's')
            .replaceAll('Ş', 'S')
            .replaceAll('ö', 'o')
            .replaceAll('Ö', 'O')
            .replaceAll('ç', 'c')
            .replaceAll('Ç', 'C');
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Image(pw.MemoryImage(logoBytes), width: 120),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('OSM YAPI',
                              style: pw.TextStyle(
                                  fontSize: 24,
                                  fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 5),
                          pw.Text('Satis Raporu',
                              style: pw.TextStyle(fontSize: 16)),
                        ],
                      )
                    ]),
                pw.SizedBox(height: 5),
                pw.Divider(),
              ],
            );
          },
          build: (pw.Context context) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Satis Detaylari',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 14)),
                      pw.Text('Tarih: $formattedDate',
                          style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    children: [
                      pw.Expanded(
                          child: pw.Text(
                              'Urun Sayisi: ${calculation.productCount}')),
                    ],
                  ),
                  if (calculation.customerName.isNotEmpty) ...[
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Musteri/Kurum: ${fixTurkishChars(calculation.customerName)}',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Urun Listesi',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(3),
                if (hasProfilBoyu) 2: const pw.FlexColumnWidth(1),
                if (hasPaket)
                  (hasProfilBoyu ? 3 : 2): const pw.FlexColumnWidth(1),
                (hasProfilBoyu && hasPaket)
                        ? 4
                        : (hasProfilBoyu || hasPaket ? 3 : 2):
                    const pw.FlexColumnWidth(1.2),
                (hasProfilBoyu && hasPaket)
                        ? 5
                        : (hasProfilBoyu || hasPaket ? 4 : 3):
                    const pw.FlexColumnWidth(1.2),
                if (hasIskonto)
                  ((hasProfilBoyu && hasPaket)
                          ? 6
                          : (hasProfilBoyu || hasPaket ? 5 : 4)):
                      const pw.FlexColumnWidth(1.2),
                if (hasKdv)
                  ((hasProfilBoyu && hasPaket)
                          ? (hasIskonto ? 7 : 6)
                          : (hasProfilBoyu || hasPaket
                              ? (hasIskonto ? 6 : 5)
                              : (hasIskonto ? 5 : 4))):
                      const pw.FlexColumnWidth(1.2),
                ((hasProfilBoyu && hasPaket)
                        ? (hasIskonto ? (hasKdv ? 8 : 7) : (hasKdv ? 7 : 6))
                        : (hasProfilBoyu || hasPaket
                            ? (hasIskonto ? (hasKdv ? 7 : 6) : (hasKdv ? 6 : 5))
                            : (hasIskonto
                                ? (hasKdv ? 6 : 5)
                                : (hasKdv ? 5 : 4)))):
                    const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Urun Kodu',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Urun Adi',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    if (hasProfilBoyu)
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Profil Boyu',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    if (hasPaket)
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Paket',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Toplam Metretül',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Liste Fiyati',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    if (hasIskonto)
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Iskontolu Birim Fiyat',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    if (hasKdv)
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('KDV\'li Birim Fiyat',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Toplam',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                for (var product in calculation.products)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(product.containsKey('ÜRÜN KODU')
                            ? fixTurkishChars(product['ÜRÜN KODU'].toString())
                            : ''),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(product.containsKey('ÜRÜN ADI')
                            ? fixTurkishChars(product['ÜRÜN ADI'].toString())
                            : ''),
                      ),
                      if (hasProfilBoyu)
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(product.containsKey('profilBoyuDegeri')
                              ? (() {
                                  final value = product['profilBoyuDegeri'];

                                  return value % 1 == 0
                                      ? '${value.toInt()}'
                                      : '${value.toStringAsFixed(2)}';
                                })()
                              : '0'),
                        ),
                      if (hasPaket)
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(product.containsKey('paketDegeri')
                              ? (() {
                                  final value = product['paketDegeri'];
                                  return value % 1 == 0
                                      ? '${value.toInt()}'
                                      : '${value.toStringAsFixed(2)}';
                                })()
                              : '0'),
                        ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(product.containsKey('toplamDeger')
                            ? (() {
                                final value = product['toplamDeger'];
                                return value % 1 == 0
                                    ? '${value.toInt()}'
                                    : '${value.toStringAsFixed(2)}';
                              })()
                            : '1'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          (() {
                            List<String> priceFields = [
                              'FİYAT (Metre)',
                              'fiyatDegeri',
                              'FIYAT',
                              'fiyat',
                              'METER_PRICE'
                            ];

                            if (fiyatColumn != null && fiyatColumn.isNotEmpty) {
                              priceFields.add(fiyatColumn);
                            }

                            for (var field in priceFields) {
                              if (product.containsKey(field)) {
                                var fiyat = product[field];

                                if (fiyat is num) {
                                  return '${fiyat.toStringAsFixed(2)} TL';
                                } else if (fiyat is String) {
                                  String cleanFiyat =
                                      fiyat.replaceAll(RegExp(r'[^0-9.,]'), '');
                                  double? parsedFiyat = double.tryParse(
                                      cleanFiyat.replaceAll(',', '.'));
                                  if (parsedFiyat != null) {
                                    return '${parsedFiyat.toStringAsFixed(2)} TL';
                                  }
                                  return '$fiyat TL';
                                }
                              }
                            }

                            for (var key in product.keys) {
                              var value = product[key];
                              if (value is num &&
                                  value > 10 &&
                                  ![
                                    'hesaplananTutar',
                                    'toplamDeger',
                                    'profilBoyuDegeri',
                                    'paketDegeri'
                                  ].contains(key)) {
                                return '${value.toStringAsFixed(2)} TL';
                              }
                            }

                            return '';
                          })(),
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ),
                      if (hasIskonto)
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            (() {
                              double listeFiyati = 0.0;
                              for (var field in [
                                'FİYAT (Metre)',
                                'fiyatDegeri',
                                'FIYAT',
                                'fiyat',
                                'METER_PRICE'
                              ]) {
                                if (product.containsKey(field)) {
                                  var fiyat = product[field];
                                  if (fiyat is num) {
                                    listeFiyati = fiyat.toDouble();
                                    break;
                                  } else if (fiyat is String) {
                                    String cleanFiyat = fiyat.replaceAll(
                                        RegExp(r'[^0-9.,]'), '');
                                    double? parsedFiyat = double.tryParse(
                                        cleanFiyat.replaceAll(',', '.'));
                                    if (parsedFiyat != null) {
                                      listeFiyati = parsedFiyat;
                                      break;
                                    }
                                  }
                                }
                              }

                              double iskontoluBirimFiyat =
                                  listeFiyati * (1 - iskontoOrani / 100);
                              return '${iskontoluBirimFiyat.toStringAsFixed(2)} TL';
                            })(),
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                        ),
                      if (hasKdv)
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            (() {
                              double listeFiyati = 0.0;
                              for (var field in [
                                'FİYAT (Metre)',
                                'fiyatDegeri',
                                'FIYAT',
                                'fiyat',
                                'METER_PRICE'
                              ]) {
                                if (product.containsKey(field)) {
                                  var fiyat = product[field];
                                  if (fiyat is num) {
                                    listeFiyati = fiyat.toDouble();
                                    break;
                                  } else if (fiyat is String) {
                                    String cleanFiyat = fiyat.replaceAll(
                                        RegExp(r'[^0-9.,]'), '');
                                    double? parsedFiyat = double.tryParse(
                                        cleanFiyat.replaceAll(',', '.'));
                                    if (parsedFiyat != null) {
                                      listeFiyati = parsedFiyat;
                                      break;
                                    }
                                  }
                                }
                              }

                              double iskontoluBirimFiyat = hasIskonto
                                  ? listeFiyati * (1 - iskontoOrani / 100)
                                  : listeFiyati;

                              double kdvliBirimFiyat =
                                  iskontoluBirimFiyat * (1 + kdvOrani / 100);
                              return '${kdvliBirimFiyat.toStringAsFixed(2)} TL';
                            })(),
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                        ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          (() {
                            double toplamMetretul = 1.0;
                            if (product.containsKey('toplamDeger')) {
                              var value = product['toplamDeger'];
                              toplamMetretul =
                                  value is num ? value.toDouble() : 1.0;
                            }

                            double listeFiyati = 0.0;
                            for (var field in [
                              'FİYAT (Metre)',
                              'fiyatDegeri',
                              'FIYAT',
                              'fiyat',
                              'METER_PRICE'
                            ]) {
                              if (product.containsKey(field)) {
                                var fiyat = product[field];
                                if (fiyat is num) {
                                  listeFiyati = fiyat.toDouble();
                                  break;
                                } else if (fiyat is String) {
                                  String cleanFiyat =
                                      fiyat.replaceAll(RegExp(r'[^0-9.,]'), '');
                                  double? parsedFiyat = double.tryParse(
                                      cleanFiyat.replaceAll(',', '.'));
                                  if (parsedFiyat != null) {
                                    listeFiyati = parsedFiyat;
                                    break;
                                  }
                                }
                              }
                            }

                            double iskontoluBirimFiyat = hasIskonto
                                ? listeFiyati * (1 - iskontoOrani / 100)
                                : listeFiyati;

                            double kdvliBirimFiyat = hasKdv
                                ? iskontoluBirimFiyat * (1 + kdvOrani / 100)
                                : iskontoluBirimFiyat;

                            double hesaplananToplam;
                            if (hasKdv) {
                              hesaplananToplam =
                                  kdvliBirimFiyat * toplamMetretul;
                            } else {
                              hesaplananToplam =
                                  iskontoluBirimFiyat * toplamMetretul;
                            }

                            return '${hesaplananToplam.toStringAsFixed(2)} TL';
                          })(),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              child: pw.Column(
                children: [
                  pw.SizedBox(height: 5),
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('NET TUTAR',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 14)),
                      pw.Text('${calculation.netAmount.toStringAsFixed(2)} TL',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  if (!hasKdv) ...[
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                            fixTurkishChars(
                                'Fiyatlarımıza KDV Dahil Değildir.'),
                            style: pw.TextStyle(
                                fontSize: 12, fontStyle: pw.FontStyle.italic)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          footer: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Divider(),
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text('OSM Yapi - Tum haklari saklidir',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            );
          },
        ),
      );

      final String fileName =
          'OSM_YAPI_Hesaplama_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

      Directory? directory;
      File file;

      if (Platform.isAndroid) {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        int sdkVersion = androidInfo.version.sdkInt;

        if (sdkVersion >= 30) {
          directory = await getApplicationDocumentsDirectory();
          file = File('${directory.path}/$fileName');
          await file.writeAsBytes(await pdf.save());

          Get.snackbar(
            'Başarılı',
            'PDF oluşturuldu, açılıyor...',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.shade100,
            colorText: Colors.green.shade800,
            duration: const Duration(seconds: 3),
          );

          await OpenFile.open(file.path);
        } else {
          directory = await getExternalStorageDirectory();
          if (directory == null) {
            Get.snackbar(
              'Hata',
              'Dosya kaydetmek için uygun klasör bulunamadı',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.red.shade100,
              colorText: Colors.red.shade800,
            );
            return null;
          }

          file = File('${directory.path}/$fileName');
          await file.writeAsBytes(await pdf.save());

          Get.snackbar(
            'Başarılı',
            'PDF indirildi: $fileName',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.shade100,
            colorText: Colors.green.shade800,
            duration: const Duration(seconds: 3),
          );

          await OpenFile.open(file.path);
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
        file = File('${directory.path}/$fileName');
        await file.writeAsBytes(await pdf.save());

        Get.snackbar(
          'Başarılı',
          'PDF oluşturuldu, açılıyor...',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
          colorText: Colors.green.shade800,
          duration: const Duration(seconds: 3),
        );

        await OpenFile.open(file.path);
      } else {
        directory = await getDownloadsDirectory();
        if (directory == null) {
          Get.snackbar(
            'Hata',
            'Dosya kaydetmek için uygun klasör bulunamadı',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.shade100,
            colorText: Colors.red.shade800,
          );
          return null;
        }

        file = File('${directory.path}/$fileName');
        await file.writeAsBytes(await pdf.save());

        Get.snackbar(
          'Başarılı',
          'PDF indirildi: $fileName',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
          colorText: Colors.green.shade800,
          duration: const Duration(seconds: 3),
        );

        await OpenFile.open(file.path);
      }

      return file;
    } catch (e) {
      Get.snackbar(
        'Hata',
        'PDF oluşturulurken bir hata oluştu: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
      );
      return null;
    }
  }

  // Depolama izni kontrolü için kullanıcı dostu diyalog
  static Future<bool> requestStoragePermission(BuildContext context) async {
    if (Platform.isAndroid) {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      int sdkVersion = androidInfo.version.sdkInt;

      if (sdkVersion >= 30) {
        return true;
      }

      final status = await Permission.storage.status;

      if (status.isGranted) {
        return true;
      }

      bool showRationale = await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Depolama İzni Gerekli'),
                content: Text(
                    'PDF dosyalarını telefona indirebilmek için depolama izni gerekiyor. '
                    'Bu izin, hesaplama sonuçlarınızı PDF olarak kaydetmek ve daha sonra erişebilmek için kullanılacaktır.'),
                actions: [
                  TextButton(
                    child: Text('İptal'),
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                  ),
                  ElevatedButton(
                    child: Text('İzin Ver'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3C3C3C),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                  ),
                ],
              );
            },
          ) ??
          false;

      if (showRationale) {
        final permissionResult = await Permission.storage.request();
        return permissionResult.isGranted;
      }

      return false;
    }

    return true;
  }

  // Hesaplama düzenlemek için ürünleri yükle
  void loadProductsForEditing() {
    if (calculationToEdit != null) {
      selectedProducts.clear();
      profilBoyuControllers.forEach((_, controller) => controller.dispose());
      paketControllers.forEach((_, controller) => controller.dispose());
      profilBoyuControllers.clear();
      paketControllers.clear();

      int index = 0;
      for (var product in calculationToEdit!.products) {
        selectedProducts.add(Map<String, dynamic>.from(product));

        var profilBoyu = "";
        var paket = "";

        if (product.containsKey('profilBoyuDegeri')) {
          final value = product['profilBoyuDegeri'];
          if (value is num && value > 0) {
            profilBoyu = value.toString();
          }
        }

        if (product.containsKey('paketDegeri')) {
          final value = product['paketDegeri'];
          if (value is num && value > 0) {
            paket = value.toString();
          }
        }

        profilBoyuControllers[index] = TextEditingController(text: profilBoyu);
        paketControllers[index] = TextEditingController(text: paket);

        profilBoyuControllers[index]!.addListener(() {
          calculateTotalPrice();
        });

        paketControllers[index]!.addListener(() {
          calculateTotalPrice();
        });

        index++;
      }

      if (calculationToEdit!.products.isNotEmpty) {
        var firstProduct = calculationToEdit!.products[0];

        if (firstProduct.containsKey('iskontoOrani')) {
          var iskonto = firstProduct['iskontoOrani'];
          if (iskonto is num) {
            iskontoController.text = iskonto.toString();
          }
        }

        if (firstProduct.containsKey('kdvOrani')) {
          var kdv = firstProduct['kdvOrani'];
          if (kdv is num) {
            kdvController.text = kdv.toString();
          }
        }
      }

      calculateTotalPrice();
    }
  }

  // Düzenlenen hesaplamayı güncelle
  static Future<void> updateCalculation(
      CalculationHistory updatedCalculation) async {
    try {
      if (calculationToEditIndex != null &&
          calculationToEditIndex! >= 0 &&
          calculationToEditIndex! < calculationHistory.length) {
        calculationHistory[calculationToEditIndex!] = updatedCalculation;

        await saveHistoryToStorage();

        Get.snackbar(
          'Başarılı',
          'Hesaplama başarıyla güncellendi',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green.shade100,
          colorText: Colors.green.shade800,
          duration: const Duration(seconds: 3),
          icon: const Icon(Icons.check_circle, color: Colors.green),
          boxShadows: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            )
          ],
        );
      }

      calculationToEdit = null;
      calculationToEditIndex = null;
    } catch (e) {
      Get.snackbar(
        'Hata',
        'Hesaplama güncellenirken bir hata oluştu: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
        duration: const Duration(seconds: 3),
      );
    }
  }
}
