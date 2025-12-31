import 'package:get/get.dart';
import 'calculate_controller_base.dart';

class CalculateControllerWiner extends CalculateControllerBase {
  // GRUP sütunu adı
  final String grupColumn = 'GRUP';

  // Dinamik olarak grupları tutan liste
  RxList<String> availableGroups = <String>[].obs;

  // Excel verisi yüklendiğinde grupları otomatik çıkar
  @override
  void setExcelData(List<Map<String, dynamic>> data) {
    super.setExcelData(data);
    _extractGroupsFromData();
  }

  // Veriden benzersiz grupları çıkar
  void _extractGroupsFromData() {
    Set<String> groups = {"Tüm Ürünler"};

    for (var product in excelData) {
      if (product.containsKey(grupColumn)) {
        String groupValue = product[grupColumn]?.toString().trim() ?? '';
        if (groupValue.isNotEmpty) {
          groups.add(groupValue);
        }
      }
    }

    availableGroups.assignAll(groups.toList());
    print('Bulunan gruplar: $availableGroups');
  }

  // Mevcut grupları döndür (UI'da kullanılmak için)
  List<String> getAvailableGroups() {
    if (availableGroups.isEmpty) {
      return ["Tüm Ürünler"];
    }
    return availableGroups.toList();
  }

  @override
  void filterByGroup(String groupName) {
    selectedGroup.value = groupName;

    if (groupName == "Tüm Ürünler") {
      filteredExcelData.assignAll(excelData);
      return;
    }

    // GRUP sütununa göre filtrele
    List<Map<String, dynamic>> filtered = excelData.where((product) {
      String productGroup = product[grupColumn]?.toString().trim() ?? '';
      return productGroup == groupName;
    }).toList();

    filteredExcelData.assignAll(filtered);
    print('$groupName grubunda ${filtered.length} ürün bulundu');
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

        if (profilBoyuColumn.isNotEmpty &&
            product.containsKey(profilBoyuColumn)) {
          var value = product[profilBoyuColumn];
          excelProfilBoyuValue = value is double
              ? value
              : double.tryParse(value.toString()) ?? 0.0;
        }

        if (paketColumn.isNotEmpty && product.containsKey(paketColumn)) {
          var value = product[paketColumn];
          excelPaketValue = value is double
              ? value
              : double.tryParse(value.toString()) ?? 0.0;
        }

        double toplamDeger = (profilBoyuValue * excelProfilBoyuValue) +
            (paketValue * excelPaketValue);

        if (fiyatColumn.isNotEmpty && product.containsKey(fiyatColumn)) {
          var fiyatValue = product[fiyatColumn];
          double metreFiyati = fiyatValue is double
              ? fiyatValue
              : double.tryParse(fiyatValue.toString()) ?? 0.0;
          double urunTutari = metreFiyati * toplamDeger;
          total += urunTutari;

          Map<String, dynamic> updatedProduct =
              Map<String, dynamic>.from(product);
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
