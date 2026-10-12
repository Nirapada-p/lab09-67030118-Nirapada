import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item.dart';
import 'item_repository.dart';

class ItemRepositoryFirestore implements ItemRepository {
  final FirebaseFirestore _firestore;

  ItemRepositoryFirestore({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _itemsCollection =>
      _firestore.collection('items');

  // อ่านสินค้าทั้งหมดจาก Firestore
  @override
  Future<List<Item>> getItems() async {
    final snapshot = await _itemsCollection.get();

    return snapshot.docs.map((doc) => Item.fromFirestore(doc)).toList();
  }

  // บันทึกสินค้าใหม่ลง Firestore
  Future<void> postItem(Item item) async {
    final sellerId = item.sellerId;

    if (sellerId == null || sellerId.isEmpty) {
      throw ArgumentError('ไม่สามารถโพสต์สินค้าได้ เนื่องจากไม่มี sellerId');
    }

    await _itemsCollection.add(item.toFirestore());
  }

  // ติดตามสินค้าของผู้ขายแต่ละคน
  Stream<List<Item>> watchMyListings(String sellerId) {
    return _itemsCollection
        .where('sellerId', isEqualTo: sellerId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Item.fromFirestore(doc)).toList(),
        );
  }
}
