import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../database/app_database.dart';
import '../models/item.dart';
import '../repositories/listing_draft_repository.dart';
import '../repositories/item_repository_firestore.dart';

class MyDraftsPage extends StatefulWidget {
  final ListingDraftRepository repository;

  const MyDraftsPage({super.key, required this.repository});

  @override
  State<MyDraftsPage> createState() => _MyDraftsPageState();
}

class _MyDraftsPageState extends State<MyDraftsPage> {
  late Future<List<ListingDraftRow>> _draftsFuture;

  final Set<int> _postingDraftIds = <int>{};

  final ItemRepositoryFirestore _itemRepository = ItemRepositoryFirestore();

  @override
  void initState() {
    super.initState();
    _refreshDrafts();
  }

  void _refreshDrafts() {
    _draftsFuture = widget.repository.getAllDrafts();
  }

  Future<double?> _showPriceDialog(ListingDraftRow draft) async {
    final controller = TextEditingController();
    String? errorMessage;

    final price = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('กำหนดราคาสินค้า'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('สินค้า: ${draft.title}'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'ราคา (บาท)',
                      hintText: 'เช่น 150 หรือ 99.50',
                      errorText: errorMessage,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('ยกเลิก'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = double.tryParse(controller.text.trim());

                    if (value == null || !value.isFinite || value <= 0) {
                      setDialogState(() {
                        errorMessage = 'กรุณากรอกราคาเป็นตัวเลขที่มากกว่า 0';
                      });
                      return;
                    }

                    Navigator.pop(dialogContext, value);
                  },
                  child: const Text('ยืนยันราคา'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return price;
  }

  Future<String> _compressImageToBase64(String imagePath) async {
    final compressedBytes = await FlutterImageCompress.compressWithFile(
      imagePath,
      minWidth: 480,
      minHeight: 480,
      quality: 35,
      format: CompressFormat.jpeg,
    );

    if (compressedBytes == null || compressedBytes.isEmpty) {
      throw Exception('ไม่สามารถบีบอัดรูปภาพได้ กรุณาเลือกรูปใหม่');
    }

    if (compressedBytes.length > 400 * 1024) {
      throw Exception('รูปภาพยังมีขนาดใหญ่เกินไป กรุณาเลือกรูปที่เล็กลง');
    }

    return base64Encode(compressedBytes);
  }

  Future<void> _postDraft(ListingDraftRow draft) async {
    if (_postingDraftIds.contains(draft.id)) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('กรุณาเข้าสู่ระบบก่อนโพสต์สินค้า');
      return;
    }

    final price = await _showPriceDialog(draft);

    if (!mounted || price == null) return;

    final imageFile = File(draft.imagePath);

    if (!await imageFile.exists()) {
      if (!mounted) return;
      _showMessage('ไม่พบไฟล์รูปภาพของร่างนี้ กรุณาตรวจสอบรูปภาพ');
      return;
    }

    setState(() {
      _postingDraftIds.add(draft.id);
    });

    try {
      final base64Image = await _compressImageToBase64(imageFile.path);

      if (!mounted) return;

      final item = Item(
        id: DateTime.now().millisecondsSinceEpoch,
        title: draft.title,
        price: price,
        description: draft.description,
        category: draft.category,
        imageUrl: '',
        img: 'data:image/jpeg;base64,$base64Image',
        sellerId: user.uid,
      );

      // บันทึกสินค้าลง Firestore
      await _itemRepository.postItem(item);

      if (!mounted) return;

      _showMessage('โพสต์ "${draft.title}" ขายสำเร็จแล้ว');

      // ลบร่างแยกจากการโพสต์
      try {
        await widget.repository.deleteDraft(draft.id);

        if (!mounted) return;

        setState(() {
          _refreshDrafts();
        });
      } catch (e, stackTrace) {
        debugPrint('Delete draft error: $e');
        debugPrintStack(stackTrace: stackTrace);

        if (!mounted) return;

        _showMessage('โพสต์สินค้าสำเร็จแล้ว แต่ลบร่างไม่สำเร็จ');
      }
    } catch (e, stackTrace) {
      debugPrint('Post item error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      _showMessage('บันทึกสินค้าไม่สำเร็จ: $e');
    } finally {
      if (mounted) {
        setState(() {
          _postingDraftIds.remove(draft.id);
        });
      }
    }
  }

  Future<void> _deleteDraft(int id) async {
    if (_postingDraftIds.contains(id)) return;

    try {
      await widget.repository.deleteDraft(id);

      if (!mounted) return;

      setState(() {
        _refreshDrafts();
      });
      _showMessage('ลบร่างประกาศแล้ว');
    } catch (e) {
      if (!mounted) return;

      _showMessage('ไม่สามารถลบร่างประกาศได้: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDateTime(DateTime dateTime) {
    final localDateTime = dateTime.toLocal();

    final day = localDateTime.day.toString().padLeft(2, '0');
    final month = localDateTime.month.toString().padLeft(2, '0');
    final year = localDateTime.year;
    final hour = localDateTime.hour.toString().padLeft(2, '0');
    final minute = localDateTime.minute.toString().padLeft(2, '0');

    return '$day/$month/$year เวลา $hour:$minute น.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ร่างประกาศของฉัน')),
      body: FutureBuilder<List<ListingDraftRow>>(
        future: _draftsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'ไม่สามารถโหลดร่างประกาศได้',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _refreshDrafts();
                        });
                      },
                      child: const Text('ลองใหม่'),
                    ),
                  ],
                ),
              ),
            );
          }

          final drafts = snapshot.data ?? [];

          if (drafts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 72,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'ยังไม่มีร่างประกาศ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'เมื่อบันทึกร่างประกาศแล้ว\n'
                    'ร่างประกาศจะแสดงที่หน้านี้',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: drafts.length,
            itemBuilder: (context, index) {
              final draft = drafts[index];
              final isPosting = _postingDraftIds.contains(draft.id);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: const CircleAvatar(child: Icon(Icons.description)),
                  title: Text(
                    draft.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('หมวดหมู่: ${draft.category}'),
                        const SizedBox(height: 4),
                        Text(
                          'แก้ไขล่าสุด: '
                          '${_formatDateTime(draft.updatedAt)}',
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: isPosting
                                ? null
                                : () => _postDraft(draft),
                            icon: isPosting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.cloud_upload),
                            label: Text(
                              isPosting
                                  ? 'กำลังบีบอัดรูปและโพสต์...'
                                  : 'โพสต์ขายจริง',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'ลบร่างประกาศ',
                    onPressed: isPosting
                        ? null
                        : () => _showDeleteConfirmation(draft),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showDeleteConfirmation(ListingDraftRow draft) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('ลบร่างประกาศ'),
          content: Text('ต้องการลบร่าง "${draft.title}" หรือไม่?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('ลบ', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true && mounted) {
      await _deleteDraft(draft.id);
    }
  }
}
