import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/money_repository.dart';
import '../../data/transaction_model.dart';
import '../../data/models/budget_category_model.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isExpense = true;
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Autre';

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveTransaction() {
    if (_formKey.currentState!.validate()) {
      final title = _titleController.text;
      final amount =
          double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;

      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Le montant doit être supérieur à 0'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';

      final transaction = Transaction(
        title: title,
        amount: amount,
        date: _selectedDate,
        isExpense: _isExpense,
        category: _selectedCategory,
        userId: userId,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      ref.read(moneyRepositoryProvider).addTransaction(transaction);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Utiliser viewInsetsOf pour éviter les rebuilds excessifs sur MIUI
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Nouvelle Transaction'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 16.0,
          bottom: bottomInset + 16.0,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Type de transaction (Dépense / Revenu)
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
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _isExpense = newSelection.first;
                  });
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>(
                    (Set<WidgetState> states) {
                      if (states.contains(WidgetState.selected)) {
                        return _isExpense
                            ? Colors.red.withValues(alpha: 0.2)
                            : Colors.green.withValues(alpha: 0.2);
                      }
                      return Colors.transparent;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Titre
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre',
                  hintText: 'Ex: Courses, Loyer...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un titre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Montant
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Montant',
                  suffixText: '€',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.euro),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un montant';
                  }
                  if (double.tryParse(value.replaceAll(',', '.')) == null) {
                    return 'Veuillez entrer un nombre valide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Date
              InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(_selectedDate),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Catégorie
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  prefixIcon: Icon(
                    getIconByName(
                      DefaultCategories.categories.firstWhere(
                        (c) => c['name'] == _selectedCategory,
                        orElse: () => {'icon_name': 'category'},
                      )['icon_name'] as String?,
                    ),
                  ),
                ),
                items: DefaultCategories.categoryNames
                    .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Row(
                            children: [
                              Icon(
                                getIconByName(
                                  DefaultCategories.categories.firstWhere(
                                    (c) => c['name'] == cat,
                                    orElse: () => {'icon_name': 'category'},
                                  )['icon_name'] as String?,
                                ),
                                size: 20,
                                color: getColorFromHex(
                                  DefaultCategories.categories.firstWhere(
                                    (c) => c['name'] == cat,
                                    orElse: () => {'color': '#607D8B'},
                                  )['color'] as String,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(cat),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Notes (optionnel)
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optionnel)',
                  hintText: 'Ajouter une note...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 32),

              // Bouton Enregistrer
              FilledButton.icon(
                onPressed: _saveTransaction,
                icon: const Icon(Icons.save),
                label: const Text('Enregistrer'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
