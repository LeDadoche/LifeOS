import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/money_repository.dart';
import '../../data/models/recurring_transaction_model.dart';
import '../../data/models/budget_category_model.dart';

class RecurringTransactionsScreen extends ConsumerWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringTransactionsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Transactions Permanentes'),
      ),
      body: recurringAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.repeat,
                      size: 64,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune transaction permanente',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ajoutez vos dépenses et revenus récurrents',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => _showAddDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Séparer revenus et dépenses
          final revenus = transactions.where((t) => !t.isExpense).toList();
          final depenses = transactions.where((t) => t.isExpense).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Résumé
                _buildSummaryCard(context, revenus, depenses),
                const SizedBox(height: 24),

                // Revenus
                if (revenus.isNotEmpty) ...[
                  _buildSectionHeader(context, 'Revenus récurrents', Colors.green),
                  const SizedBox(height: 12),
                  ...revenus.map((t) => _buildTransactionTile(context, ref, t)),
                  const SizedBox(height: 24),
                ],

                // Dépenses
                if (depenses.isNotEmpty) ...[
                  _buildSectionHeader(context, 'Dépenses récurrentes', colorScheme.error),
                  const SizedBox(height: 12),
                  ...depenses.map((t) => _buildTransactionTile(context, ref, t)),
                ],

                const SizedBox(height: 80), // Espace pour le FAB
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Erreur: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    List<RecurringTransaction> revenus,
    List<RecurringTransaction> depenses,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalRevenus = revenus.fold<double>(0, (sum, t) => sum + t.amount);
    final totalDepenses = depenses.fold<double>(0, (sum, t) => sum + t.amount);
    final solde = totalRevenus - totalDepenses;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Résumé mensuel',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(context, 'Revenus', totalRevenus, Colors.green),
                _buildSummaryItem(context, 'Dépenses', totalDepenses, colorScheme.error),
                _buildSummaryItem(
                  context, 
                  'Solde', 
                  solde, 
                  solde >= 0 ? Colors.green : colorScheme.error,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    double value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(0)} €',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionTile(
    BuildContext context,
    WidgetRef ref,
    RecurringTransaction transaction,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = transaction.isExpense ? colorScheme.error : Colors.green;
    final categoryColor = getColorFromHex(
      DefaultCategories.categories
          .firstWhere(
            (c) => c['name'] == transaction.category,
            orElse: () => {'color': '#607D8B'},
          )['color'] as String,
    );

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: categoryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              '${transaction.dayOfMonth}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: categoryColor,
              ),
            ),
          ),
        ),
        title: Text(
          transaction.title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text('${transaction.category} • Jour ${transaction.dayOfMonth}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${transaction.isExpense ? '-' : '+'}${transaction.amount.toStringAsFixed(0)} €',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: transaction.isActive,
              onChanged: (value) {
                if (transaction.id != null) {
                  ref.read(moneyRepositoryProvider)
                      .toggleRecurringTransaction(transaction.id!, value);
                }
              },
            ),
          ],
        ),
        onTap: () => _showEditDialog(context, ref, transaction),
        onLongPress: () => _showDeleteDialog(context, ref, transaction),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _RecurringTransactionForm(
        onSave: (transaction) {
          ref.read(moneyRepositoryProvider).addRecurringTransaction(transaction);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, RecurringTransaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _RecurringTransactionForm(
        transaction: transaction,
        onSave: (updated) {
          ref.read(moneyRepositoryProvider).updateRecurringTransaction(updated);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, RecurringTransaction transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer "${transaction.title}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              if (transaction.id != null) {
                ref.read(moneyRepositoryProvider)
                    .deleteRecurringTransaction(transaction.id!);
              }
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

class _RecurringTransactionForm extends StatefulWidget {
  final RecurringTransaction? transaction;
  final Function(RecurringTransaction) onSave;

  const _RecurringTransactionForm({
    this.transaction,
    required this.onSave,
  });

  @override
  State<_RecurringTransactionForm> createState() => _RecurringTransactionFormState();
}

class _RecurringTransactionFormState extends State<_RecurringTransactionForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isExpense = true;
  int _dayOfMonth = 1;
  String _category = 'Autre';

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _titleController.text = widget.transaction!.title;
      _amountController.text = widget.transaction!.amount.toString();
      _isExpense = widget.transaction!.isExpense;
      _dayOfMonth = widget.transaction!.dayOfMonth;
      _category = widget.transaction!.category;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    
    final transaction = RecurringTransaction(
      id: widget.transaction?.id,
      title: _titleController.text,
      amount: double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0,
      category: _category,
      dayOfMonth: _dayOfMonth,
      isExpense: _isExpense,
      userId: userId,
      isActive: widget.transaction?.isActive ?? true,
    );

    widget.onSave(transaction);
  }

  @override
  Widget build(BuildContext context) {
    // Utiliser viewInsetsOf pour éviter les rebuilds excessifs sur MIUI
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    
    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomInset,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.transaction == null 
                    ? 'Nouvelle transaction permanente'
                    : 'Modifier la transaction',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Type
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Dépense'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Revenu'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                ],
                selected: {_isExpense},
                onSelectionChanged: (value) {
                  setState(() => _isExpense = value.first);
                },
              ),
              const SizedBox(height: 16),

              // Titre
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Titre',
                  hintText: 'Ex: Loyer, Salaire...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un titre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Montant et Jour
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Montant',
                        suffixText: '€',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Requis';
                        }
                        if (double.tryParse(value.replaceAll(',', '.')) == null) {
                          return 'Invalide';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _dayOfMonth,
                      decoration: InputDecoration(
                        labelText: 'Jour',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: List.generate(31, (i) => i + 1)
                          .map((day) => DropdownMenuItem(
                                value: day,
                                child: Text('$day'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _dayOfMonth = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Catégorie
              DropdownButtonFormField<String>(
                initialValue: DefaultCategories.categoryNames.contains(_category) 
                    ? _category 
                    : 'Autre',
                decoration: InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: DefaultCategories.categoryNames
                    .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _category = value);
                  }
                },
              ),
              const SizedBox(height: 24),

              // Bouton
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(widget.transaction == null ? 'Ajouter' : 'Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
