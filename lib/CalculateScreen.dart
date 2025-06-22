import 'package:flutter/material.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/services.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:get/get.dart';
import 'calculate_controller_base.dart';
import 'calculate_controller_winer.dart';
import 'calculate_controller_alfapen.dart';

class CalculateScreen extends StatefulWidget {
  final String buttonType;
  
  const CalculateScreen({super.key, required this.buttonType});

  @override
  State<CalculateScreen> createState() => _CalculateScreenState();
}

class _CalculateScreenState extends State<CalculateScreen> {
  late final dynamic controller;
  Map<String, dynamic>? selectedProduct;
  bool _isPanelExpanded = false;

  @override
  void initState() {
    super.initState();
    
    // Widget buttonType'a göre doğru controller'ı oluştur
    if (widget.buttonType.contains('Alfa Pen')) {
      controller = Get.put(CalculateControllerAlfapen(), tag: widget.buttonType);
    } else if (widget.buttonType.contains('Winer')) {
      controller = Get.put(CalculateControllerWiner(), tag: widget.buttonType);
    } else {
      // Varsayılan olarak base controller'ı kullan
      controller = Get.put(CalculateControllerBase(), tag: widget.buttonType);
    }
    
    controller.setExcelType(widget.buttonType);
    _loadExcelData();
    
    // Eğer düzenleme modu ise, hesaplamayı yükle
    if (CalculateControllerBase.calculationToEdit != null && 
        CalculateControllerBase.calculationToEditIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Excel verisi yüklendikten sonra ürünleri yükle
        if (!controller.isLoading.value) {
          controller.loadProductsForEditing();
        } else {
          // Excel verisi yüklenene kadar bekle
          controller.isLoading.listen((isLoading) {
            if (!isLoading && CalculateControllerBase.calculationToEdit != null) {
              controller.loadProductsForEditing();
            }
          });
        }
      });
    }
  }

  Future<void> _loadExcelData() async {
    try {
      // Hangi Excel dosyasını yükleyeceğimizi belirleyelim
      String excelFileName = '';
      String excelType = '';
      
      if (widget.buttonType.contains('Alfa Pen')) {
        excelFileName = 'assets/excel/alfapen.xlsx';
        excelType = 'Alfa Pen - 4';
      } else if (widget.buttonType.contains('Winer')) {
        excelFileName = 'assets/excel/60nolu.xlsx';
        excelType = 'Winer - 60';
      }
      
      print('Excel dosyası yükleniyor: $excelFileName, Tip: $excelType');
      
      final ByteData data = await rootBundle.load(excelFileName);
      var bytes = await data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      
      // Excel dosyasını çözmeye çalış
      var excel;
      try {
        excel = await Excel.decodeBytes(bytes);
      } catch (e) {
        print('Excel yüklenirken format hatası oluştu: $e');
        // Format hatası oluşursa, throw ile üst seviyedeki catch bloğuna gönder
        throw Exception('Excel formatı okuma hatası: $e');
      }

      List<Map<String, dynamic>> tempData = [];

      for (var table in excel.tables.keys) {
        print('Excel tablosu: $table');
        var rows = excel.tables[table]!.rows;
        if (rows.isEmpty) {
          continue;
        }
        
        // Header row'u al
        var headerRow = rows[0];
        List<String> headers = [];
        for (var cell in headerRow) {
          headers.add(cell?.value?.toString() ?? '');
        }
        
        print('Bulunan başlıklar: $headers');
        
        // Tüm satırları işle (header sonrası)
        for (var i = 1; i < rows.length; i++) {
          var row = rows[i];
          if (row.isNotEmpty && row[0] != null) {
            Map<String, dynamic> rowData = {};
            
            for (var j = 0; j < headers.length; j++) {
              if (j < row.length && row[j] != null) {
                String header = headers[j];
                
                // Hücre değerini güvenli bir şekilde oku
                dynamic cellValue;
                try {
                  cellValue = row[j]?.value;
                } catch (e) {
                  print('Hücre değeri okunurken hata: $e, Hücre: Satır $i Sütun $j');
                  cellValue = null;
                }
                
                // Sayısal değerler için özel işlem
                if (header.toUpperCase().contains('PROFİL BOYU') || 
                    header.toUpperCase().contains('FİYAT') || 
                    header.toUpperCase().contains('PAKET')) {
                  double numValue = 0.0;
                  
                  if (cellValue != null) {
                    if (cellValue is num) {
                      numValue = cellValue.toDouble();
                    } else if (cellValue is String) {
                      // Virgül yerine nokta kullanarak sayıya çevir
                      String numStr = cellValue.replaceAll(',', '.');
                      // Boş olmayan tüm sayısal olmayan karakterleri kaldır
                      numStr = numStr.replaceAll(RegExp(r'[^\d.]'), '');
                      
                      if (numStr.isNotEmpty) {
                        // Sayıya çevirmeyi dene
                        try {
                          numValue = double.parse(numStr);
                        } catch (e) {
                          print('Sayı çevirme hatası: $e, Değer: $numStr');
                          numValue = 0.0;
                        }
                      }
                    } else {
                      // Diğer tipleri string'e çevirip sonra double'a dönüştürmeyi dene
                      try {
                        String strVal = cellValue.toString();
                        strVal = strVal.replaceAll(',', '.').replaceAll(RegExp(r'[^\d.]'), '');
                        
                        if (strVal.isNotEmpty) {
                          numValue = double.parse(strVal);
                        }
                      } catch (e) {
                        print('Sayı çevirme hatası 2: $e, Değer: $cellValue');
                      }
                    }
                  }
                  
                  rowData[header] = numValue;
                } else {
                  // Sayısal olmayan değerler için string'e çevir
                  rowData[header] = cellValue?.toString() ?? '';
                }
              }
            }
            
            if (rowData.containsKey(headers[0]) && 
                rowData[headers[0]].toString().isNotEmpty) {
              tempData.add(rowData);
            }
          }
        }
      }
      
      
      print('Excel\'den yüklenen veri sayısı: ${tempData.length}');
      
      
      controller.setExcelData(tempData);
      
      
      controller.setExcelType(excelType);
      controller.filterByGroup("Tüm Ürünler");
      
    } catch (e) {
      print('Excel yükleme hatası: $e');
      
      Get.snackbar(
        'Excel Yükleme Hatası',
        'Excel dosyası yüklenirken bir hata oluştu: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
        duration: const Duration(seconds: 5),
        icon: const Icon(Icons.error_outline, color: Colors.red),
      );
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Ürün Silme Onayı',
            style: TextStyle(
              color: widget.buttonType == 'Alfa Pen' ? Colors.blue.shade800 : Colors.red.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('$productName ürünü silinecek.'),
                const SizedBox(height: 8),
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Sil'),
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

  Future<void> _showCustomerNamePopup(BuildContext context) async {
    // Düzenleme modu için müşteri adını varsayılan olarak ayarla
    TextEditingController customerNameController = TextEditingController();
    
    // Eğer düzenleme modunda isek, mevcut müşteri adını kullan
    if (CalculateControllerBase.calculationToEdit != null) {
      customerNameController.text = CalculateControllerBase.calculationToEdit!.customerName;
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            CalculateControllerBase.calculationToEdit != null ? 'Hesaplama Düzenle' : 'Müşteri/Kurum Bilgisi',
            style: TextStyle(
              color: widget.buttonType == 'Alfa Pen' ? Colors.blue.shade800 : Colors.red.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: customerNameController,
                  decoration: InputDecoration(
                    labelText: 'Müşteri/Kurum Adı',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(CalculateControllerBase.calculationToEdit != null ? 'Güncelle' : 'Kaydet'),
              onPressed: () async {
                Navigator.of(context).pop();
                
                if (CalculateControllerBase.calculationToEdit != null) {
                  // Düzenleme modunda - hesaplamayı güncelle
                  final List<Map<String, dynamic>> productCopies = [];
                  
                  // Iskonto ve KDV oranlarını al
                  final iskontoValue = double.tryParse(controller.iskontoController.text) ?? 0.0;
                  final kdvValue = double.tryParse(controller.kdvController.text) ?? 0.0;

                  for (var product in controller.selectedProducts) {
                    Map<String, dynamic> copy = Map<String, dynamic>.from(product);
                    
                    // Fiyat bilgilerini ekle
                    if (!copy.containsKey('FİYAT (Metre)') && copy.containsKey(controller.fiyatColumn)) {
                      copy['FİYAT (Metre)'] = copy[controller.fiyatColumn];
                    }
                    
                    if (!copy.containsKey('FİYAT (Metre)') && copy.containsKey('fiyatDegeri')) {
                      copy['FİYAT (Metre)'] = copy['fiyatDegeri'];
                    }
                    
                    // İskonto ve KDV değerlerini ürüne ekle
                    copy['iskontoOrani'] = iskontoValue;
                    copy['kdvOrani'] = kdvValue;
                    
                    productCopies.add(copy);
                  }
                  
                  final updatedCalculation = CalculationHistory(
                    date: DateTime.now(), // Güncelleme tarihi
                    excelType: controller.excelType,
                    productCount: productCopies.length,
                    totalAmount: controller.toplamTutar.value,
                    netAmount: controller.netTutar.value,
                    products: productCopies,
                    customerName: customerNameController.text,
                  );
                  
                  // Hesaplamayı güncelle
                  await CalculateControllerBase.updateCalculation(updatedCalculation);
                  
                  // Ana ekrana geri dön
                  Navigator.of(context).pop();
                } else {
                  // Yeni hesaplama modunda - hesaplamayı kaydet
                  await controller.saveCalculation(customerNameController.text);
                  
                  Get.snackbar(
                    'Başarılı',
                    'Hesaplama başarıyla kaydedildi',
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: Colors.green.shade100,
                    colorText: Colors.green.shade800,
                    borderRadius: 10,
                    margin: const EdgeInsets.all(15),
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
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = widget.buttonType == 'Alfa Pen' 
        ? Color(0xFF3C3C3C) // Koyu gri/siyah (logo)
        : Color(0xFFF47B20); // Turuncu (logo)
    
    final Color secondaryColor = widget.buttonType == 'Alfa Pen' 
        ? Colors.grey.shade200 
        : Color(0xFFFBD2A2); // Açık turuncu (logodaki turuncunun açık tonu)
        
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.buttonType} Hesaplamaları',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: Obx(() => controller.isLoading.value
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: primaryColor),
                const SizedBox(height: 16),
                Text(
                  'Ürünler Yükleniyor...',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        : SafeArea(
            child: SingleChildScrollView(
              child: Container(
                width: MediaQuery.of(context).size.width, 
                height: MediaQuery.of(context).size. height * 0.85,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Grup seçim alanı - Bu kısım her zaman gösterilsin
                          const SizedBox(height: 4),
                          const SizedBox(height: 4),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  spreadRadius: 0,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Obx(() => DropdownButtonHideUnderline(
                              child: ButtonTheme(
                                alignedDropdown: true,
                                child: DropdownButton<String>(
                                  value: controller.selectedGroup.value,
                                  isExpanded: true,
                                  icon: const Icon(Icons.category),
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  items: widget.buttonType.contains('Alfa Pen')
                                    ? controller.groupDefinitionsAlfa.keys.map<DropdownMenuItem<String>>((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      }).toList()
                                    : controller.groupDefinitions60.keys.map<DropdownMenuItem<String>>((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      controller.filterByGroup(newValue);
                                    }
                                  },
                                ),
                              ),
                            )),
                          ),
                          
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  spreadRadius: 0,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: DropdownSearch<Map<String, dynamic>>(
                              popupProps: PopupProps.menu(
                                showSearchBox: true,
                                searchFieldProps: TextFieldProps(
                                  decoration: InputDecoration(
                                    labelText: 'Ürün Ara',
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: primaryColor, width: 2),
                                    ),
                                  ),
                                ),
                                constraints: BoxConstraints(
                                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                                ),
                              ),
                              items: controller.filteredExcelData,
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
                              dropdownDecoratorProps: DropDownDecoratorProps(
                                dropdownSearchDecoration: InputDecoration(
                                  hintText: 'Ürün Seçiniz',
                                  hintStyle: TextStyle(color: Colors.grey.shade600),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                        ],
                      ),
                    ),
                    
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Seçilen Ürünler',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                                Obx(() => controller.selectedProducts.isNotEmpty
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${controller.selectedProducts.length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink()
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 8),
                            
                            Expanded(
                              child: Obx(() => controller.selectedProducts.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.shopping_cart_outlined,
                                          size: 48,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Henüz ürün seçilmedi.',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
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
                                      
                                      String hesaplananTutarText = '';
                                      
                                      if (product.containsKey('hesaplananTutar')) {
                                        hesaplananTutarText = '${product['hesaplananTutar'].toStringAsFixed(2)} TL';
                                      }
                                      
                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          side: BorderSide(
                                            color: product.containsKey('hesaplananTutar') 
                                                ? primaryColor.withOpacity(0.3)
                                                : Colors.transparent,
                                            width: 1,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                flex: 2,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      displayTitle,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    if (hesaplananTutarText.isNotEmpty)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 6),
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: secondaryColor,
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            hesaplananTutarText, 
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              color: primaryColor,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // İlk alan: Profil Boyu
                                              Expanded(
                                                flex: 1,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Profil Boyu',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    SizedBox(
                                                      height: 40,
                                                      child: TextField(
                                                        controller: controller.profilBoyuControllers[index],
                                                        decoration: InputDecoration(
                                                          border: OutlineInputBorder(
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          focusedBorder: OutlineInputBorder(
                                                            borderRadius: BorderRadius.circular(8),
                                                            borderSide: BorderSide(color: primaryColor, width: 2),
                                                          ),
                                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                        ),
                                                        style: const TextStyle(fontSize: 14),
                                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                        inputFormatters: [
                                                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                                        ],
                                                        onChanged: (value) {
                                                          // Boş değer kontrolünü kaldırdık
                                                          // Değişikliği direk uygulayacak
                                                          controller.calculateTotalPrice();
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // İkinci alan: Paket
                                              Expanded(
                                                flex: 1,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Paket',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    SizedBox(
                                                      height: 40,
                                                      child: TextField(
                                                        controller: controller.paketControllers[index],
                                                        decoration: InputDecoration(
                                                          border: OutlineInputBorder(
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          focusedBorder: OutlineInputBorder(
                                                            borderRadius: BorderRadius.circular(8),
                                                            borderSide: BorderSide(color: primaryColor, width: 2),
                                                          ),
                                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                        ),
                                                        style: const TextStyle(fontSize: 14),
                                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                        inputFormatters: [
                                                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                                        ],
                                                        onChanged: (value) {
                                                          // Boş değer kontrolünü kaldırdık
                                                          // Değişikliği direk uygulayacak
                                                          controller.calculateTotalPrice();
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Material(
                                                color: Colors.red.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(8),
                                                  onTap: () => _showDeleteConfirmationDialog(index),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(10),
                                                    child: Icon(
                                                      Icons.delete_outline,
                                                      color: Colors.red.shade700,
                                                      size: 22,
                                                    ),
                                                  ),
                                                ),
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
                            
                            Obx(() => Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: secondaryColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: primaryColor.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  setState(() {
                                    _isPanelExpanded = !_isPanelExpanded;
                                  });
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          _isPanelExpanded 
                                              ? Icons.keyboard_arrow_up
                                              : Icons.keyboard_arrow_down,
                                          color: primaryColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Toplam: ${controller.toplamTutar.value.toStringAsFixed(2)} TL',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            )),
                            
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: _isPanelExpanded ? null : 0,
                              curve: Curves.easeInOut,
                              child: _isPanelExpanded ? Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.2),
                                      spreadRadius: 1,
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: MediaQuery.of(context).size.width * 0.35,
                                          child: TextField(
                                            controller: controller.iskontoController,
                                            decoration: InputDecoration(
                                              labelText: 'İskonto (%)',
                                              labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(10),
                                                borderSide: BorderSide(color: primaryColor, width: 2),
                                              ),
                                              prefixIcon: const Icon(Icons.percent, size: 15),
                                              contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                                            ),
                                            style: TextStyle(fontSize: 16),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                            ],
                                            onChanged: (_) => controller.calculateTotalPrice(),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: MediaQuery.of(context).size.width * 0.35,
                                          child: TextField(
                                            controller: controller.kdvController,
                                            decoration: InputDecoration(
                                              labelText: 'KDV (%)',
                                              labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(10),
                                                borderSide: BorderSide(color: primaryColor, width: 2),
                                              ),
                                              prefixIcon: const Icon(Icons.attach_money, size: 20),
                                              contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 14),
                                            ),
                                            style: TextStyle(fontSize: 16),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                            ],
                                            onChanged: (_) => controller.calculateTotalPrice(),
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    const SizedBox(height: 16),
                                    
                                    Obx(() => Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'İskonto Tutarı:',
                                                style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                                              ),
                                              Text(
                                                '${controller.iskontoTutar.value.toStringAsFixed(2)} TL',
                                                style: TextStyle(
                                                  fontSize: 14, 
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.red.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Divider(height: 16),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Ara Tutar:',
                                                style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                                              ),
                                              Text(
                                                '${(controller.toplamTutar.value - controller.iskontoTutar.value).toStringAsFixed(2)} TL',
                                                style: const TextStyle(
                                                  fontSize: 14, 
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Divider(height: 16),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'KDV Tutarı:',
                                                style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                                              ),
                                              Text(
                                                '${controller.kdvTutar.value.toStringAsFixed(2)} TL',
                                                style: TextStyle(
                                                  fontSize: 14, 
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.green.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    )),
                                    
                                    const SizedBox(height: 16),
                                    
                                    Obx(() => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: secondaryColor,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: primaryColor.withOpacity(0.2),
                                            spreadRadius: 1,
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'NET TUTAR',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold, 
                                              fontSize: 14,
                                              color: primaryColor,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: primaryColor,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${controller.netTutar.value.toStringAsFixed(2)} TL',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold, 
                                                fontSize: 14,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                    
                                    const SizedBox(height: 16),
                                    
                                    if (controller.selectedProducts.length >= 1)
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            _showCustomerNamePopup(context);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green.shade600,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          icon: const Icon(Icons.save),
                                          label: const Text(
                                            'Hesaplamayı Kaydet',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ) : const SizedBox(),
                            ),
                            
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
      ),
    );
  }
}