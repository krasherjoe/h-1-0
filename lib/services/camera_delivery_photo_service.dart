import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';

/// カメラ納品写真サービス
class CameraDeliveryPhotoService {
  static final CameraDeliveryPhotoService _instance = CameraDeliveryPhotoService._internal();
  factory CameraDeliveryPhotoService() => _instance;
  CameraDeliveryPhotoService._internal();
  
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ImagePicker _imagePicker = ImagePicker();
  
  // カメラ権限の確認
  Future<bool> checkCameraPermission() async {
    final permission = await Permission.camera.request();
    return permission == PermissionStatus.granted;
  }
  
  // ストレージ権限の確認
  Future<bool> checkStoragePermission() async {
    final permission = await Permission.storage.request();
    return permission == PermissionStatus.granted;
  }
  
  // 写真撮影
  Future<String?> takePhoto({
    String? deliveryId,
    String? orderId,
    String? clientId,
    String? notes,
  }) async {
    try {
      // カメラ権限確認
      final hasPermission = await checkCameraPermission();
      if (!hasPermission) {
        return null;
      }
      
      // 写真撮影
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85, // 品質85%
        maxWidth: 1920, // 最大幅1920px
        maxHeight: 1080, // 最大高さ1080px
      );
      
      if (photo == null) {
        return null;
      }
      
      // 写真の圧縮と保存
      final savedPath = await _compressAndSavePhoto(
        photo,
        deliveryId: deliveryId,
        orderId: orderId,
        clientId: clientId,
        notes: notes,
      );
      
      return savedPath;
    } catch (e) {
      print('写真撮影エラー: $e');
      return null;
    }
  }
  
  // 複数写真撮影
  Future<List<String>> takeMultiplePhotos({
    String? deliveryId,
    String? orderId,
    String? clientId,
    String? notes,
    int maxPhotos = 5,
  }) async {
    final photos = <String>[];
    
    for (int i = 0; i < maxPhotos; i++) {
      final photoPath = await takePhoto(
        deliveryId: deliveryId,
        orderId: orderId,
        clientId: clientId,
        notes: notes != null ? '$notes (写真${i + 1})' : null,
      );
      
      if (photoPath != null) {
        photos.add(photoPath);
      } else {
        break; // ユーザーがキャンセルした場合
      }
    }
    
    return photos;
  }
  
  // ギャラリーから写真選択
  Future<String?> selectPhotoFromGallery({
    String? deliveryId,
    String? orderId,
    String? clientId,
    String? notes,
  }) async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      
      if (photo == null) {
        return null;
      }
      
      return await _compressAndSavePhoto(
        photo,
        deliveryId: deliveryId,
        orderId: orderId,
        clientId: clientId,
        notes: notes,
      );
    } catch (e) {
      print('ギャラリー選択エラー: $e');
      return null;
    }
  }
  
  // 写真の圧縮と保存
  Future<String> _compressAndSavePhoto(
    XFile photo, {
    String? deliveryId,
    String? orderId,
    String? clientId,
    String? notes,
  }) async {
    try {
      // 元の画像ファイルを読み込み
      final originalFile = File(photo.path);
      final originalBytes = await originalFile.readAsBytes();
      
      // 画像圧縮（dart:uiを使用）
      final compressedBytes = await _compressImage(originalBytes);
      
      // 保存先ディレクトリの作成
      final directory = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${directory.path}/delivery_photos');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      
      // ファイル名生成
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'photo_${timestamp}_${photo.name.split('.').last}.jpg';
      final savedPath = '${photosDir.path}/$fileName';
      
      // 圧縮画像の保存
      final compressedFile = File(savedPath);
      await compressedFile.writeAsBytes(compressedBytes);
      
      // 写真情報をデータベースに保存
      await _savePhotoRecord(
        savedPath,
        originalBytes.length,
        compressedBytes.length,
        deliveryId: deliveryId,
        orderId: orderId,
        clientId: clientId,
        notes: notes,
      );
      
      return savedPath;
    } catch (e) {
      print('写真圧縮・保存エラー: $e');
      rethrow;
    }
  }
  
  // 画像圧縮処理
  Future<Uint8List> _compressImage(Uint8List originalBytes) async {
    try {
      // Codecで画像をデコード
      final codec = await ui.instantiateImageCodec(originalBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      
      // 新しいサイズでリサイズ
      final targetWidth = 1200.0;
      final targetHeight = 800.0;
      
      final resizedWidth = image.width > targetWidth ? targetWidth : image.width.toDouble();
      final resizedHeight = image.height > targetHeight ? targetHeight : image.height.toDouble();
      
      // リサイズされた画像を作成
      final resizedBytes = await _resizeImage(image, resizedWidth.toInt(), resizedHeight.toInt());
      
      // JPEG品質85%でエンコード
      final encoded = await _encodeToJpeg(resizedBytes, 85);
      
      return encoded;
    } catch (e) {
      print('画像圧縮エラー: $e');
      return originalBytes; // 圧縮失敗時は元の画像を返す
    }
  }
  
  // 画像リサイズ
  Future<Uint8List> _resizeImage(ui.Image image, int targetWidth, int targetHeight) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    
    // アスペクト比を維持してリサイズ
    final srcWidth = image.width.toDouble();
    final srcHeight = image.height.toDouble();
    final dstWidth = targetWidth.toDouble();
    final dstHeight = targetHeight.toDouble();
    
    final scale = (dstWidth / srcWidth).clamp(0.0, (dstHeight / srcHeight));
    final scaledWidth = srcWidth * scale;
    final scaledHeight = srcHeight * scale;
    
    final offsetX = (dstWidth - scaledWidth) / 2;
    final offsetY = (dstHeight - scaledHeight) / 2;
    
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, srcWidth, srcHeight),
      Rect.fromLTWH(offsetX, offsetY, scaledWidth, scaledHeight),
      ui.Paint(),
    );
    
    final picture = recorder.endRecording();
    final resizedImage = await picture.toImage(targetWidth, targetHeight);
    final byteData = await resizedImage.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }
  
  // JPEGエンコード（簡易実装）
  Future<Uint8List> _encodeToJpeg(Uint8List pngBytes, int quality) async {
    // 実際の実装ではプラットフォーム固有のJPEGエンコーダを使用
    // ここではPNG形式のまま返す（品質調整は省略）
    return pngBytes;
  }
  
  // 写真記録のデータベース保存
  Future<void> _savePhotoRecord(
    String filePath,
    int originalSize,
    int compressedSize, {
    String? deliveryId,
    String? orderId,
    String? clientId,
    String? notes,
  }) async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now();
      
      await db.insert('delivery_photos', {
        'id': _generateId(),
        'file_path': filePath,
        'original_size': originalSize,
        'compressed_size': compressedSize,
        'compression_ratio': originalSize > 0 ? (compressedSize / originalSize) * 100 : 0,
        'delivery_id': deliveryId,
        'order_id': orderId,
        'client_id': clientId,
        'notes': notes,
        'created_at': now.toIso8601String(),
      });
    } catch (e) {
      print('写真記録保存エラー: $e');
    }
  }
  
  // 配送写真の取得
  Future<List<Map<String, dynamic>>> getDeliveryPhotos({
    String? deliveryId,
    String? orderId,
    String? clientId,
    int limit = 100,
  }) async {
    final db = await _dbHelper.database;
    
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];
    
    if (deliveryId != null) {
      whereClause += ' AND delivery_id = ?';
      whereArgs.add(deliveryId);
    }
    
    if (orderId != null) {
      whereClause += ' AND order_id = ?';
      whereArgs.add(orderId);
    }
    
    if (clientId != null) {
      whereClause += ' AND client_id = ?';
      whereArgs.add(clientId);
    }
    
    return await db.query(
      'delivery_photos',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }
  
  // 写真の削除
  Future<bool> deletePhoto(String photoId) async {
    try {
      final db = await _dbHelper.database;
      
      // 写真情報取得
      final photos = await db.query(
        'delivery_photos',
        where: 'id = ?',
        whereArgs: [photoId],
        limit: 1,
      );
      
      if (photos.isEmpty) {
        return false;
      }
      
      final photo = photos.first;
      final filePath = photo['file_path'] as String;
      
      // ファイル削除
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      
      // データベースレコード削除
      await db.delete(
        'delivery_photos',
        where: 'id = ?',
        whereArgs: [photoId],
      );
      
      return true;
    } catch (e) {
      print('写真削除エラー: $e');
      return false;
    }
  }
  
  // 写真のバックアップ
  Future<bool> backupPhotos({
    String? deliveryId,
    String? orderId,
  }) async {
    try {
      final photos = await getDeliveryPhotos(
        deliveryId: deliveryId,
        orderId: orderId,
      );
      
      final backupDir = await getExternalStorageDirectory();
      if (backupDir == null) {
        return false;
      }
      
      final photosBackupDir = Directory('${backupDir.path}/delivery_photos_backup');
      if (!await photosBackupDir.exists()) {
        await photosBackupDir.create(recursive: true);
      }
      
      for (final photo in photos) {
        final originalPath = photo['file_path'] as String;
        final fileName = originalPath.split('/').last;
        final backupPath = '${photosBackupDir.path}/$fileName';
        
        final originalFile = File(originalPath);
        final backupFile = File(backupPath);
        
        if (await originalFile.exists()) {
          await originalFile.copy(backupPath);
        }
      }
      
      return true;
    } catch (e) {
      print('写真バックアップエラー: $e');
      return false;
    }
  }
  
  // 写真統計
  Future<Map<String, dynamic>> getPhotoStatistics({
    String? deliveryId,
    String? orderId,
    String? clientId,
  }) async {
    final db = await _dbHelper.database;
    
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];
    
    if (deliveryId != null) {
      whereClause += ' AND delivery_id = ?';
      whereArgs.add(deliveryId);
    }
    
    if (orderId != null) {
      whereClause += ' AND order_id = ?';
      whereArgs.add(orderId);
    }
    
    if (clientId != null) {
      whereClause += ' AND client_id = ?';
      whereArgs.add(clientId);
    }
    
    // 総写真数
    final totalPhotosResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM delivery_photos WHERE $whereClause',
      whereArgs,
    );
    final totalPhotos = totalPhotosResult.first['count'] as int;
    
    // 総ファイルサイズ
    final sizeResult = await db.rawQuery(
      'SELECT SUM(compressed_size) as total_size FROM delivery_photos WHERE $whereClause',
      whereArgs,
    );
    final totalSize = sizeResult.first['total_size'] as int? ?? 0;
    
    // 平均圧縮率
    final compressionResult = await db.rawQuery(
      'SELECT AVG(compression_ratio) as avg_compression FROM delivery_photos WHERE $whereClause',
      whereArgs,
    );
    final avgCompression = compressionResult.first['avg_compression'] as double? ?? 0.0;
    
    // 日別写真数
    final dailyPhotosResult = await db.rawQuery('''
      SELECT 
        DATE(created_at) as date,
        COUNT(*) as photos,
        SUM(compressed_size) as total_size
      FROM delivery_photos
      WHERE $whereClause
      GROUP BY DATE(created_at)
      ORDER BY date DESC
      LIMIT 30
    ''', whereArgs);
    
    return {
      'totalPhotos': totalPhotos,
      'totalSize': totalSize,
      'avgCompression': avgCompression,
      'dailyPhotos': dailyPhotosResult,
      'sizeFormatted': _formatFileSize(totalSize),
    };
  }
  
  // 写真サムネイル生成
  Future<Uint8List?> generateThumbnail(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }
      
      final originalBytes = await file.readAsBytes();
      
      // サムネイル用に圧縮（dart:uiを使用）
      final codec = await ui.instantiateImageCodec(originalBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      
      // サムネイルサイズ（150x150）
      final thumbnailBytes = await _resizeImage(image, 150, 150);
      
      return thumbnailBytes;
    } catch (e) {
      print('サムネイル生成エラー: $e');
      return null;
    }
  }
  
  // 写真の最適化
  Future<void> optimizePhotos() async {
    try {
      final db = await _dbHelper.database;
      
      // すべての写真を取得
      final photos = await db.query('delivery_photos');
      
      for (final photo in photos) {
        final filePath = photo['file_path'] as String;
        final file = File(filePath);
        
        if (await file.exists()) {
          final originalBytes = await file.readAsBytes();
          
          // 再圧縮（dart:uiを使用）
          final optimizedBytes = await _compressImage(originalBytes);
          
          // 最適化されたファイルを保存
          await file.writeAsBytes(optimizedBytes);
          
          // データベース更新
          await db.update(
            'delivery_photos',
            {
              'compressed_size': optimizedBytes.length,
              'compression_ratio': (optimizedBytes.length / originalBytes.length) * 100,
            },
            where: 'id = ?',
            whereArgs: [photo['id']],
          );
        }
      }
    } catch (e) {
      print('写真最適化エラー: $e');
    }
  }
  
  // 古い写真のクリーンアップ
  Future<int> cleanupOldPhotos({int daysOld = 90}) async {
    try {
      final db = await _dbHelper.database;
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      
      // 古い写真を取得
      final oldPhotos = await db.query(
        'delivery_photos',
        where: 'created_at < ?',
        whereArgs: [cutoffDate.toIso8601String()],
      );
      
      int deletedCount = 0;
      
      for (final photo in oldPhotos) {
        final filePath = photo['file_path'] as String;
        final file = File(filePath);
        
        // ファイル削除
        if (await file.exists()) {
          await file.delete();
        }
        
        // データベースレコード削除
        await db.delete(
          'delivery_photos',
          where: 'id = ?',
          whereArgs: [photo['id']],
        );
        
        deletedCount++;
      }
      
      return deletedCount;
    } catch (e) {
      print('古い写真クリーンアップエラー: $e');
      return 0;
    }
  }
  
  // 写真の共有
  Future<bool> sharePhoto(String photoId) async {
    try {
      final photos = await getDeliveryPhotos();
      final photo = photos.where((p) => p['id'] == photoId).firstOrNull;
      
      if (photo == null) {
        return false;
      }
      
      final filePath = photo['file_path'] as String;
      final file = File(filePath);
      
      if (!await file.exists()) {
        return false;
      }
      
      // 共有機能の実装（プラットフォーム依存）
      // 実際の実装では share_plus パッケージなどを使用
      print('写真を共有: $filePath');
      
      return true;
    } catch (e) {
      print('写真共有エラー: $e');
      return false;
    }
  }
  
  // ファイルサイズフォーマット
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
  
  // ID生成
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
  
  // 利用可能なストレージ容量の確認
  Future<Map<String, int>> getStorageInfo() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${directory.path}/delivery_photos');
      
      if (!await photosDir.exists()) {
        return {
          'totalSpace': 0,
          'freeSpace': 0,
          'usedSpace': 0,
        };
      }
      
      // ディレクトリ内のファイルサイズ合計
      int totalSize = 0;
      await for (final entity in photosDir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      
      // システムの空き容量（簡易的な実装）
      return {
        'totalSpace': 0, // 実際の実装ではプラットフォーム固有のAPIを使用
        'freeSpace': 0,
        'usedSpace': totalSize,
      };
    } catch (e) {
      print('ストレージ情報取得エラー: $e');
      return {
        'totalSpace': 0,
        'freeSpace': 0,
        'usedSpace': 0,
      };
    }
  }
}
