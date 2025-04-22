import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Hesaplama geçmişini saklamak için model sınıfı
class CalculationHistory {
  final DateTime date;
  final String excelType; // 58 nolu veya 59 nolu
  final int productCount;
  final double totalAmount;
  final double netAmount;
  final List<Map<String, dynamic>> products;

  CalculationHistory({
    required this.date,
    required this.excelType,
    required this.productCount,
    required this.totalAmount,
    required this.netAmount,
    required this.products,
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
    );
  }
}

class CalculateController extends GetxController {
  // Hesaplama geçmişi
  static RxList<CalculationHistory> calculationHistory = <CalculationHistory>[].obs;
  
  // En fazla saklanacak geçmiş sayısı
  static const int maxHistoryCount = 10;
  
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
  
  
  final iskontoController = TextEditingController(text: '0');
  final kdvController = TextEditingController(text: '20');
  final Map<int, TextEditingController> metreControllers = {};
  
  
  RxBool isLoading = true.obs;
  
  
  String codeColumn = '';
  String nameColumn = '';
  String profilBoyuColumn = '';
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
    metreControllers.forEach((_, controller) => controller.dispose());
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
        
        // Metre controller'ı oluştur
        metreControllers[newProductIndex] = TextEditingController(text: '1');
        metreControllers[newProductIndex]!.addListener(() {
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
      metreControllers[index]?.dispose();
      selectedProducts.removeAt(index);
      
      // Controller'ları yeniden indeksle
      final Map<int, TextEditingController> updatedControllers = {};
      for (int i = 0; i < selectedProducts.length; i++) {
        if (i >= index) {
          updatedControllers[i] = metreControllers[i + 1]!;
        } else {
          updatedControllers[i] = metreControllers[i]!;
        }
      }
      
      metreControllers.clear();
      metreControllers.addAll(updatedControllers);
      
      calculateTotalPrice();
    }
  }

  // Toplam tutarı hesaplama fonksiyonu
  void calculateTotalPrice() {
    double total = 0.0;
    
    for (int i = 0; i < selectedProducts.length; i++) {
      final product = selectedProducts[i];
      final controller = metreControllers[i];
      
      if (controller != null) {
        final metre = double.tryParse(controller.text) ?? 0.0;
        
        // Eğer fiyat sütunu bulunabilmişse hesapla
        if (fiyatColumn.isNotEmpty && product.containsKey(fiyatColumn)) {
          // Metre değerini ürün fiyatı ile çarp ve toplama ekle
          double metreFiyati = double.parse(product[fiyatColumn].toString());
          double urunTutari = metreFiyati * metre;
          total += urunTutari;
          
          // Hesaplanan değeri ürün bilgisine ekle (sonraki gösterimler için)
          product['hesaplananTutar'] = urunTutari;
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
          if (key.toLowerCase().contains('profil') || key.toLowerCase().contains('boy')) {
            profilBoyuColumn = key;
            break;
          }
        }
        // İlk sayısal değeri içeren sütunu kullan
        if (profilBoyuColumn.isEmpty) {
          for (var key in excelData[0].keys) {
            if (excelData[0][key] is double) {
              profilBoyuColumn = key;
              break;
            }
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
  Future<void> saveCalculation() async {
    // Eğer en az 3 ürün eklenmişse kaydet
    if (selectedProducts.length >= 3) {
      final calculation = CalculationHistory(
        date: DateTime.now(),
        excelType: excelType,
        productCount: selectedProducts.length,
        totalAmount: toplamTutar.value,
        netAmount: netTutar.value,
        products: selectedProducts.map((p) => Map<String, dynamic>.from(p)).toList(),
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
}