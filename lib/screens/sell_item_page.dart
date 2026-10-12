import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/listing_draft.dart';
import '../repositories/listing_draft_repository.dart';
import '../services/gemini_vision_service.dart';
import 'my_drafts_page.dart';

class SellItemPage extends StatefulWidget {
  final ListingDraftRepository draftRepository;

  const SellItemPage({super.key, required this.draftRepository});

  @override
  State<SellItemPage> createState() => _SellItemPageState();
}

class _SellItemPageState extends State<SellItemPage> {
  File? _selectedImage;

  bool _isLoading = false;
  bool _isSaving = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final String _prompt = '''
วิเคราะห์เฉพาะลักษณะสินค้าที่มองเห็นได้จากภาพ
แนะนำชื่อสินค้า หมวดหมู่ และคำอธิบายอย่างเป็นกลาง
ห้ามคาดเดาข้อมูลที่ไม่สามารถยืนยันได้จากภาพ
''';

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    try {
      final XFile? result = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      if (result == null) return;

      // คัดลอกรูปไปยังพื้นที่ถาวรของแอป
      final appDirectory = await getApplicationDocumentsDirectory();
      final imageDirectory = Directory(
        p.join(appDirectory.path, 'product_images'),
      );

      await imageDirectory.create(recursive: true);

      final extension = p.extension(result.path);
      final savedPath = p.join(
        imageDirectory.path,
        'draft_${DateTime.now().microsecondsSinceEpoch}$extension',
      );

      final savedImage = await File(result.path).copy(savedPath);

      if (!mounted) return;

      setState(() {
        _selectedImage = savedImage;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เลือกรูปภาพไม่สำเร็จ: $e')));
    }
  }

  Future<void> _analyzeProductImage() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกรูปภาพสินค้าก่อน')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final draft = await GeminiVisionService().analyzeProductImage(
        _selectedImage!,
        prompt: _prompt,
      );

      if (!mounted) return;

      setState(() {
        _titleController.text = draft.title;
        _categoryController.text = draft.category;
        _descriptionController.text = draft.description;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI วิเคราะห์แล้ว กรุณาตรวจสอบข้อมูลก่อนบันทึก'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      final error = e.toString().toLowerCase();
      String message = 'AI วิเคราะห์ไม่สำเร็จ สามารถกรอกข้อมูลเองได้';

      if (error.contains('safety')) {
        message = 'AI ปฏิเสธการวิเคราะห์ภาพนี้ กรุณากรอกข้อมูลเอง';
      } else if (error.contains('503') || error.contains('high demand')) {
        message = 'AI มีผู้ใช้งานจำนวนมาก กรุณาลองใหม่ภายหลัง';
      } else if (error.contains('gemini_api_key')) {
        message = 'ไม่พบ GEMINI_API_KEY กรุณาตรวจสอบการตั้งค่า';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _confirmListing() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกรูปภาพสินค้าก่อน')),
      );
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อประกาศ')));
      return;
    }

    final finalDraft = ListingDraft(
      title: _titleController.text.trim(),
      category: _categoryController.text.trim(),
      description: _descriptionController.text.trim(),
    );

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.draftRepository.saveDraft(finalDraft, _selectedImage!.path);

      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _selectedImage = null;
        _titleController.clear();
        _categoryController.clear();
        _descriptionController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกร่างประกาศเรียบร้อยแล้ว')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('บันทึกร่างประกาศไม่สำเร็จ: $e')));
    }
  }

  Future<void> _openMyDrafts() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyDraftsPage(repository: widget.draftRepository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isLoading || _isSaving;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ขายสินค้า'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'ร่างประกาศของฉัน',
            onPressed: _openMyDrafts,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _selectedImage!,
                  height: 250,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 250,
                    child: Center(child: Text('ไม่สามารถแสดงรูปภาพได้')),
                  ),
                ),
              )
            else
              Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.image_outlined,
                  size: 80,
                  color: Colors.grey,
                ),
              ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: isBusy ? null : pickImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('เลือกรูปภาพสินค้า'),
            ),

            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: isBusy ? null : _analyzeProductImage,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('ให้ AI ช่วยแนะนำข้อมูล'),
            ),

            if (_isLoading || _isSaving) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _isLoading
                      ? 'AI กำลังวิเคราะห์ภาพ...'
                      : 'กำลังบันทึกร่างประกาศ...',
                ),
              ),
            ],

            const SizedBox(height: 24),

            const Text(
              'ข้อมูลประกาศสินค้า',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _titleController,
              enabled: !isBusy,
              decoration: const InputDecoration(
                labelText: 'ชื่อประกาศ *',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _categoryController,
              enabled: !isBusy,
              decoration: const InputDecoration(
                labelText: 'หมวดหมู่',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _descriptionController,
              enabled: !isBusy,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'คำอธิบายสินค้า',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: isBusy ? null : _confirmListing,
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึกร่างประกาศ'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

            const SizedBox(height: 8),

            TextButton.icon(
              onPressed: _openMyDrafts,
              icon: const Icon(Icons.list_alt),
              label: const Text('ดูร่างประกาศของฉัน'),
            ),
          ],
        ),
      ),
    );
  }
}
