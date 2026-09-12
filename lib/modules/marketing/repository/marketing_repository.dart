import '../../../core/database/app_database.dart';
import '../models/offer.dart';

class MarketingRepository {
  final _db = AppDatabase.instance;

  Future<List<Offer>> getAllOffers() async {
    final rows = await _db.database.query('marketing_offers', orderBy: 'created_at DESC');
    return rows.map((r) => Offer.fromMap(r)).toList();
  }

  Future<int> addOffer(Offer offer) => _db.database.insert('marketing_offers', offer.toMap());

  Future<void> deleteOffer(int id) =>
      _db.database.delete('marketing_offers', where: 'id = ?', whereArgs: [id]);
}
