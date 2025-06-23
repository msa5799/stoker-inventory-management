import "firebase_service.dart";
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'auth_service.dart';
import 'inventory_service.dart';
import '../models/product.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _lastLowStockCheckKey = 'last_low_stock_check';
  static const String _lastAnalyticsCheckKey = 'last_analytics_check';

  // Bildirim kanalları
  static const String lowStockChannelId = 'low_stock_channel';
  static const String analyticsChannelId = 'analytics_channel';
  static const String generalChannelId = 'general_channel';

  // Navigation callback
  static Function(String)? onNotificationTapped;

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Bildirim kanallarını oluştur
    await _createNotificationChannels();
  }

  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel lowStockChannel =
        AndroidNotificationChannel(
      lowStockChannelId,
      'Düşük Stok Uyarıları',
      description: 'Stok seviyesi düşük olan ürünler için bildirimler',
      importance: Importance.high,
    );

    const AndroidNotificationChannel analyticsChannel =
        AndroidNotificationChannel(
      analyticsChannelId,
      'Analitik Raporlar',
      description: 'Günlük ve haftalık analitik raporlar',
      importance: Importance.defaultImportance,
    );

    const AndroidNotificationChannel generalChannel =
        AndroidNotificationChannel(
      generalChannelId,
      'Genel Bildirimler',
      description: 'Genel uygulama bildirimleri',
      importance: Importance.defaultImportance,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(lowStockChannel);

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(analyticsChannel);

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(generalChannel);
  }

  void _onNotificationTapped(NotificationResponse notificationResponse) {
    // Bildirime tıklandığında yapılacak işlemler
    debugPrint('Notification tapped: ${notificationResponse.payload}');
    
    // Analytics sayfasını aç
    if (onNotificationTapped != null) {
      onNotificationTapped!('/analytics');
    }
  }

  // Bildirim izni iste
  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      return status.isGranted;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final result = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    }
    return true;
  }

  // Bildirim izni durumunu kontrol et
  Future<bool> hasPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await Permission.notification.isGranted;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final result = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return result?.isEnabled ?? false;
    }
    return true;
  }

  // Bildirimlerin etkin olup olmadığını kontrol et
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? false;
  }

  // Bildirimleri etkinleştir/devre dışı bırak
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);
    
    if (enabled) {
      // Varsayılan bildirim zamanını ayarla (18:00)
      final hour = prefs.getInt('notification_hour') ?? 18;
      final minute = prefs.getInt('notification_minute') ?? 0;
      await scheduleDailyAnalyticsNotification(TimeOfDay(hour: hour, minute: minute));
    } else {
      await cancelDailyAnalyticsNotification();
    }
  }

  // Günlük analitik bildirimini zamanla
  Future<void> scheduleDailyAnalyticsNotification(TimeOfDay time) async {
    if (!await areNotificationsEnabled()) return;

    // Önce mevcut bildirimi iptal et
    await cancelDailyAnalyticsNotification();

    // Bugünün tarihinde belirtilen saati hesapla
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    
    // Eğer zaman geçmişse, yarın için zamanla
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Gerçek analiz verilerini hazırla
    await _scheduleAnalyticsNotificationWithData(scheduledDate);
  }

  // Analiz verileriyle bildirim zamanla
  Future<void> _scheduleAnalyticsNotificationWithData(DateTime scheduledDate) async {
    try {
      final inventoryService = InventoryService();
      
      // Bugünün satışlarını al (zamanlanmış gün için)
      final targetDate = scheduledDate;
      final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      // Gerçek veriler
      final productsData = await FirebaseService.getProducts(); final products = productsData.map((data) => Product.fromMap(data)).toList();
      final allSales = await inventoryService.getSales();
      
      // Hedef günün satışlarını filtrele
      final daySales = allSales.where((sale) {
        return sale.transactionDate.isAfter(startOfDay) && sale.transactionDate.isBefore(endOfDay);
      }).toList();
      
      // Hesaplamalar
      double dayRevenue = 0;
      int daySalesCount = daySales.length;
      
      for (var sale in daySales) {
        dayRevenue += sale.totalAmount;
      }
      
      // Düşük stok ürünleri
      final lowStockProducts = products
          .where((product) => product.currentStock <= product.minStockLevel)
          .toList();
      
      // Bildirim metnini oluştur - Düşük stok öncelikli
      String notificationTitle;
      String notificationBody;
      
      if (lowStockProducts.isNotEmpty) {
        notificationTitle = '⚠️ Düşük Stok Uyarısı';
        if (lowStockProducts.length == 1) {
          final product = lowStockProducts.first;
          notificationBody = '${product.name}: ${product.currentStock} ${product.unit} kaldı (min: ${product.minStockLevel})';
        } else if (lowStockProducts.length <= 3) {
          final productInfo = lowStockProducts.map((p) => '${p.name} (${p.currentStock}/${p.minStockLevel})').join(', ');
          notificationBody = 'Düşük stok: $productInfo';
        } else {
          final firstThree = lowStockProducts.take(3).map((p) => p.name).join(', ');
          notificationBody = 'Düşük stok: $firstThree ve ${lowStockProducts.length - 3} ürün daha';
        }
        
        // Satış bilgisini ekle
        if (daySalesCount > 0) {
          notificationBody += ' • Bugün: ${daySalesCount} satış, ₺${dayRevenue.toStringAsFixed(0)}';
        } else {
          notificationBody += ' • Bugün henüz satış yapılmadı';
        }
      } else {
        notificationTitle = '📊 Günlük Rapor';
        if (daySalesCount > 0) {
          notificationBody = 'Bugün: ${daySalesCount} satış, ₺${dayRevenue.toStringAsFixed(0)} gelir • Stok durumu normal ✅';
        } else {
          notificationBody = 'Bugün henüz satış yapılmadı • ${products.length} ürün, stok durumu normal ✅';
        }
      }

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        analyticsChannelId,
        'Günlük Raporlar',
        channelDescription: 'Günlük analitik raporlar',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/launcher_icon',
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails();

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      // Günlük tekrarlayan bildirim zamanla - Gerçek verilerle
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        100, // Unique ID for daily analytics
        notificationTitle,
        notificationBody,
        _convertToTZDateTime(scheduledDate),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Günlük tekrar
        payload: 'daily_analytics',
      );
    } catch (e) {
      debugPrint('Schedule analytics notification error: $e');
      
      // Hata durumunda basit bildirim zamanla
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        analyticsChannelId,
        'Günlük Raporlar',
        channelDescription: 'Günlük analitik raporlar',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/launcher_icon',
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails();

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        100,
        '📊 Günlük Rapor',
        'Günlük rapor hazır, detayları görmek için tıklayın',
        _convertToTZDateTime(scheduledDate),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'daily_analytics',
      );
    }
  }

  // Günlük analitik bildirimini iptal et
  Future<void> cancelDailyAnalyticsNotification() async {
    await _flutterLocalNotificationsPlugin.cancel(100);
  }

  // DateTime'ı TZDateTime'a çevir
  tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, tz.local);
  }

  // Düşük stok bildirimi gönder
  Future<void> sendLowStockNotification(List<String> lowStockProducts) async {
    if (!await areNotificationsEnabled()) return;
    if (lowStockProducts.isEmpty) return;

    final title = 'Düşük Stok Uyarısı';
    final body = lowStockProducts.length == 1
        ? '${lowStockProducts.first} ürününde stok azaldı'
        : '${lowStockProducts.length} üründe stok azaldı';

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      lowStockChannelId,
      'Düşük Stok Uyarıları',
      channelDescription: 'Stok seviyesi düşük olan ürünler için bildirimler',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      1,
      title,
      body,
      platformChannelSpecifics,
      payload: 'low_stock',
    );
  }

  // Analitik rapor bildirimi gönder
  Future<void> sendAnalyticsNotification({
    required int totalProducts,
    required double todaySales,
    required int todaySalesCount,
    String? customTitle,
    String? customBody,
  }) async {
    if (!await areNotificationsEnabled()) return;

    final title = customTitle ?? 'Günlük Rapor';
    final body = customBody ?? 'Bugün ${todaySalesCount} satış, ₺${todaySales.toStringAsFixed(0)} gelir';

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      analyticsChannelId,
      'Analitik Raporlar',
      channelDescription: 'Günlük ve haftalık analitik raporlar',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/launcher_icon',
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      2,
      title,
      body,
      platformChannelSpecifics,
      payload: 'analytics',
    );
  }

  // Genel bildirim gönder
  Future<void> sendGeneralNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!await areNotificationsEnabled()) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      generalChannelId,
      'Genel Bildirimler',
      channelDescription: 'Genel uygulama bildirimleri',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/launcher_icon',
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      3,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  // Düşük stok kontrolü yap ve bildirim gönder
  Future<Map<String, dynamic>> checkAndNotifyLowStock() async {
    try {
      final productsData = await FirebaseService.getProducts();
      final products = productsData.map((data) => Product.fromMap(data)).toList();
      
      final lowStockProducts = products
          .where((product) => product.currentStock <= product.minStockLevel)
          .toList();

      if (lowStockProducts.isNotEmpty && await areNotificationsEnabled()) {
        String title = '⚠️ Düşük Stok Uyarısı';
        String body;
        
        if (lowStockProducts.length == 1) {
          final product = lowStockProducts.first;
          body = '${product.name} ürününde stok azaldı (${product.currentStock} ${product.unit} kaldı, min: ${product.minStockLevel})';
        } else if (lowStockProducts.length <= 3) {
          final productInfo = lowStockProducts.map((p) => '${p.name} (${p.currentStock}/${p.minStockLevel})').join(', ');
          body = 'Düşük stok: $productInfo';
        } else {
          final firstThree = lowStockProducts.take(3).map((p) => p.name).join(', ');
          body = 'Düşük stok: $firstThree ve ${lowStockProducts.length - 3} ürün daha';
        }

        await sendGeneralNotification(
          title: title,
          body: body,
          payload: 'low_stock_check',
        );
      }

      return {
        'success': true,
        'lowStockCount': lowStockProducts.length,
        'lowStockProducts': lowStockProducts.map((p) => {
          'name': p.name,
          'currentStock': p.currentStock,
          'minStockLevel': p.minStockLevel,
          'unit': p.unit,
        }).toList(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<void> _checkLowStockAndNotify() async {
    try {
      final productsData = await FirebaseService.getProducts(); final products = productsData.map((data) => Product.fromMap(data)).toList();
      final lowStockProducts = products
          .where((product) => product.currentStock <= product.minStockLevel)
          .toList();

      if (lowStockProducts.isNotEmpty) {
        String notificationTitle;
        String notificationBody;

        if (lowStockProducts.length == 1) {
          final product = lowStockProducts.first;
          notificationTitle = 'Stok Azaldı!';
          notificationBody = '${product.name}: ${product.currentStock} ${product.unit} kaldı (min: ${product.minStockLevel})';
        } else if (lowStockProducts.length <= 3) {
          notificationTitle = '${lowStockProducts.length} Ürün Stok Azaldı!';
          final productInfo = lowStockProducts.map((p) => '${p.name} (${p.currentStock}/${p.minStockLevel})').join(', ');
          notificationBody = productInfo;
        } else {
          notificationTitle = '${lowStockProducts.length} Ürün Stok Azaldı!';
          final firstThree = lowStockProducts.take(3).map((p) => p.name).join(', ');
          notificationBody = '$firstThree ve ${lowStockProducts.length - 3} ürün daha...';
        }

        await _showNotification(
          id: 1,
          title: notificationTitle,
          body: notificationBody,
          payload: 'low_stock',
        );
      }
    } catch (e) {
      print('Low stock check error: $e');
    }
  }

  Future<void> _checkAndSendDailyReport() async {
    try {
      final productsData = await FirebaseService.getProducts(); final products = productsData.map((data) => Product.fromMap(data)).toList();
      final lowStockProducts = products
          .where((product) => product.currentStock <= product.minStockLevel)
          .toList();

      if (lowStockProducts.isNotEmpty) {
        String notificationTitle = 'Günlük Stok Raporu';
        String notificationBody;

        if (lowStockProducts.length == 1) {
          final product = lowStockProducts.first;
          notificationTitle = 'Günlük Stok Raporu - 1 Ürün';
          notificationBody = '${product.name}: ${product.currentStock} ${product.unit} kaldı (min: ${product.minStockLevel})';
        } else if (lowStockProducts.length <= 3) {
          notificationTitle = 'Günlük Stok Raporu - ${lowStockProducts.length} Ürün';
          final productInfo = lowStockProducts.map((p) => '${p.name} (${p.currentStock}/${p.minStockLevel})').join(', ');
          notificationBody = productInfo;
        } else {
          notificationTitle = 'Günlük Stok Raporu - ${lowStockProducts.length} Ürün';
          final firstThree = lowStockProducts.take(3).map((p) => p.name).join(', ');
          notificationBody = '$firstThree ve ${lowStockProducts.length - 3} ürün daha stok azaldı';
        }

        await _showNotification(
          id: 2,
          title: notificationTitle,
          body: notificationBody,
          payload: 'daily_report',
        );
      }
    } catch (e) {
      print('Daily report error: $e');
    }
  }

  Future<void> _checkAndSendWeeklyReport() async {
    try {
      final productsData = await FirebaseService.getProducts(); final products = productsData.map((data) => Product.fromMap(data)).toList();
      final lowStockProducts = products
          .where((product) => product.currentStock <= product.minStockLevel)
          .toList();

      if (lowStockProducts.isNotEmpty) {
        String title = 'Haftalık Stok Raporu';
        String body;

        if (lowStockProducts.length == 1) {
          final product = lowStockProducts.first;
          body = '${product.name} ürününde stok azaldı (${product.currentStock} ${product.unit} kaldı, min: ${product.minStockLevel})';
        } else if (lowStockProducts.length <= 3) {
          final productInfo = lowStockProducts.map((p) => '${p.name} (${p.currentStock}/${p.minStockLevel})').join(', ');
          body = 'Stok azalan ürünler: $productInfo';
        } else {
          final firstThree = lowStockProducts.take(3).map((p) => p.name).join(', ');
          body = 'Stok azalan ürünler: $firstThree ve ${lowStockProducts.length - 3} ürün daha';
        }

        // Prepare data for email
        final lowStockData = lowStockProducts.map((p) => {
          'name': p.name,
          'currentStock': p.currentStock,
          'minStockLevel': p.minStockLevel,
          'unit': p.unit,
        }).toList();

        await _showNotification(
          id: 3,
          title: title,
          body: body,
          payload: 'weekly_report',
        );

        // Send email report if configured
        // await _sendWeeklyEmailReport(lowStockData);
      }
    } catch (e) {
      print('Weekly report error: $e');
    }
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      generalChannelId,
      'Genel Bildirimler',
      channelDescription: 'Genel uygulama bildirimleri',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/launcher_icon',
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  // Düşük stok kontrolü yap
  Future<void> checkLowStock() async {
    try {
      final productsData = await FirebaseService.getProducts();
      final products = productsData.map((data) => Product.fromMap(data)).toList();
      
      final lowStockProducts = products
          .where((product) => product.currentStock <= product.minStockLevel)
          .map((product) => product.name)
          .toList();

      if (lowStockProducts.isNotEmpty) {
        await sendLowStockNotification(lowStockProducts);
      }

      // Son kontrol zamanını kaydet
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastLowStockCheckKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Low stock check error: $e');
    }
  }

  // Analitik rapor oluştur
  Future<void> generateAnalyticsReport() async {
    try {
      final inventoryService = InventoryService();
      
      // Bugünün satışlarını al
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      // Gerçek veriler
      final productsData = await FirebaseService.getProducts();
      final products = productsData.map((data) => Product.fromMap(data)).toList();
      final allSales = await inventoryService.getSales();
      
      // Bugünün satışlarını filtrele
      final todaySales = allSales.where((sale) {
        return sale.transactionDate.isAfter(startOfDay) && sale.transactionDate.isBefore(endOfDay);
      }).toList();
      
      // Hesaplamalar
      double todayRevenue = 0;
      int todaySalesCount = todaySales.length;
      double todayProfit = 0;
      
      for (var sale in todaySales) {
        todayRevenue += sale.totalAmount;
        if (sale.profitLoss != null) {
          todayProfit += sale.profitLoss!;
        }
      }
      
      // Düşük stok ürünleri
      final lowStockProducts = products
          .where((product) => product.currentStock <= product.minStockLevel)
          .toList();
      
      // Bildirim metnini oluştur - Düşük stok öncelikli
      String notificationTitle;
      String notificationBody;
      
      if (lowStockProducts.isNotEmpty) {
        notificationTitle = '⚠️ Düşük Stok Uyarısı';
        if (lowStockProducts.length == 1) {
          final product = lowStockProducts.first;
          notificationBody = '${product.name}: ${product.currentStock} ${product.unit} kaldı (min: ${product.minStockLevel})';
        } else if (lowStockProducts.length <= 3) {
          final productInfo = lowStockProducts.map((p) => '${p.name} (${p.currentStock}/${p.minStockLevel})').join(', ');
          notificationBody = 'Düşük stok: $productInfo';
        } else {
          final firstThree = lowStockProducts.take(3).map((p) => p.name).join(', ');
          notificationBody = 'Düşük stok: $firstThree ve ${lowStockProducts.length - 3} ürün daha';
        }
        
        // Satış bilgisini ekle
        if (todaySalesCount > 0) {
          notificationBody += ' • Bugün: ${todaySalesCount} satış, ₺${todayRevenue.toStringAsFixed(0)}';
        } else {
          notificationBody += ' • Bugün henüz satış yapılmadı';
        }
      } else {
        notificationTitle = '📊 Günlük Rapor';
        if (todaySalesCount > 0) {
          notificationBody = 'Bugün: ${todaySalesCount} satış, ₺${todayRevenue.toStringAsFixed(0)} gelir';
          if (todayProfit > 0) {
            notificationBody += ', ₺${todayProfit.toStringAsFixed(0)} kar';
          }
          notificationBody += ' • Stok durumu normal ✅';
        } else {
          notificationBody = 'Bugün henüz satış yapılmadı • ${products.length} ürün, stok durumu normal ✅';
        }
      }
      
      await sendAnalyticsNotification(
        totalProducts: products.length,
        todaySales: todayRevenue,
        todaySalesCount: todaySalesCount,
        customTitle: notificationTitle,
        customBody: notificationBody,
      );

      // Son kontrol zamanını kaydet
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastAnalyticsCheckKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Analytics report error: $e');
    }
  }

  // Test bildirimi gönder
  Future<void> sendTestNotification() async {
    if (!await areNotificationsEnabled()) {
      throw Exception('Bildirimler etkin değil');
    }

    // Gerçek analiz verilerini hesapla ve test bildirimi gönder
    await generateAnalyticsReport();
  }
} 