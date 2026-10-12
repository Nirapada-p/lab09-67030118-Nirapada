import 'package:flutter/material.dart';

import 'home_page.dart';
import 'sell_item_page.dart';
import 'favorites_page.dart';

import '../repositories/item_repository.dart';
import '../repositories/favorites_repository.dart';
import '../repositories/listing_draft_repository.dart';

class MainScaffold extends StatefulWidget {
  final List<ItemRepository> itemRepositories;
  final FavoritesRepository favoritesRepository;
  final ListingDraftRepository draftRepository;

  const MainScaffold({
    super.key,
    required this.itemRepositories,
    required this.favoritesRepository,
    required this.draftRepository,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  // เปลี่ยนค่านี้เพื่อให้ HomePage สร้างใหม่และโหลดสินค้าล่าสุดจาก Firestore
  int _homeReloadCount = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        key: ValueKey(_homeReloadCount),
        repositories: widget.itemRepositories,
        favoritesRepository: widget.favoritesRepository,
      ),
      SellItemPage(draftRepository: widget.draftRepository),
      FavoritesPage(repository: widget.favoritesRepository),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            // กลับมาหน้าหลักจากแท็บอื่น ให้โหลดสินค้าใหม่ (เห็นสินค้าที่เพิ่งโพสต์)
            if (index == 0 && _selectedIndex != 0) {
              _homeReloadCount++;
            }

            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront),
            label: 'หน้าหลัก',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_a_photo),
            label: 'ลงประกาศขาย',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'รายการโปรด',
          ),
        ],
      ),
    );
  }
}
