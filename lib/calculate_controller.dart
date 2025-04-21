import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CalculateController extends GetxController {
  // Excel veri listesi
  RxList<Map<String, dynamic>> excelData = <Map<String, dynamic>>[].obs;
  
  // Seçilen ürünler listesi
  RxList<Map<String, dynamic>> selectedProducts = <Map<String, dynamic>>[].obs;
  
  // Metinlerden tutarlar
  RxDouble toplamTutar = 0.0.obs;
  RxDouble netTutar = 0.0.obs;
  RxDouble iskontoTutar = 0.0.obs;
  RxDouble kdvTutar = 0.0.obs;
  
  // Controller'lar
  final iskontoController = TextEditingController(text: '0');
  final kdvController = TextEditingController(text: '20');
  final Map<int, TextEditingController> metreControllers = {};
  
  // Yükleniyor durumu
  RxBool isLoading = true.obs;
  
  // Dinamik sütun adları
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

  // Ürün ekleme fonksiyonu
  void addProduct(Map<String, dynamic> product) {
    if (product != null) {
      // Ürünün zaten eklenip eklenmediğini kontrol et
      bool isAlreadyAdded = false;
      if (codeColumn.isNotEmpty) {
        isAlreadyAdded = selectedProducts.any(
          (existingProduct) => existingProduct[codeColumn] == product[codeColumn]
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
          double metreFiyati = double.parse(product[fiyatColumn]);
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
    print('Toplam Tutar: $total');
    print('İskonto Tutar: ${iskontoTutar.value}');
    print('KDV Tutar: ${kdvTutar.value}');
    print('Net Tutar: ${netTutar.value}');
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
    setColumnNames();
    isLoading.value = false;
  }
}