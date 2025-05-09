import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'calculate_controller_base.dart';

class CalculateControllerWiner extends CalculateControllerBase {
  final Map<String, Map<String, dynamic>> groupDefinitions59 = {
    "Tüm Ürünler": {"startRow": 0, "endRow": -1},
    "60 Serisi Ana Profiller": {"startRow": 0, "endRow": 23},
    "60 3 Odacık Serisi Ana Profiller": {"startRow": 24, "endRow": 36},
    "70 Süper Seri Profiller": {"startRow": 37, "endRow": 62},
    "80 Seri Profiller": {"startRow": 63, "endRow": 86},
    "Sürme Serisi Profiller": {"startRow": 87, "endRow": 122},
    "Yalıtımlı Sürme Serisi": {"startRow": 123, "endRow": 144},
    "Yardımcı Profiller": {"startRow": 145, "endRow": 185},
  };

  @override
  void filterByGroup(String groupName) {
    selectedGroup.value = groupName;
    
    if (groupName == "Tüm Ürünler") {
      filteredExcelData.assignAll(excelData);
      return;
    }
    
    if (!groupDefinitions59.containsKey(groupName)) {
      filteredExcelData.assignAll(excelData);
      return;
    }
    
    var groupInfo = groupDefinitions59[groupName]!;
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
          if (!updatedProduct.containsKey('FİYAT (Metre)')) {
            updatedProduct['FİYAT (Metre)'] = metreFiyati;
          }
          
          selectedProducts[i] = updatedProduct; 
        }
      }
    }
    
    toplamTutar.value = total;
    calculateNetTutar();
  }
}