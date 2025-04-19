import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';

class CalculateScreen extends StatefulWidget {
  final String buttonType;
  
  const CalculateScreen({super.key, required this.buttonType});

  @override
  State<CalculateScreen> createState() => _CalculateScreenState();
}

class _CalculateScreenState extends State<CalculateScreen> {
  List<Map<String, dynamic>> excelData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExcelData();
  }

  Future<void> _loadExcelData() async {
    try {
      
      final String excelFileName = widget.buttonType == '58 nolu'
          ? 'assets/excel/58nolu.xlsx'
          : 'assets/excel/59nolu.xlsx';

      // Excel dosyasını oku
      final ByteData data = await rootBundle.load(excelFileName);
      var bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      var excel = Excel.decodeBytes(bytes);

      List<Map<String, dynamic>> tempData = [];

      // Excel içindeki verileri oku
      for (var table in excel.tables.keys) {
        for (var row in excel.tables[table]!.rows) {
          if (row.isNotEmpty && row[0] != null) {
            Map<String, dynamic> rowData = {};
            
            // İlk satır başlık olarak kabul edilebilir
            // Bu örnekte basit bir şekilde sütunları index ile alıyoruz
            if (row.length > 0 && row[0]?.value != null) rowData['Sütun1'] = row[0]?.value.toString();
            if (row.length > 1 && row[1]?.value != null) rowData['Sütun2'] = row[1]?.value.toString();
            if (row.length > 2 && row[2]?.value != null) rowData['Sütun3'] = row[2]?.value.toString();
            // Diğer sütunlar gerekirse buraya ekleyebilirsiniz
            
            if (rowData.isNotEmpty) {
              tempData.add(rowData);
            }
          }
        }
      }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.buttonType} Hesaplamaları'),
        backgroundColor: widget.buttonType == '58 nolu' ? Colors.blue.shade800 : Colors.red.shade700,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.buttonType} verileri',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: excelData.isEmpty
                        ? const Center(
                            child: Text('Excel dosyasında veri bulunamadı.'),
                          )
                        : ListView.builder(
                            itemCount: excelData.length,
                            itemBuilder: (context, index) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(excelData[index]['Sütun1'] ?? 'Veri yok'),
                                  subtitle: Text(
                                      'Sütun2: ${excelData[index]['Sütun2'] ?? 'Veri yok'} - Sütun3: ${excelData[index]['Sütun3'] ?? 'Veri yok'}'),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
