import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'transaction_model.dart';

final moneyRepositoryProvider = Provider<MoneyRepository>((ref) {
  return MoneyRepository(Supabase.instance.client);
});

final transactionsProvider = StreamProvider<List<Transaction>>((ref) {
  return ref.watch(moneyRepositoryProvider).watchTransactions();
});

class MoneyRepository {
  final SupabaseClient _client;

  MoneyRepository(this._client);

  Stream<List<Transaction>> watchTransactions() {
    return _client
        .from('transactions')
        .stream(primaryKey: ['id'])
        .order('date', ascending: false)
        .map((data) => data.map((json) => Transaction.fromJson(json)).toList());
  }

  Future<void> addTransaction(Transaction transaction) async {
    // On s'assure que l'ID utilisateur est correct (sécurité supplémentaire)
    final user = _client.auth.currentUser;
    if (user == null) return;

    final data = transaction.toJson();
    data['user_id'] = user.id; // Force l'ID utilisateur courant
    data.remove('id'); // Laisse Supabase générer l'ID

    await _client.from('transactions').insert(data);
  }

  Future<void> deleteTransaction(int id) async {
    await _client.from('transactions').delete().eq('id', id);
  }
}
