import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';

/// Ürün verilerini cache'lemek ve internet durumunu yönetmek için servis sınıfı
class CacheService {
  static const String _winerDataKey = 'winer_cached_data';
  static const String _winerTimestampKey = 'winer_cache_timestamp';
  static const String _winerNameKey = 'winer_display_name';
  static const String _alfapenDataKey = 'alfapen_cached_data';
  static const String _alfapenTimestampKey = 'alfapen_cache_timestamp';

  // SharedPreferences instance'ını cache'le - her seferinde yeniden almayı önle
  static SharedPreferences? _prefs;
  
  static Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// İnternet bağlantısını kontrol et - timeout ile optimize edildi
  static Future<bool> hasInternetConnection() async {
    try {
      // Daha hızlı kontrol için HEAD request kullan
      final response = await http
          .head(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Winer verilerini cache'e kaydet
  static Future<void> cacheWinerData(List<Map<String, dynamic>> data) async {
    try {
      final prefs = await _preferences;
      final jsonData = jsonEncode(data);
      await Future.wait([
        prefs.setString(_winerDataKey, jsonData),
        prefs.setInt(_winerTimestampKey, DateTime.now().millisecondsSinceEpoch),
      ]);
      print('Winer verileri cache\'e kaydedildi: ${data.length} ürün');
    } catch (e) {
      print('Winer verileri cache\'e kaydedilemedi: $e');
    }
  }

  /// Winer verilerini cache'den oku
  static Future<List<Map<String, dynamic>>?> getCachedWinerData() async {
    try {
      final prefs = await _preferences;
      final jsonData = prefs.getString(_winerDataKey);
      
      if (jsonData != null && jsonData.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonData);
        final data = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
        print('Winer verileri cache\'den yüklendi: ${data.length} ürün');
        return data;
      }
    } catch (e) {
      print('Winer verileri cache\'den okunamadı: $e');
    }
    return null;
  }

  /// Winer gösterim adını cache'e kaydet (ör: "Winer - 63")
  static Future<void> cacheWinerName(String name) async {
    try {
      final prefs = await _preferences;
      await prefs.setString(_winerNameKey, name);
      print('Winer gösterim adı cache\'e kaydedildi: $name');
    } catch (e) {
      print('Winer adı cache\'e kaydedilemedi: $e');
    }
  }

  /// Winer gösterim adını cache'den oku
  static Future<String> getWinerName() async {
    try {
      final prefs = await _preferences;
      return prefs.getString(_winerNameKey) ?? 'Winer - 62';
    } catch (e) {
      print('Winer adı cache\'den okunamadı: $e');
      return 'Winer - 62';
    }
  }

  /// Winer cache'inin son güncelleme zamanını al
  static Future<DateTime?> getWinerCacheTimestamp() async {
    try {
      final prefs = await _preferences;
      final timestamp = prefs.getInt(_winerTimestampKey);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      print('Winer cache timestamp okunamadı: $e');
    }
    return null;
  }

  /// Alfa Pen verilerini cache'e kaydet
  static Future<void> cacheAlfaPenData(List<Map<String, dynamic>> data) async {
    try {
      final prefs = await _preferences;
      final jsonData = jsonEncode(data);
      await Future.wait([
        prefs.setString(_alfapenDataKey, jsonData),
        prefs.setInt(_alfapenTimestampKey, DateTime.now().millisecondsSinceEpoch),
      ]);
      print('Alfa Pen verileri cache\'e kaydedildi: ${data.length} ürün');
    } catch (e) {
      print('Alfa Pen verileri cache\'e kaydedilemedi: $e');
    }
  }

  /// Alfa Pen verilerini cache'den oku
  static Future<List<Map<String, dynamic>>?> getCachedAlfaPenData() async {
    try {
      final prefs = await _preferences;
      final jsonData = prefs.getString(_alfapenDataKey);
      
      if (jsonData != null && jsonData.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonData);
        final data = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
        print('Alfa Pen verileri cache\'den yüklendi: ${data.length} ürün');
        return data;
      }
    } catch (e) {
      print('Alfa Pen verileri cache\'den okunamadı: $e');
    }
    return null;
  }

  /// Alfa Pen cache'inin son güncelleme zamanını al
  static Future<DateTime?> getAlfaPenCacheTimestamp() async {
    try {
      final prefs = await _preferences;
      final timestamp = prefs.getInt(_alfapenTimestampKey);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      print('Alfa Pen cache timestamp okunamadı: $e');
    }
    return null;
  }

  /// Cache'de Winer verisi var mı kontrol et
  static Future<bool> hasWinerCache() async {
    final prefs = await _preferences;
    return prefs.containsKey(_winerDataKey);
  }

  /// Cache'de Alfa Pen verisi var mı kontrol et
  static Future<bool> hasAlfaPenCache() async {
    final prefs = await _preferences;
    return prefs.containsKey(_alfapenDataKey);
  }

  /// Tüm cache'i temizle
  static Future<void> clearAllCache() async {
    final prefs = await _preferences;
    await Future.wait([
      prefs.remove(_winerDataKey),
      prefs.remove(_winerTimestampKey),
      prefs.remove(_alfapenDataKey),
      prefs.remove(_alfapenTimestampKey),
    ]);
    print('Tüm cache temizlendi');
  }

  /// Sadece Winer cache'ini temizle
  static Future<void> clearWinerCache() async {
    final prefs = await _preferences;
    await Future.wait([
      prefs.remove(_winerDataKey),
      prefs.remove(_winerTimestampKey),
    ]);
    print('Winer cache temizlendi');
  }

  /// Sadece Alfa Pen cache'ini temizle
  static Future<void> clearAlfaPenCache() async {
    final prefs = await _preferences;
    await Future.wait([
      prefs.remove(_alfapenDataKey),
      prefs.remove(_alfapenTimestampKey),
    ]);
    print('Alfa Pen cache temizlendi');
  }

  /// Google Sheets'ten Winer seri adını doğrudan çek (HomeScreen açılışında kullanılır)
  static Future<String?> fetchWinerNameFromSheets() async {
    try {
      if (!await hasInternetConnection()) return null;

      String csvUrl =
          'https://docs.google.com/spreadsheets/d/e/2PACX-1vRuNLxisljropuR9vv2cT_-sKLssJWI_BIXJ0jJmLbX4TXcWLCyYtWjaRGuTDjLursOuJXDCy1t-mFl/pub?output=csv';

      final response = await http
          .get(Uri.parse(csvUrl))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      List<List<dynamic>> csvTable =
          const CsvToListConverter().convert(utf8.decode(response.bodyBytes));
      if (csvTable.isEmpty) return null;

      List<String> headers =
          csvTable[0].map((e) => e.toString().trim()).toList();

      print('Sheets başlıkları (Winer ad çekme): $headers');

      // Yöntem 1: "SERİ" içeren sütun başlığını bul
      for (int i = 0; i < headers.length; i++) {
        if (headers[i].toUpperCase().contains('SERİ') ||
            headers[i].toUpperCase().contains('SERI')) {
          if (csvTable.length > 1 && i < csvTable[1].length) {
            String value = csvTable[1][i].toString().trim();
            if (value.isNotEmpty) {
              await cacheWinerName(value);
              print('Sheets\'ten Winer adı bulundu (SERİ kolonu): $value');
              return value;
            }
          }
          break;
        }
      }

      // Yöntem 2: H sütunu (index 7) kontrol et
      if (headers.length > 7) {
        // Başlığın kendisi Winer içeriyorsa (kullanıcı başlığa yazmış olabilir)
        if (headers[7].toLowerCase().contains('winer')) {
          await cacheWinerName(headers[7]);
          print('Sheets\'ten Winer adı bulundu (H başlık): ${headers[7]}');
          return headers[7];
        }
        // İlk veri satırındaki H değeri
        if (csvTable.length > 1 && csvTable[1].length > 7) {
          String hValue = csvTable[1][7].toString().trim();
          if (hValue.isNotEmpty && hValue.toLowerCase().contains('winer')) {
            await cacheWinerName(hValue);
            print('Sheets\'ten Winer adı bulundu (H değer): $hValue');
            return hValue;
          }
        }
      }

      // Yöntem 3: Herhangi bir sütundaki başlık veya değer Winer-XX formatında mı?
      for (int i = 0; i < headers.length; i++) {
        String h = headers[i].trim();
        if (RegExp(r'[Ww]iner\s*-\s*\d+').hasMatch(h)) {
          await cacheWinerName(h);
          print('Sheets\'ten Winer adı bulundu (başlık regex): $h');
          return h;
        }
      }

      print('Sheets\'te Winer seri adı bulunamadı');
      return null;
    } catch (e) {
      print('Winer adı Sheets\'ten alınamadı: $e');
      return null;
    }
  }
}
