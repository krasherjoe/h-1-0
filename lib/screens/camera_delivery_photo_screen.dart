import 'package:flutter/material.dart';
import '../services/camera_delivery_photo_service.dart';

/// 納品写真管理画面
class CameraDeliveryPhotoScreen extends StatefulWidget {
  const CameraDeliveryPhotoScreen({super.key});

  @override
  State<CameraDeliveryPhotoScreen> createState() => _CameraDeliveryPhotoScreenState();
}

class _CameraDeliveryPhotoScreenState extends State<CameraDeliveryPhotoScreen> {
  final CameraDeliveryPhotoService _photoService = CameraDeliveryPhotoService();
  List<Map<String, dynamic>> _photos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final photos = await _photoService.getDeliveryPhotos();
      setState(() {
        _photos = photos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('写真読み込みエラー: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('納品写真管理'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
              ? const Center(
                  child: Text(
                    '納品写真がありません\nカメラで撮影してください',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: _photos.length,
                  itemBuilder: (context, index) {
                    final photo = _photos[index];
                    return ListTile(
                      leading: const Icon(Icons.photo),
                      title: Text(photo['file_path'] ?? '不明'),
                      subtitle: Text('撮影日: ${photo['created_at'] ?? '不明'}'),
                      onTap: () {
                        // TODO: 写真プレビュー機能
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            await _photoService.takePhoto();
            _loadPhotos(); // 再読み込み
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('写真撮影エラー: $e')),
              );
            }
          }
        },
        tooltip: '納品写真を撮影',
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
