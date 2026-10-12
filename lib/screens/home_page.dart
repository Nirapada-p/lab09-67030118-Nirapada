import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/item.dart';
import '../models/cart_model.dart';
import '../repositories/item_repository.dart';
import '../repositories/favorites_repository.dart';
import '../services/gemini_service.dart';
import '../services/auth_service.dart';
import '../widgets/item_image.dart';
import 'checkout_page.dart';

class HomePage extends StatefulWidget {
  final List<ItemRepository> repositories;
  final FavoritesRepository favoritesRepository;

  const HomePage({
    super.key,
    required this.repositories,
    required this.favoritesRepository,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ลำดับของ repository ใน main.dart: [API, Firestore]
  static const int _firestoreSourceIndex = 1;

  late Future<List<_SourcedItem>> _itemsFuture;

  final Set<int> _favoriteItemIds = <int>{};

  @override
  void initState() {
    super.initState();
    _itemsFuture = _loadAllItems();
    _loadFavorites();
  }

  Future<List<_SourcedItem>> _loadAllItems() async {
    final results = await Future.wait(
      widget.repositories.map((repository) => repository.getItems()),
    );

    final studentItems = <_SourcedItem>[];
    final otherItems = <_SourcedItem>[];

    for (var i = 0; i < results.length; i++) {
      for (final item in results[i]) {
        final sourcedItem = _SourcedItem(item: item, sourceIndex: i);

        if (i == _firestoreSourceIndex) {
          studentItems.add(sourcedItem);
        } else {
          otherItems.add(sourcedItem);
        }
      }
    }

    // สินค้านักศึกษา: ใหม่สุดขึ้นก่อน (id คือเวลาที่โพสต์)
    studentItems.sort((a, b) => b.item.id.compareTo(a.item.id));

    return [...studentItems, ...otherItems];
  }

  // โหลดรายการสินค้าใหม่ (ใช้ตอนดึงลงเพื่อรีเฟรช หรือกดปุ่มรีเฟรช)
  Future<void> _reload() async {
    final future = _loadAllItems();

    setState(() {
      _itemsFuture = future;
    });

    try {
      await future;
    } catch (_) {
      // ข้อผิดพลาดจะแสดงผ่าน FutureBuilder อยู่แล้ว
    }

    await _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final favorites = await widget.favoritesRepository.getAllFavorites();

      if (!mounted) return;

      setState(() {
        _favoriteItemIds
          ..clear()
          ..addAll(favorites.map((favorite) => favorite.itemId));
      });
    } catch (e) {
      debugPrint('ไม่สามารถโหลดรายการโปรดได้: $e');
    }
  }

  Future<void> _testGemini() async {
    try {
      final result = await GeminiService().generateText(
        'ช่วยแต่งประโยคทักทายลูกค้าร้านค้าออนไลน์แบบเป็นกันเอง',
      );

      debugPrint('Gemini Response: $result');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result), duration: const Duration(seconds: 5)),
      );
    } catch (e) {
      debugPrint('Gemini Error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    try {
      await AuthService().signOut();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ออกจากระบบไม่สำเร็จ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Marketplace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชสินค้า',
            onPressed: _reload,
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'ทดสอบ Gemini',
            onPressed: _testGemini,
          ),
          IconButton(
            icon: Badge(
              label: Text('${context.watch<CartModel>().itemCount}'),
              child: const Icon(Icons.shopping_cart),
            ),
            tooltip: 'ตะกร้าสินค้า',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CheckoutPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: _signOut,
          ),
        ],
      ),
      body: FutureBuilder<List<_SourcedItem>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
          }

          final sourcedItems = snapshot.data ?? [];

          if (sourcedItems.isEmpty) {
            return const Center(child: Text('ไม่พบสินค้า'));
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: sourcedItems.length,
              itemBuilder: (context, index) {
                final sourcedItem = sourcedItems[index];
                final item = sourcedItem.item;
                final isFavorite = _favoriteItemIds.contains(item.id);

                final isFirestore =
                    sourcedItem.sourceIndex == _firestoreSourceIndex;

                // รูปที่ใช้แสดง: Base64 (สินค้านักศึกษา) หรือ URL (สินค้าจาก API)
                final imageSource = ItemImage.pick(
                  img: item.img,
                  imageUrl: item.imageUrl,
                );

                return ListTile(
                  leading: ItemImage(source: imageSource, size: 56),
                  title: Text(item.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${item.price} บาท'),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          avatar: Icon(
                            isFirestore ? Icons.school : Icons.storefront,
                            size: 16,
                          ),
                          label: Text(
                            isFirestore
                                ? '🎓 สินค้านักศึกษา'
                                : '🏪 สินค้าจาก API',
                          ),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                        ),
                        color: isFavorite ? Colors.red : null,
                        tooltip: isFavorite
                            ? 'อยู่ในรายการโปรดแล้ว'
                            : 'เพิ่มในรายการโปรด',
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);

                          try {
                            await widget.favoritesRepository.addFavorite(
                              item.id,
                              item.title,
                              item.price,
                              imageSource ?? '',
                            );

                            if (!mounted) return;

                            setState(() {
                              _favoriteItemIds.add(item.id);
                            });

                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('เพิ่มสินค้าในรายการโปรดแล้ว'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'ไม่สามารถเพิ่มรายการโปรดได้: $e',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_shopping_cart),
                        tooltip: 'เพิ่มลงตะกร้า',
                        onPressed: () {
                          context.read<CartModel>().add(item);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'เพิ่ม "${item.title}" ลงตะกร้าแล้ว',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _SourcedItem {
  final Item item;
  final int sourceIndex;

  const _SourcedItem({required this.item, required this.sourceIndex});
}
