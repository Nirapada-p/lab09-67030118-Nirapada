import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item.dart';
import 'item_repository.dart';

class ItemRepositoryFirestore implements ItemRepository {
  final FirebaseFirestore _firestore;

  ItemRepositoryFirestore({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _itemsCollection =>
      _firestore.collection('items');

  @override
  Future<List<Item>> getItems() async {
    final snapshot = await _itemsCollection.get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return Item(
        id: _getItemId(doc.id, data),
        title: data['title'] as String? ?? '',
        price: (data['price'] as num?)?.toDouble() ?? 0.0,
        description: data['description'] as String? ?? '',
        category: data['category'] as String? ?? '',
        imageUrl: data['imageUrl'] as String? ?? data['image'] as String? ?? '',
      );
    }).toList();
  }

  Future<void> postItem(Item item) async {
    await _itemsCollection.add({
      'id': item.id,
      'title': item.title,
      'price': item.price,
      'description': item.description,
      'category': item.category,
      'imageUrl': item.imageUrl,
    });
  }

  Stream<List<Item>> watchMyListings(String sellerId) {
    return _itemsCollection
        .where('sellerId', isEqualTo: sellerId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();

            return Item(
              id: _getItemId(doc.id, data),
              title: data['title'] as String? ?? '',
              price: (data['price'] as num?)?.toDouble() ?? 0.0,
              description: data['description'] as String? ?? '',
              category: data['category'] as String? ?? '',
              imageUrl:
                  data['imageUrl'] as String? ?? data['image'] as String? ?? '',
            );
          }).toList();
        });
  }

  int _getItemId(String documentId, Map<String, dynamic> data) {
    final id = data['id'];

    if (id is int) return id;

    return int.tryParse(documentId) ?? documentId.hashCode;
  }
}
