import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/money_repository.dart';
import '../../data/models/financial_profile_model.dart';

class FinancialProfileScreen extends ConsumerStatefulWidget {
  const FinancialProfileScreen({super.key});

  @override
  ConsumerState<FinancialProfileScreen> createState() =>
      _FinancialProfileScreenState();
}

class _FinancialProfileScreenState
    extends ConsumerState<FinancialProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _salaryController = TextEditingController();
  final _overdraftController = TextEditingController();
  final _savingsGoalController = TextEditingController();
  final _weeklyGroceryController = TextEditingController();
  int _payDay = 1;
  bool _isLoading = true;
  FinancialProfile? _existingProfile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile =
        await ref.read(moneyRepositoryProvider).getFinancialProfile();
    if (profile != null) {
      _existingProfile = profile;
      _salaryController.text = profile.averageSalary.toString();
      _overdraftController.text = profile.overdraftLimit.toString();
      _savingsGoalController.text = profile.savingsGoal.toString();
      _weeklyGroceryController.text = profile.weeklyGroceryBudget.toString();
      _payDay = profile.payDay;
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _salaryController.dispose();
    _overdraftController.dispose();
    _savingsGoalController.dispose();
    _weeklyGroceryController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';

    final profile = FinancialProfile(
      id: _existingProfile?.id,
      userId: userId,
      averageSalary:
          double.tryParse(_salaryController.text.replaceAll(',', '.')) ?? 0,
      payDay: _payDay,
      overdraftLimit:
          double.tryParse(_overdraftController.text.replaceAll(',', '.')) ?? 0,
      savingsGoal:
          double.tryParse(_savingsGoalController.text.replaceAll(',', '.')) ??
              0,
      weeklyGroceryBudget:
          double.tryParse(_weeklyGroceryController.text.replaceAll(',', '.')) ??
              0,
    );

    await ref.read(moneyRepositoryProvider).saveFinancialProfile(profile);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil financier enregistré'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Profil Financier'),
        actions: [
          TextButton.icon(
            onPressed: _saveProfile,
            icon: const Icon(Icons.save),
            label: const Text('Enregistrer'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête explicatif
                    Card(
                      elevation: 0,
                      color:
                          colorScheme.primaryContainer.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Ces informations permettent de calculer votre santé financière et votre reste à vivre.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section Revenus
                    _buildSectionHeader(context, 'Revenus', Icons.trending_up),
                    const SizedBox(height: 12),

                    // Salaire moyen
                    TextFormField(
                      controller: _salaryController,
                      decoration: InputDecoration(
                        labelText: 'Salaire moyen mensuel',
                        hintText: 'Ex: 2500',
                        suffixText: '€',
                        prefixIcon: const Icon(Icons.euro),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        helperText:
                            'Utilisé pour calculer votre indicateur de santé financière',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        if (double.tryParse(value.replaceAll(',', '.')) ==
                            null) {
                          return 'Veuillez entrer un nombre valide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Jour de paie
                    DropdownButtonFormField<int>(
                      initialValue: _payDay,
                      decoration: InputDecoration(
                        labelText: 'Jour de paie',
                        prefixIcon: const Icon(Icons.calendar_month),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        helperText:
                            'Jour du mois où vous recevez votre salaire',
                      ),
                      items: List.generate(31, (i) => i + 1)
                          .map((day) => DropdownMenuItem(
                                value: day,
                                child: Text('$day'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _payDay = value);
                        }
                      },
                    ),
                    const SizedBox(height: 32),

                    // Section Limites
                    _buildSectionHeader(context, 'Limites', Icons.shield),
                    const SizedBox(height: 12),

                    // Plafond de découvert
                    TextFormField(
                      controller: _overdraftController,
                      decoration: InputDecoration(
                        labelText: 'Plafond de découvert autorisé',
                        hintText: 'Ex: 500',
                        suffixText: '€',
                        prefixIcon: const Icon(Icons.account_balance),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        helperText:
                            'Ajouté au solde pour calculer le plafond de sécurité',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        if (double.tryParse(value.replaceAll(',', '.')) ==
                            null) {
                          return 'Veuillez entrer un nombre valide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Section Budget Courses
                    _buildSectionHeader(context, 'Budget Courses (Famille)',
                        Icons.shopping_basket),
                    const SizedBox(height: 12),

                    // Explication budget hebdomadaire
                    Card(
                      elevation: 0,
                      color:
                          colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: colorScheme.tertiary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Le budget hebdomadaire sera multiplié par le nombre de semaines restantes dans le mois.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onTertiaryContainer,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _weeklyGroceryController,
                      decoration: InputDecoration(
                        labelText: 'Budget courses par semaine',
                        hintText: 'Ex: 200',
                        suffixText: '€/sem',
                        prefixIcon: const Icon(Icons.shopping_cart),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        helperText:
                            'Exemple: 200€ × 4 semaines = 800€/mois réservés',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        if (double.tryParse(value.replaceAll(',', '.')) ==
                            null) {
                          return 'Veuillez entrer un nombre valide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Section Objectifs
                    _buildSectionHeader(context, 'Objectifs', Icons.savings),
                    const SizedBox(height: 12),

                    // Objectif d'épargne
                    TextFormField(
                      controller: _savingsGoalController,
                      decoration: InputDecoration(
                        labelText: 'Objectif d\'épargne mensuel',
                        hintText: 'Ex: 200',
                        suffixText: '€',
                        prefixIcon: const Icon(Icons.savings),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        helperText:
                            'Montant que vous souhaitez épargner chaque mois',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        if (double.tryParse(value.replaceAll(',', '.')) ==
                            null) {
                          return 'Veuillez entrer un nombre valide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Bouton Enregistrer
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saveProfile,
                        icon: const Icon(Icons.save),
                        label: const Text('Enregistrer le profil'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: colorScheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
        ),
      ],
    );
  }
}
