import 'package:flutter/material.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:get/get.dart';
import 'calculate_controller.dart';

class CalculateScreen extends StatefulWidget {
  final String buttonType;
  
  const CalculateScreen({super.key, required this.buttonType});

  @override
  State<CalculateScreen> createState() => _CalculateScreenState();
}

class _CalculateScreenState extends State<CalculateScreen> {
  // GetX controller
  late final CalculateController controller;
  Map<String, dynamic>? selectedProduct;

  @override
  void initState() {
    super.initState();
    // Controller'ı başlat
    controller = Get.put(CalculateController(), tag: widget.buttonType);
    _loadExcelData();
  }

  Future<void> _loadExcelData() async {
    try {
      final String excelFileName = widget.buttonType == '58 nolu'
          ? 'assets/excel/58nolu.xlsx'
          : 'assets/excel/59nolu.xlsx';

      print('Excel dosyası yükleniyor: $excelFileName');
      
      // Excel dosyasını oku
      final ByteData data = await rootBundle.load(excelFileName);
      var bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      var excel = Excel.decodeBytes(bytes);

      List<Map<String, dynamic>> tempData = [];

      // Excel içindeki verileri oku
      for (var table in excel.tables.keys) {
        print('Excel tablosu okunuyor: $table');
        
        // Önce tablo yapısını inceleyip sütun adlarını belirle
        var rows = excel.tables[table]!.rows;
        if (rows.isEmpty) {
          print('Tablo boş: $table');
          continue;
        }
        
        // İlk satır (başlık satırı)
        var headerRow = rows[0];
        List<String> headers = [];
        for (var cell in headerRow) {
          headers.add(cell?.value?.toString() ?? '');
        }
        
        print("Excel sütun başlıkları: $headers");
        
        // 1. sütundan sonraki satırları oku (başlığı atlayarak)
        for (var i = 1; i < rows.length; i++) {
          var row = rows[i];
          if (row.isNotEmpty && row[0] != null) {
            Map<String, dynamic> rowData = {};
            
            // Başlık adlarına göre verileri ekle
            for (var j = 0; j < headers.length; j++) {
              if (j < row.length && row[j]?.value != null) {
                String header = headers[j];
                
                // Sayısal değer kontrolü
                dynamic cellValue = row[j]?.value;
                if (header.toUpperCase().contains('PROFİL BOYU') || 
                    header.toUpperCase().contains('FİYAT')) {
                  // Sayısal değerleri double olarak çevir
                  double numValue = 0.0;
                  
                  if (cellValue != null) {
                    if (cellValue is num) {
                      numValue = cellValue.toDouble();
                    } else if (cellValue is String) {
                      // Virgül yerine nokta kullanımını destekle
                      String numStr = cellValue.replaceAll(',', '.');
                      numValue = double.tryParse(numStr) ?? 0.0;
                    }
                  }
                  
                  rowData[header] = numValue;
                } else {
                  rowData[header] = cellValue?.toString() ?? '';
                }
              }
            }
            
            // En azından ilk sütun dolu ise ekle
            if (rowData.containsKey(headers[0]) && 
                rowData[headers[0]].toString().isNotEmpty) {
              print("Ürün: ${rowData[headers[0]]} yükleniyor");
              tempData.add(rowData);
            }
          }
        }
      }

      print('Toplam ${tempData.length} ürün yüklendi');
      
      // Controller'a veriyi aktar
      controller.setExcelData(tempData);
      
    } catch (e) {
      print('Excel veri okuma hatası: $e');
      controller.isLoading.value = false;
    }
  }
  
  Future<void> _showDeleteConfirmationDialog(int index) async {
    final product = controller.selectedProducts[index];
    String codeColumn = controller.codeColumn;
    String nameColumn = controller.nameColumn;
    
    String productName = '';
    if (codeColumn.isNotEmpty && nameColumn.isNotEmpty &&
        product.containsKey(codeColumn) && product.containsKey(nameColumn)) {
      productName = '${product[codeColumn]} - ${product[nameColumn]}';
    } else if (codeColumn.isNotEmpty && product.containsKey(codeColumn)) {
      productName = product[codeColumn].toString();
    } else {
      productName = 'Ürün ${index + 1}';
    }
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Ürün Silme Onayı'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('$productName ürünü silinecek.'),
                const Text('Bu işlemi onaylıyor musunuz?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Sil', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                controller.removeProduct(index);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.buttonType} Hesaplamaları'),
        backgroundColor: widget.buttonType == '58 nolu' ? Colors.blue.shade800 : Colors.red.shade700,
      ),
      body: Obx(() => controller.isLoading.value
        ? const Center(child: CircularProgressIndicator())
        : Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ürün Seçimi ve Ekle Butonu
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownSearch<Map<String, dynamic>>(
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(
                        decoration: const InputDecoration(
                          labelText: 'Ürün Ara',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    items: controller.excelData,
                    itemAsString: (item) {
                      if (item == null) return '';
                      String displayText = '';
                      if (controller.codeColumn.isNotEmpty && controller.nameColumn.isNotEmpty && 
                          item.containsKey(controller.codeColumn) && item.containsKey(controller.nameColumn)) {
                        displayText = '${item[controller.codeColumn]} - ${item[controller.nameColumn]}';
                      } else if (controller.codeColumn.isNotEmpty && item.containsKey(controller.codeColumn)) {
                        displayText = item[controller.codeColumn].toString();
                      } else {
                        displayText = 'Ürün';
                      }
                      return displayText;
                    },
                    dropdownDecoratorProps: const DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        hintText: 'Ürün Seçiniz',
                        border: InputBorder.none,
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null) {
                        selectedProduct = value;
                        controller.addProduct(value);
                      }
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                const Text(
                  'Seçilen Ürünler',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                // Seçilen Ürünler Listesi
                Expanded(
                  flex: 2,
                  child: Obx(() => controller.selectedProducts.isEmpty
                    ? const Center(child: Text('Henüz ürün seçilmedi.'))
                    : ListView.builder(
                        itemCount: controller.selectedProducts.length,
                        itemBuilder: (context, index) {
                          final product = controller.selectedProducts[index];
                          String displayTitle = '';
                          if (controller.codeColumn.isNotEmpty && controller.nameColumn.isNotEmpty && 
                              product.containsKey(controller.codeColumn) && product.containsKey(controller.nameColumn)) {
                            displayTitle = '${product[controller.codeColumn]} - ${product[controller.nameColumn]}';
                          } else if (controller.codeColumn.isNotEmpty && product.containsKey(controller.codeColumn)) {
                            displayTitle = product[controller.codeColumn].toString();
                          } else {
                            displayTitle = 'Ürün ${index + 1}';
                          }
                          
                          String profilBoyuText = '';
                          String fiyatText = '';
                          String hesaplananTutarText = '';
                          
                          if (controller.profilBoyuColumn.isNotEmpty && product.containsKey(controller.profilBoyuColumn)) {
                            profilBoyuText = 'Profil Boyu: ${product[controller.profilBoyuColumn]}';
                          }
                          
                          if (controller.fiyatColumn.isNotEmpty && product.containsKey(controller.fiyatColumn)) {
                            fiyatText = 'Fiyat: ${product[controller.fiyatColumn]} TL';
                          }
                          
                          if (product.containsKey('hesaplananTutar')) {
                            hesaplananTutarText = 'Tutar: ${product['hesaplananTutar'].toStringAsFixed(2)} TL';
                          }
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayTitle,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        if (profilBoyuText.isNotEmpty || fiyatText.isNotEmpty)
                                          Text('$profilBoyuText ${profilBoyuText.isNotEmpty && fiyatText.isNotEmpty ? " - " : ""} $fiyatText'),
                                        if (hesaplananTutarText.isNotEmpty)
                                          Text(
                                            hesaplananTutarText, 
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: TextField(
                                      controller: controller.metreControllers[index],
                                      decoration: const InputDecoration(
                                        labelText: 'Metre',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                      ],
                                      onChanged: (value) {
                                        // Metre değeri değiştiğinde fiyatı güncelle
                                        if (value.isNotEmpty) {
                                          // Boş değilse hesapla
                                          controller.calculateTotalPrice();
                                        } else {
                                          // Boş ise 0 olarak ayarla ve hesapla
                                          controller.metreControllers[index] = '0' as TextEditingController;
                                          controller.calculateTotalPrice();
                                        }
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _showDeleteConfirmationDialog(index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Toplam Tutar
                Obx(() => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Toplam Tutar',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '${controller.toplamTutar.value.toStringAsFixed(2)} TL',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                )),
                
                const SizedBox(height: 16),
                
                // İskonto ve KDV Giriş Alanları
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller.iskontoController,
                        decoration: const InputDecoration(
                          labelText: 'İskonto Giriniz (%)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: controller.kdvController,
                        decoration: const InputDecoration(
                          labelText: 'KDV Giriniz (%)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // İskonto ve KDV Detayları
                Obx(() => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'İskonto: ${controller.iskontoTutar.value.toStringAsFixed(2)} TL',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            'KDV: ${controller.kdvTutar.value.toStringAsFixed(2)} TL',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      Text(
                        'Ara Tutar: ${(controller.toplamTutar.value - controller.iskontoTutar.value).toStringAsFixed(2)} TL',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )),
                
                const SizedBox(height: 16),
                
                // Net Tutar
                Obx(() => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade800),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Net Tutar',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '${controller.netTutar.value.toStringAsFixed(2)} TL',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          )
      ),
    );
  }
}
