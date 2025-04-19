import 'package:flutter/material.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:typed_data';

class CalculateScreen extends StatefulWidget {
  final String buttonType;
  
  const CalculateScreen({super.key, required this.buttonType});

  @override
  State<CalculateScreen> createState() => _CalculateScreenState();
}

class _CalculateScreenState extends State<CalculateScreen> {
  List<Map<String, dynamic>> excelData = [];
  List<Map<String, dynamic>> selectedProducts = [];
  Map<int, TextEditingController> metreControllers = {};
  double toplamTutar = 0.0;
  double netTutar = 0.0;
  
  final TextEditingController iskontoController = TextEditingController(text: '0');
  final TextEditingController kdvController = TextEditingController(text: '18');
  
  Map<String, dynamic>? selectedProduct;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExcelData();
    
    // İskonto ve KDV değişikliklerinde hesaplamaları güncelle
    iskontoController.addListener(_calculateNetTutar);
    kdvController.addListener(_calculateNetTutar);
  }
  
  @override
  void dispose() {
    // Controller'ları temizle
    iskontoController.dispose();
    kdvController.dispose();
    metreControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
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
        
        // Mevcut sütun başlıklarınız
        bool hasUrunKodu = headers.any((h) => h.toUpperCase() == 'ÜRÜN KODU');
        bool hasUrunAdi = headers.any((h) => h.toUpperCase() == 'ÜRÜN ADI');
        bool hasProfilBoyu = headers.any((h) => h.toUpperCase().contains('PROFİL BOYU'));
        bool hasFiyat = headers.any((h) => h.toUpperCase().contains('FİYAT'));
        
        print('Sütun kontrolü: Ürün Kodu: $hasUrunKodu, Ürün Adı: $hasUrunAdi, ' + 
              'Profil Boyu: $hasProfilBoyu, Fiyat: $hasFiyat');
        
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
      
      setState(() {
        excelData = tempData;
        isLoading = false;
      });
    } catch (e) {
      print('Excel veri okuma hatası: $e');
      setState(() {
        isLoading = false;
      });
    }
  }
  
  void _addProduct() {
    if (selectedProduct != null) {
      String codeColumn = _getProductCodeColumn();
      
      // Ürünün zaten eklenip eklenmediğini kontrol et
      bool isAlreadyAdded = false;
      if (codeColumn.isNotEmpty) {
        isAlreadyAdded = selectedProducts.any(
          (product) => product[codeColumn] == selectedProduct![codeColumn]
        );
      }
      
      if (!isAlreadyAdded) {
        setState(() {
          final newProductIndex = selectedProducts.length;
          // Ürünü ekle ve metre controller'ı oluştur
          selectedProducts.add(Map<String, dynamic>.from(selectedProduct!));
          metreControllers[newProductIndex] = TextEditingController(text: '1');
          metreControllers[newProductIndex]!.addListener(() {
            _calculateTotalPrice();
          });
          
          _calculateTotalPrice();
        });
      } else {
        // Kullanıcıya zaten eklendiğini bildir
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu ürün zaten eklenmiş!'))
        );
      }
    }
  }
  
  void _removeProduct(int index) {
    setState(() {
      // Ürünü kaldır
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
      metreControllers = updatedControllers;
      
      _calculateTotalPrice();
    });
  }
  
  // Profil boyu ve Fiyat sütun adlarını belirle
  String _getProfilBoyuColumn() {
    if (excelData.isNotEmpty) {
      if (excelData[0].containsKey('PROFİL BOYU (metre)')) return 'PROFİL BOYU (metre)';
      // Profil Boyu için alternatif isimler
      for (var key in excelData[0].keys) {
        if (key.toLowerCase().contains('profil') || key.toLowerCase().contains('boy')) {
          return key;
        }
      }
      // Bulunamazsa ilk sayısal değeri içeren sütunu kullan
      for (var key in excelData[0].keys) {
        if (excelData[0][key] is double) return key;
      }
    }
    return '';
  }
  
  String _getFiyatColumn() {
    if (excelData.isNotEmpty) {
      if (excelData[0].containsKey('FİYAT (Metre)')) return 'FİYAT (Metre)';
      // Fiyat için alternatif isimler
      for (var key in excelData[0].keys) {
        if (key.toLowerCase().contains('fiyat') || key.toLowerCase().contains('ücret') || 
            key.toLowerCase().contains('tutar') || key.toLowerCase().contains('price')) {
          return key;
        }
      }
      // Bulunamazsa son sayısal değeri içeren sütunu kullan
      List<String> numericColumns = [];
      for (var key in excelData[0].keys) {
        if (excelData[0][key] is double) numericColumns.add(key);
      }
      if (numericColumns.isNotEmpty) return numericColumns.last;
    }
    return '';
  }
  
  // Ürün kodunu ve adını belirle
  String _getProductCodeColumn() {
    if (excelData.isNotEmpty) {
      if (excelData[0].containsKey('ÜRÜN KODU')) return 'ÜRÜN KODU';
      // Alternatif isimler
      for (var key in excelData[0].keys) {
        if (key.toLowerCase().contains('kod') || key.toLowerCase().contains('code')) {
          return key;
        }
      }
      // İlk sütunu kullan
      return excelData[0].keys.first;
    }
    return '';
  }
  
  String _getProductNameColumn() {
    if (excelData.isNotEmpty) {
      if (excelData[0].containsKey('ÜRÜN ADI')) return 'ÜRÜN ADI';
      // Alternatif isimler
      for (var key in excelData[0].keys) {
        if (key.toLowerCase().contains('ad') || key.toLowerCase().contains('name') || 
            key.toLowerCase().contains('ürün') || key.toLowerCase().contains('product')) {
          return key;
        }
      }
      // İkinci sütunu kullan (varsa)
      var keys = excelData[0].keys.toList();
      if (keys.length > 1) return keys[1];
    }
    return '';
  }
  
  void _calculateTotalPrice() {
    double total = 0.0;
    
    String profilBoyuColumn = _getProfilBoyuColumn();
    String fiyatColumn = _getFiyatColumn();
    
    for (int i = 0; i < selectedProducts.length; i++) {
      final product = selectedProducts[i];
      final controller = metreControllers[i];
      
      if (controller != null) {
        final metre = double.tryParse(controller.text) ?? 0.0;
        
        // Eğer ProfilBoyu ve Fiyat sütunları bulunabilmişse hesapla
        if (profilBoyuColumn.isNotEmpty && fiyatColumn.isNotEmpty &&
            product.containsKey(profilBoyuColumn) && product.containsKey(fiyatColumn)) {
          total += (product[profilBoyuColumn] * product[fiyatColumn] * metre);
        }
      }
    }
    
    setState(() {
      toplamTutar = total;
    });
    
    _calculateNetTutar();
  }
  
  void _calculateNetTutar() {
    final iskonto = double.tryParse(iskontoController.text) ?? 0.0;
    final kdv = double.tryParse(kdvController.text) ?? 18.0;
    
    final tutar = toplamTutar - (toplamTutar * iskonto / 100);
    final kdvTutar = tutar * kdv / 100;
    
    setState(() {
      netTutar = tutar + kdvTutar;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Dinamik sütun adlarını al
    String codeColumn = _getProductCodeColumn();
    String nameColumn = _getProductNameColumn();
    String profilBoyuColumn = _getProfilBoyuColumn();
    String fiyatColumn = _getFiyatColumn();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.buttonType} Hesaplamaları'),
        backgroundColor: widget.buttonType == '58 nolu' ? Colors.blue.shade800 : Colors.red.shade700,
      ),
      body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ürün Seçimi ve Ekle Butonu
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Map<String, dynamic>>(
                            hint: const Text('Ürün Seçiniz'),
                            value: selectedProduct,
                            isExpanded: true,
                            items: excelData.map((item) {
                              String displayText = '';
                              if (codeColumn.isNotEmpty && nameColumn.isNotEmpty && 
                                  item.containsKey(codeColumn) && item.containsKey(nameColumn)) {
                                displayText = '${item[codeColumn]} - ${item[nameColumn]}';
                              } else if (codeColumn.isNotEmpty && item.containsKey(codeColumn)) {
                                displayText = item[codeColumn].toString();
                              } else {
                                displayText = 'Ürün';
                              }
                              return DropdownMenuItem<Map<String, dynamic>>(
                                value: item,
                                child: Text(displayText),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedProduct = value;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      ),
                      child: const Text('Ekle'),
                    ),
                  ],
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
                  child: selectedProducts.isEmpty
                    ? const Center(child: Text('Henüz ürün seçilmedi.'))
                    : ListView.builder(
                        itemCount: selectedProducts.length,
                        itemBuilder: (context, index) {
                          final product = selectedProducts[index];
                          String displayTitle = '';
                          if (codeColumn.isNotEmpty && nameColumn.isNotEmpty && 
                              product.containsKey(codeColumn) && product.containsKey(nameColumn)) {
                            displayTitle = '${product[codeColumn]} - ${product[nameColumn]}';
                          } else if (codeColumn.isNotEmpty && product.containsKey(codeColumn)) {
                            displayTitle = product[codeColumn].toString();
                          } else {
                            displayTitle = 'Ürün ${index + 1}';
                          }
                          
                          String profilBoyuText = '';
                          String fiyatText = '';
                          if (profilBoyuColumn.isNotEmpty && product.containsKey(profilBoyuColumn)) {
                            profilBoyuText = 'Profil Boyu: ${product[profilBoyuColumn]}';
                          }
                          if (fiyatColumn.isNotEmpty && product.containsKey(fiyatColumn)) {
                            fiyatText = 'Fiyat: ${product[fiyatColumn]} TL';
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
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: TextField(
                                      controller: metreControllers[index],
                                      decoration: const InputDecoration(
                                        labelText: 'Metre',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _removeProduct(index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                ),
                
                const SizedBox(height: 16),
                
                // Toplam Tutar
                Container(
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
                        '${toplamTutar.toStringAsFixed(2)} TL',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // İskonto ve KDV Giriş Alanları
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: iskontoController,
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
                        controller: kdvController,
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
                
                // Net Tutar
                Container(
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
                        '${netTutar.toStringAsFixed(2)} TL',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
