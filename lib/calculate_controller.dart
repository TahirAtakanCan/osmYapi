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

// Hesaplama geçmişini saklamak için model sınıfı
class CalculationHistory {
  final DateTime date;
  final String excelType; // 58 nolu veya 59 nolu
  final int productCount;
  final double totalAmount;
  final double netAmount;
  final List<Map<String, dynamic>> products;
  final String customerName; // Müşteri/kurum adı

  CalculationHistory({
    required this.date,
    required this.excelType,
    required this.productCount,
    required this.totalAmount,
    required this.netAmount,
    required this.products,
    required this.customerName, // Müşteri adı eklendi
  });

  // JSON'a çevirme
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'excelType': excelType,
      'productCount': productCount,
      'totalAmount': totalAmount,
      'netAmount': netAmount,
      'products': products,
      'customerName': customerName, // Müşteri adı JSON'a eklendi
    };
  }

  // JSON'dan oluşturma
  factory CalculationHistory.fromJson(Map<String, dynamic> json) {
    return CalculationHistory(
      date: DateTime.parse(json['date']),
      excelType: json['excelType'],
      productCount: json['productCount'],
      totalAmount: json['totalAmount'],
      netAmount: json['netAmount'],
      products: List<Map<String, dynamic>>.from(json['products']),
      customerName: json['customerName'] ?? '', // JSON'dan müşteri adı alınıyor
    );
  }
}

class CalculateController extends GetxController {
  // Hesaplama geçmişi
  static RxList<CalculationHistory> calculationHistory = <CalculationHistory>[].obs;
  
  // En fazla saklanacak geçmiş sayısı
  static const int maxHistoryCount = 100;
  
  // Excel dosya tipi (58 nolu, 59 nolu)
  String excelType = '';

  RxList<Map<String, dynamic>> excelData = <Map<String, dynamic>>[].obs;
  RxList<Map<String, dynamic>> filteredExcelData = <Map<String, dynamic>>[].obs;
  RxString selectedGroup = "Tüm Ürünler".obs;

  
  final Map<String, Map<String, dynamic>> groupDefinitions = {
    "Tüm Ürünler": {"startRow": 0, "endRow": -1},
    "60 Serisi Ana Profiller": {"startRow": 0, "endRow": 23},
    "60 3 Odacık Serisi Ana Profiller": {"startRow": 24, "endRow": 36},
    "70 Süper Seri Profiller": {"startRow": 37, "endRow": 62},
    "80 Seri Profiller": {"startRow": 63, "endRow": 86},
    "Sürme Serisi Profiller": {"startRow": 87, "endRow": 122},
    "Yalıtımlı Sürme Serisi": {"startRow": 123, "endRow": 144},
    "Yardımcı Profiller": {"startRow": 145, "endRow": 185},
  };
  
  
  RxList<Map<String, dynamic>> selectedProducts = <Map<String, dynamic>>[].obs;
  
  
  RxDouble toplamTutar = 0.0.obs;
  RxDouble netTutar = 0.0.obs;
  RxDouble iskontoTutar = 0.0.obs;
  RxDouble kdvTutar = 0.0.obs;
  
  
  final iskontoController = TextEditingController(text: '');
  final kdvController = TextEditingController(text: '');
  
  
  final Map<int, TextEditingController> profilBoyuControllers = {};
  final Map<int, TextEditingController> paketControllers = {};
  
  
  RxBool isLoading = true.obs;
  
  
  String codeColumn = '';
  String nameColumn = '';
  String profilBoyuColumn = 'PROFİL BOYU (metre)';
  String paketColumn = 'PAKET';
  String fiyatColumn = '';

  // Controller'ın başlatılması
  @override
  void onInit() {
    super.onInit();
    
    // İskonto ve KDV controller'ları için listener ekleyin
    iskontoController.addListener(_calculateNetTutar);
    kdvController.addListener(_calculateNetTutar);
  }

  @override
  void onClose() {
    // Controller'ları temizle
    iskontoController.dispose();
    kdvController.dispose();
    profilBoyuControllers.forEach((_, controller) => controller.dispose());
    paketControllers.forEach((_, controller) => controller.dispose());
    super.onClose();
  }

  
  void filterByGroup(String groupName) {
    selectedGroup.value = groupName;
    
    if (groupName == "Tüm Ürünler") {
      filteredExcelData.assignAll(excelData);
      return;
    }
    
    var groupInfo = groupDefinitions[groupName];
    if (groupInfo != null) {
      int startRow = groupInfo["startRow"] as int;
      int endRow = groupInfo["endRow"] as int;
      
      if (endRow == -1) {
        endRow = excelData.length - 1;
      }
      
      List<Map<String, dynamic>> filtered = [];
      for (int i = 0; i < excelData.length; i++) {
        if (i >= startRow && i <= endRow) {
          filtered.add(excelData[i]);
        }
      }
      
      filteredExcelData.assignAll(filtered);
    }
  }

  // Ürün ekleme fonksiyonu
  void addProduct(Map<String, dynamic> product) {
    if (product != null) {
      // Ürünün zaten eklenip eklenmediğini kontrol et
      bool isAlreadyAdded = false;
      if (codeColumn.isNotEmpty && nameColumn.isNotEmpty) {
        isAlreadyAdded = selectedProducts.any(
          (existingProduct) => 
            existingProduct[codeColumn] == product[codeColumn] && 
            existingProduct[nameColumn] == product[nameColumn]
        );
      }
      
      if (!isAlreadyAdded) {
        final newProductIndex = selectedProducts.length;
        
        // Ürünü ekle
        selectedProducts.add(Map<String, dynamic>.from(product));
        
        // Profil Boyu ve Paket controller'ları oluştur
        profilBoyuControllers[newProductIndex] = TextEditingController(text: '1');
        paketControllers[newProductIndex] = TextEditingController(text: '1');
        
        // Her iki controller'a da listener ekle
        profilBoyuControllers[newProductIndex]!.addListener(() {
          calculateTotalPrice();
        });
        
        paketControllers[newProductIndex]!.addListener(() {
          calculateTotalPrice();
        });
        
        calculateTotalPrice();
      } else {
        // Kullanıcıya bildir (bu kısım UI'da gösterilecek)
        Get.snackbar(
          'Uyarı',
          'Bu ürün zaten eklenmiş!',
          snackPosition: SnackPosition.BOTTOM
        );
      }
    }
  }

  // Ürün silme fonksiyonu
  void removeProduct(int index) {
    if (index >= 0 && index < selectedProducts.length) {
      profilBoyuControllers[index]?.dispose();
      paketControllers[index]?.dispose();
      selectedProducts.removeAt(index);
      
      // Controller'ları yeniden indeksle
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

  // Toplam tutarı hesaplama fonksiyonu
  void calculateTotalPrice() {
    double total = 0.0;
    
    for (int i = 0; i < selectedProducts.length; i++) {
      final product = selectedProducts[i];
      final profilBoyuController = profilBoyuControllers[i];
      final paketController = paketControllers[i];
      
      if (profilBoyuController != null && paketController != null) {
        // Profil Boyu ve Paket değerlerini al (boş değer kontrolünü değiştirdim)
        final profilBoyuValue = profilBoyuController.text.isEmpty 
            ? 0.0 
            : double.tryParse(profilBoyuController.text) ?? 0.0;
        
        final paketValue = paketController.text.isEmpty 
            ? 0.0 
            : double.tryParse(paketController.text) ?? 0.0;
        
        // Excel'deki değerleri al
        double excelProfilBoyuValue = 0.0;
        double excelPaketValue = 0.0;
        
        if (profilBoyuColumn.isNotEmpty && product.containsKey(profilBoyuColumn)) {
          var value = product[profilBoyuColumn];
          excelProfilBoyuValue = value is double ? value : double.tryParse(value.toString()) ?? 0.0;
        }
        
        if (paketColumn.isNotEmpty && product.containsKey(paketColumn)) {
          var value = product[paketColumn];
          excelPaketValue = value is double ? value : double.tryParse(value.toString()) ?? 0.0;
        }
        
        // Hesaplama: (Profil Boyu * Excel Profil Boyu) + (Paket * Excel Paket)
        double toplamDeger = (profilBoyuValue * excelProfilBoyuValue) + (paketValue * excelPaketValue);
        
        // Eğer fiyat sütunu bulunabilmişse hesapla
        if (fiyatColumn.isNotEmpty && product.containsKey(fiyatColumn)) {
          // Toplamı ürün fiyatı ile çarp
          var fiyatValue = product[fiyatColumn];
          double metreFiyati = fiyatValue is double ? fiyatValue : double.tryParse(fiyatValue.toString()) ?? 0.0;
          double urunTutari = metreFiyati * toplamDeger;
          total += urunTutari;
          
          // Hesaplanan değerleri ürün bilgisine ekle (sonraki gösterimler için)
          product['hesaplananTutar'] = urunTutari;
          product['toplamDeger'] = toplamDeger;
          product['profilBoyuDegeri'] = profilBoyuValue;
          product['paketDegeri'] = paketValue;
          selectedProducts[i] = product; // Gözlenebilir diziyi güncelle
        }
      }
    }
    
    toplamTutar.value = total;
    _calculateNetTutar();
  }

  // Net tutarı hesaplama fonksiyonu
  void _calculateNetTutar() {
    final iskonto = double.tryParse(iskontoController.text) ?? 0.0;
    
    // KDV alanı boşsa veya geçersizse KDV hesaplanmayacak
    final kdvText = kdvController.text.trim();
    final double? kdv = kdvText.isEmpty ? null : double.tryParse(kdvText);
    
    final iskontoMiktar = toplamTutar.value * iskonto / 100;
    final aratutar = toplamTutar.value - iskontoMiktar;
    
    // KDV değeri varsa hesapla, yoksa 0 olarak ayarla
    final kdvMiktar = kdv != null ? aratutar * kdv / 100 : 0.0;
    
    iskontoTutar.value = iskontoMiktar;
    kdvTutar.value = kdvMiktar;
    netTutar.value = aratutar + kdvMiktar;
  }

  // Ürün kodunun sütun adını belirle
  void setColumnNames() {
    if (excelData.isNotEmpty) {
      // Ürün Kodu sütunu
      if (excelData[0].containsKey('ÜRÜN KODU')) {
        codeColumn = 'ÜRÜN KODU';
      } else {
        // Alternatif isimler
        for (var key in excelData[0].keys) {
          if (key.toLowerCase().contains('kod') || key.toLowerCase().contains('code')) {
            codeColumn = key;
            break;
          }
        }
        // İlk sütunu kullan
        if (codeColumn.isEmpty && excelData[0].keys.isNotEmpty) {
          codeColumn = excelData[0].keys.first;
        }
      }

      // Ürün Adı sütunu
      if (excelData[0].containsKey('ÜRÜN ADI')) {
        nameColumn = 'ÜRÜN ADI';
      } else {
        // Alternatif isimler
        for (var key in excelData[0].keys) {
          if (key.toLowerCase().contains('ad') || key.toLowerCase().contains('name') || 
              key.toLowerCase().contains('ürün') || key.toLowerCase().contains('product')) {
            nameColumn = key;
            break;
          }
        }
        // İkinci sütunu kullan (varsa)
        var keys = excelData[0].keys.toList();
        if (nameColumn.isEmpty && keys.length > 1) {
          nameColumn = keys[1];
        }
      }

      // Profil Boyu sütunu
      if (excelData[0].containsKey('PROFİL BOYU (metre)')) {
        profilBoyuColumn = 'PROFİL BOYU (metre)';
      } else {
        // Alternatif isimler
        for (var key in excelData[0].keys) {
          if (key.toLowerCase().contains('profil') && key.toLowerCase().contains('boy')) {
            profilBoyuColumn = key;
            break;
          }
        }
      }

      // Paket sütunu
      if (excelData[0].containsKey('PAKET')) {
        paketColumn = 'PAKET';
      } else {
        // Alternatif isimler
        for (var key in excelData[0].keys) {
          if (key.toLowerCase().contains('paket')) {
            paketColumn = key;
            break;
          }
        }
      }

      // Fiyat sütunu
      if (excelData[0].containsKey('FİYAT (Metre)')) {
        fiyatColumn = 'FİYAT (Metre)';
      } else {
        // Alternatif isimler
        for (var key in excelData[0].keys) {
          if (key.toLowerCase().contains('fiyat') || key.toLowerCase().contains('ücret') || 
              key.toLowerCase().contains('tutar') || key.toLowerCase().contains('price')) {
            fiyatColumn = key;
            break;
          }
        }
        // Son sayısal değeri içeren sütunu kullan
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

      print('Sütun isimleri: Kod=$codeColumn, Ad=$nameColumn, ProfilBoyu=$profilBoyuColumn, Paket=$paketColumn, Fiyat=$fiyatColumn');
    }
  }

  // Excel verisini ayarla
  void setExcelData(List<Map<String, dynamic>> data) {
    excelData.assignAll(data);
    filteredExcelData.assignAll(data); // Başlangıçta tüm verileri filtreli veriler olarak göster
    setColumnNames();
    isLoading.value = false;
  }
  
  // Excel dosya tipini ayarla (58 nolu, 59 nolu)
  void setExcelType(String type) {
    excelType = type;
  }
  
  // Hesaplamayı kaydet
  Future<void> saveCalculation(String customerName) async {
    // Eğer en az 3 ürün eklenmişse kaydet
    if (selectedProducts.length >= 2) {
      final calculation = CalculationHistory(
        date: DateTime.now(),
        excelType: excelType,
        productCount: selectedProducts.length,
        totalAmount: toplamTutar.value,
        netAmount: netTutar.value,
        products: selectedProducts.map((p) => Map<String, dynamic>.from(p)).toList(),
        customerName: customerName, // Müşteri/kurum adı kaydediliyor
      );
      
      // Geçmişe ekle
      calculationHistory.insert(0, calculation);
      
      // Maksimum 10 kayıt tut
      if (calculationHistory.length > maxHistoryCount) {
        calculationHistory.removeRange(maxHistoryCount, calculationHistory.length);
      }
      
      // Kalıcı depolama için kaydet
      await saveHistoryToStorage();
    }
  }
  
  // Geçmişi kalıcı depolamaya kaydet
  static Future<void> saveHistoryToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJsonList = calculationHistory.map((calc) => calc.toJson()).toList();
      await prefs.setString('calculation_history', jsonEncode(historyJsonList));
    } catch (e) {
      print('Hesaplama geçmişi kaydedilemedi: $e');
    }
  }
  
  // Geçmişi kalıcı depolamadan yükle
  static Future<void> loadHistoryFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('calculation_history');
      
      if (historyJson != null && historyJson.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(historyJson);
        calculationHistory.value = jsonList
            .map((json) => CalculationHistory.fromJson(json))
            .toList();
      }
    } catch (e) {
      print('Hesaplama geçmişi yüklenemedi: $e');
    }
  }

  // Hesaplama geçmişi için PDF oluştur
  static Future<File?> generateCalculationPdf(CalculationHistory calculation) async {
    try {
      // Android sürümünü kontrol et
      bool needsPermission = false;
      if (Platform.isAndroid) {
        // API 30 (Android 11) ve sonrasında özel izinler gerekmiyor çünkü uygulama kendi dizinine yazabilir
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        int sdkVersion = androidInfo.version.sdkInt;
        
        // Android 10 ve öncesi için depolama izni gerekiyor
        if (sdkVersion < 30) {
          needsPermission = true;
        }
      }
      
      // Gerekiyorsa izin iste
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
      
      // PDF dokümanı oluştur
      final pdf = pw.Document();
      
      // OSM Yapı logosu ekle
      final ByteData logoData = await rootBundle.load('assets/images/osmyapilogo.jpg');
      final Uint8List logoBytes = logoData.buffer.asUint8List();

      // Bugünün tarihini formatla
      final dateFormatter = DateFormat('dd.MM.yyyy HH:mm');
      final formattedDate = dateFormatter.format(calculation.date);
      
      // PDF'e içerik ekle
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
                        pw.Text('OSM YAPI', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 5),
                        pw.Text('Hesaplama Raporu', style: pw.TextStyle(fontSize: 16)),
                      ],
                    )
                  ]
                ),
                pw.SizedBox(height: 5),
                pw.Divider(),
              ],
            );
          },
          build: (pw.Context context) => [
            // Müşteri ve Hesaplama Bilgileri
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
                      pw.Text('Hesaplama Detaylari', 
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)
                      ),
                      pw.Text('Tarih: $formattedDate', style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    children: [
                      pw.Expanded(child: pw.Text('Excel Tipi: ${calculation.excelType}')),
                      pw.Expanded(child: pw.Text('Urun Sayisi: ${calculation.productCount}')),
                    ],
                  ),
                  if (calculation.customerName.isNotEmpty) ...[
                    pw.SizedBox(height: 5),
                    pw.Text('Musteri/Kurum: ${calculation.customerName}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Ürün Listesi Tablosu
            pw.Text('Urun Listesi', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Tablo Başlığı
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Urun Kodu', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Urun Adi', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Profil Boyu', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Paket', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Toplam', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                
                // Ürün Satırları
                for (var product in calculation.products)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(product.containsKey('ÜRÜN KODU') ? product['ÜRÜN KODU'].toString() : ''),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(product.containsKey('ÜRÜN ADI') ? product['ÜRÜN ADI'].toString() : ''),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(product.containsKey('profilBoyuDegeri') 
                          ? '${product['profilBoyuDegeri'].toString()} m' 
                          : '1.0 m'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(product.containsKey('paketDegeri') 
                          ? '${product['paketDegeri'].toString()}' 
                          : '1'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(product.containsKey('hesaplananTutar') 
                          ? '${product['hesaplananTutar'].toStringAsFixed(2)} TL' 
                          : ''),
                      ),
                    ],
                  ),
              ],
            ),
            
            pw.SizedBox(height: 20),
            
            // Tutar Özeti
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Toplam Tutar', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text('${calculation.totalAmount.toStringAsFixed(2)} TL', style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                  pw.SizedBox(height: 5),
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('NET TUTAR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                      pw.Text('${calculation.netAmount.toStringAsFixed(2)} TL', 
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    ],
                  ),
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
                    pw.Text('OSM Yapi - Tum haklari saklidir', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            );
          },
        ),
      );
      
      // PDF'i kaydet
      final String fileName = 'OSM_YAPI_Hesaplama_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      
      Directory? directory;
      File file;
      
      if (Platform.isAndroid) {
        // Android sürümüne göre kaydetme yöntemini değiştir
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        int sdkVersion = androidInfo.version.sdkInt;
        
        if (sdkVersion >= 30) { // Android 11+
          // Android 11'de harici depolamaya doğrudan erişim yok,
          // uygulama özel dizinine kaydedip sonra paylaşıyoruz
          directory = await getApplicationDocumentsDirectory();
          file = File('${directory.path}/$fileName');
          await file.writeAsBytes(await pdf.save());
          
          // Başarı mesajı göster
          Get.snackbar(
            'Başarılı',
            'PDF oluşturuldu, açılıyor...',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.shade100,
            colorText: Colors.green.shade800,
            duration: const Duration(seconds: 3),
          );
          
          // PDF dosyasını aç
          await OpenFile.open(file.path);
        } 
        else { // Android 10 ve öncesi
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
          
          // PDF dosyasını aç
          await OpenFile.open(file.path);
        }
      } 
      else if (Platform.isIOS) {
        // iOS için uygulama dökümanları klasörüne kaydet
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
        
        // PDF dosyasını aç
        await OpenFile.open(file.path);
      } 
      else {
        // Diğer platformlar için indirme klasörüne kaydet
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
        
        // PDF dosyasını aç
        await OpenFile.open(file.path);
      }
      
      return file;
    } catch (e) {
      print('PDF oluşturma hatası: $e');
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
      // Android sürümünü kontrol et
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      int sdkVersion = androidInfo.version.sdkInt;
      
      // Android 11 (API 30) ve üstünde genel depolama izni gerekmez
      if (sdkVersion >= 30) {
        return true;
      }
      
      // Android 10 ve öncesi için izin kontrolü
      final status = await Permission.storage.status;
      
      if (status.isGranted) {
        return true;
      }
      
      // İzin henüz verilmemiş, kullanıcıya açıklayıcı bir diyalog göster
      bool showRationale = await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Depolama İzni Gerekli'),
            content: Text(
              'PDF dosyalarını telefona indirebilmek için depolama izni gerekiyor. '
              'Bu izin, hesaplama sonuçlarınızı PDF olarak kaydetmek ve daha sonra erişebilmek için kullanılacaktır.'
            ),
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
      ) ?? false;
      
      if (showRationale) {
        // Kullanıcı izin vermek istedi, izin isteyelim
        final permissionResult = await Permission.storage.request();
        return permissionResult.isGranted;
      }
      
      return false;
    }
    
    // iOS veya diğer platformlar için her zaman true döndür
    return true;
  }
}