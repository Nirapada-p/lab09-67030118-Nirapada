import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

// แสดงรูปสินค้าได้ทั้งแบบ URL (สินค้าจาก API) และ Base64 (สินค้าที่นักศึกษาโพสต์เอง)
class ItemImage extends StatefulWidget {
  // Base64 หรือ URL ของรูปภาพ
  final String? source;
  final double size;

  const ItemImage({super.key, required this.source, this.size = 56});

  // เลือกรูปที่จะใช้: ถ้ามี Base64 (img) ให้ใช้ก่อน ไม่เช่นนั้นใช้ imageUrl
  static String? pick({String? img, String? imageUrl}) {
    if (img != null && img.isNotEmpty) return img;
    if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;
    return null;
  }

  @override
  State<ItemImage> createState() => _ItemImageState();
}

class _ItemImageState extends State<ItemImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant ItemImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.source != widget.source) {
      _decode();
    }
  }

  bool _isUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  // แปลง Base64 เป็น bytes ครั้งเดียว ไม่แปลงซ้ำทุกครั้งที่ build
  void _decode() {
    _bytes = null;

    final source = widget.source;

    if (source == null || source.isEmpty || _isUrl(source)) return;

    try {
      var base64String = source;

      if (base64String.startsWith('data:') && base64String.contains(',')) {
        base64String = base64String.split(',').last;
      }

      _bytes = base64Decode(base64String);
    } catch (e) {
      debugPrint('ไม่สามารถอ่านรูป Base64 ได้: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final source = widget.source;

    Widget child;

    if (_bytes != null) {
      child = Image.memory(
        _bytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image),
      );
    } else if (source != null && _isUrl(source)) {
      child = Image.network(
        source,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image),
      );
    } else {
      child = const Icon(Icons.image_not_supported);
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: child),
    );
  }
}
