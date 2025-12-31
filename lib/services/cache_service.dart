import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Ürün verilerini cache'lemek ve internet durumunu yönetmek için servis sınıfı
class CacheService {
  static const String _winerDataKey = 'winer_cached_data';
  static const String _winerTimestampKey = 'winer_cache_timestamp';
  static const String _alfapenDataKey = 'alfapen_cached_data';
  static const String _alfapenTimestampKey = 'alfapen_cache_timestamp';

  /// İnternet bağlantısını kontrol et
  static Future<bool> hasInternetConnection() async {
    try {
      // Google'a basit bir istek atarak internet kontrolü yap
      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Winer verilerini cache'e kaydet
  static Future<void> cacheWinerData(List<Map<String, dynamic>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = jsonEncode(data);
      await prefs.setString(_winerDataKey, jsonData);
      await prefs.setInt(_winerTimestampKey, DateTime.now().millisecondsSinceEpoch);
      print('Winer verileri cache\'e kaydedildi: ${data.length} ürün');
    } catch (e) {
      print('Winer verileri cache\'e kaydedilemedi: $e');
    }
  }

  /// Winer verilerini cache'den oku
  static Future<List<Map<String, dynamic>>?> getCachedWinerData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
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

  /// Winer cache'inin son güncelleme zamanını al
  static Future<DateTime?> getWinerCacheTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
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
      final prefs = await SharedPreferences.getInstance();
      final jsonData = jsonEncode(data);
      await prefs.setString(_alfapenDataKey, jsonData);
      await prefs.setInt(_alfapenTimestampKey, DateTime.now().millisecondsSinceEpoch);
      print('Alfa Pen verileri cache\'e kaydedildi: ${data.length} ürün');
    } catch (e) {
      print('Alfa Pen verileri cache\'e kaydedilemedi: $e');
    }
  }

  /// Alfa Pen verilerini cache'den oku
  static Future<List<Map<String, dynamic>>?> getCachedAlfaPenData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
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
      final prefs = await SharedPreferences.getInstance();
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
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_winerDataKey);
  }

  /// Cache'de Alfa Pen verisi var mı kontrol et
  static Future<bool> hasAlfaPenCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_alfapenDataKey);
  }

  /// Tüm cache'i temizle
  static Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_winerDataKey);
    await prefs.remove(_winerTimestampKey);
    await prefs.remove(_alfapenDataKey);
    await prefs.remove(_alfapenTimestampKey);
    print('Tüm cache temizlendi');
  }

  /// Sadece Winer cache'ini temizle
  static Future<void> clearWinerCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_winerDataKey);
    await prefs.remove(_winerTimestampKey);
    print('Winer cache temizlendi');
  }

  /// Sadece Alfa Pen cache'ini temizle
  static Future<void> clearAlfaPenCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_alfapenDataKey);
    await prefs.remove(_alfapenTimestampKey);
    print('Alfa Pen cache temizlendi');
  }
}
