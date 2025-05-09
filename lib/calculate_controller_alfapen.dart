import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'calculate_controller_base.dart';

class CalculateControllerAlfapen extends CalculateControllerBase {
  final Map<String, Map<String, dynamic>> groupDefinitionsAlfa = {
    "Tüm Ürünler": {"startRow": 0, "endRow": -1},
    "ECO70 PROFIT Serisi": {"startRow": 0, "endRow": 19},
    "7000 Sürme Serisi": {"startRow": 20, "endRow": 46},
    "Yardımcı Profiller 60 lık Seri": {"startRow": 47, "endRow": 58},
    "Yardımcı Profiller 70 lik Seri": {"startRow": 59, "endRow": 66},
    "Yardımcı Profiller Ortak Kullanım": {"startRow": 67, "endRow": 89},
  };

  @override
  void filterByGroup(String groupName) {
    selectedGroup.value = groupName;
    
    if (groupName == "Tüm Ürünler") {
      filteredExcelData.assignAll(excelData);
      return;
    }
    
    if (!groupDefinitionsAlfa.containsKey(groupName)) {
      filteredExcelData.assignAll(excelData);
      return;
    }
    
    var groupInfo = groupDefinitionsAlfa[groupName]!;
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

  // Toplam tutarı hesaplama fonksiyonu - Alfa Pen için hesaplama mantığı
  @override
  void calculateTotalPrice() {
    double total = 0.0;
    
    for (int i = 0; i < selectedProducts.length; i++) {
      final product = selectedProducts[i];
      final profilBoyuController = profilBoyuControllers[i];
      final paketController = paketControllers[i];
      
      if (profilBoyuController != null && paketController != null) {
        final profilBoyuValue = profilBoyuController.text.isEmpty 
            ? 0.0 
            : double.tryParse(profilBoyuController.text) ?? 0.0;
        
        final paketValue = paketController.text.isEmpty 
            ? 0.0 
            : double.tryParse(paketController.text) ?? 0.0;
        
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
        
        double toplamDeger = (profilBoyuValue * excelProfilBoyuValue) + (paketValue * excelPaketValue);
        
        if (fiyatColumn.isNotEmpty && product.containsKey(fiyatColumn)) {
          var fiyatValue = product[fiyatColumn];
          double metreFiyati = fiyatValue is double ? fiyatValue : double.tryParse(fiyatValue.toString()) ?? 0.0;
          
          double urunTutari = metreFiyati * toplamDeger;
          total += urunTutari;
          
          Map<String, dynamic> updatedProduct = Map<String, dynamic>.from(product);
          updatedProduct['hesaplananTutar'] = urunTutari;
          updatedProduct['toplamDeger'] = toplamDeger;
          updatedProduct['profilBoyuDegeri'] = profilBoyuValue;
          updatedProduct['paketDegeri'] = paketValue;
          
          updatedProduct['fiyatDegeri'] = metreFiyati;
          if (!updatedProduct.containsKey('Fiyat (Metre)')) {
            updatedProduct['Fiyat (Metre)'] = metreFiyati;
          }
          
          selectedProducts[i] = updatedProduct; 
        }
      }
    }
    
    toplamTutar.value = total;
    calculateNetTutar();
  }
}