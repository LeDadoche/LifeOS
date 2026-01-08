import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/money_repository.dart';
import '../../data/models/savings_goal_model.dart';
import '../../data/models/budget_category_model.dart';

class SavingsGoalsScreen extends ConsumerWidget {
  const SavingsGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(savingsGoalsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Objectifs d\'\u00c9pargne'),
      ),
      body: goalsAsync.when(
        data: (goals) {
          if (goals.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      size: 80,
                      color: colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Créez votre premier objectif',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Définissez des objectifs d\'épargne pour suivre votre progression',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: () => _showAddDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Créer un objectif'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Séparer les objectifs actifs et complétés
          final active = goals.where((g) => !g.isCompleted).toList();
          final completed = goals.where((g) => g.isCompleted).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Résumé
                _buildSummaryCard(context, goals),
                const SizedBox(height: 24),

                // Objectifs actifs
                if (active.isNotEmpty) ...[
                  _buildSectionHeader(context, 'Objectifs en cours', colorScheme.primary),
                  const SizedBox(height: 12),
                  ...active.map((goal) => _GoalCard(
                    goal: goal,
                    onTap: () => _showEditDialog(context, ref, goal),
                    onAddAmount: (amount) {
                      if (goal.id != null) {
                        ref.read(moneyRepositoryProvider).addToSavingsGoal(goal.id!, amount);
                      }
                    },
                    onDelete: () => _showDeleteDialog(context, ref, goal),
                  )),
                  const SizedBox(height: 24),
                ],

                // Objectifs complétés
                if (completed.isNotEmpty) ...[
                  _buildSectionHeader(context, 'Objectifs atteints 🎉', Colors.green),
                  const SizedBox(height: 12),
                  ...completed.map((goal) => _GoalCard(
                    goal: goal,
                    onTap: () => _showEditDialog(context, ref, goal),
                    onDelete: () => _showDeleteDialog(context, ref, goal),
                  )),
                ],

                const SizedBox(height: 80),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Erreur: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouvel objectif'),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, List<SavingsGoal> goals) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalTarget = goals.fold<double>(0, (sum, g) => sum + g.targetAmount);
    final totalSaved = goals.fold<double>(0, (sum, g) => sum + g.currentAmount);
    final completedCount = goals.where((g) => g.isCompleted).length;

    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.savings, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Vue d\'ensemble',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat(context, '${goals.length}', 'Objectifs'),
                _buildStat(context, '$completedCount', 'Atteints'),
                _buildStat(context, '${totalSaved.toStringAsFixed(0)}€', 'Épargnés'),
              ],
            ),
            const SizedBox(height: 16),
            // Progression globale
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progression globale',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${(totalTarget > 0 ? (totalSaved / totalTarget) * 100 : 0).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: totalTarget > 0 ? (totalSaved / totalTarget).clamp(0.0, 1.0) : 0,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 10,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _SavingsGoalForm(
        onSave: (goal) {
          ref.read(moneyRepositoryProvider).addSavingsGoal(goal);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, SavingsGoal goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _SavingsGoalForm(
        goal: goal,
        onSave: (updated) {
          ref.read(moneyRepositoryProvider).updateSavingsGoal(updated);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, SavingsGoal goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer l\'objectif "${goal.title}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              if (goal.id != null) {
                ref.read(moneyRepositoryProvider).deleteSavingsGoal(goal.id!);
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

class _GoalCard extends StatelessWidget {
  final SavingsGoal goal;
  final VoidCallback onTap;
  final Function(double)? onAddAmount;
  final VoidCallback onDelete;

  const _GoalCard({
    required this.goal,
    required this.onTap,
    this.onAddAmount,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = getColorFromHex(goal.color);
    final icon = getIconByName(goal.iconName);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: goal.isCompleted
          ? Colors.green.withValues(alpha: 0.1)
          : colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: goal.isCompleted
              ? Colors.green.withValues(alpha: 0.3)
              : color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (goal.isCompleted ? Colors.green : color)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      goal.isCompleted ? Icons.check_circle : icon,
                      color: goal.isCompleted ? Colors.green : color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            decoration: goal.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (goal.description != null)
                          Text(
                            goal.description!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (!goal.isCompleted && onAddAmount != null)
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: color,
                      onPressed: () => _showAddAmountDialog(context),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Progression
              Row(
                children: [
                  // Cercle de progression
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 70,
                          height: 70,
                          child: CircularProgressIndicator(
                            value: goal.progressRatio,
                            strokeWidth: 6,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              goal.isCompleted ? Colors.green : color,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${goal.progressPercent}%',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: goal.isCompleted ? Colors.green : color,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Détails
                  Expanded(
                    child: Column(
                      children: [
                        _buildProgressRow(
                          context,
                          'Épargné',
                          goal.currentAmount,
                          goal.isCompleted ? Colors.green : color,
                        ),
                        const SizedBox(height: 8),
                        _buildProgressRow(
                          context,
                          'Objectif',
                          goal.targetAmount,
                          colorScheme.onSurfaceVariant,
                        ),
                        if (!goal.isCompleted) ...[
                          const SizedBox(height: 8),
                          _buildProgressRow(
                            context,
                            'Restant',
                            goal.remainingAmount,
                            Colors.orange,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // Date cible
              if (goal.targetDate != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Échéance: ${_formatDate(goal.targetDate!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_isOverdue(goal.targetDate!) && !goal.isCompleted) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'En retard',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Complet message
              if (goal.isCompleted && goal.completedAt != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.celebration, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        'Atteint le ${_formatDate(goal.completedAt!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressRow(
    BuildContext context,
    String label,
    double amount,
    Color color,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          '${amount.toStringAsFixed(2)} €',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  bool _isOverdue(DateTime date) {
    return date.isBefore(DateTime.now());
  }

  void _showAddAmountDialog(BuildContext context) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ajouter à "${goal.title}"'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Montant',
            suffixText: '€',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(controller.text.replaceAll(',', '.'));
              if (amount != null && amount > 0 && onAddAmount != null) {
                onAddAmount!(amount);
                Navigator.pop(context);
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }
}

class _SavingsGoalForm extends StatefulWidget {
  final SavingsGoal? goal;
  final Function(SavingsGoal) onSave;

  const _SavingsGoalForm({
    this.goal,
    required this.onSave,
  });

  @override
  State<_SavingsGoalForm> createState() => _SavingsGoalFormState();
}

class _SavingsGoalFormState extends State<_SavingsGoalForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetController = TextEditingController();
  final _currentController = TextEditingController();
  DateTime? _targetDate;
  String _selectedColor = '#4CAF50';
  String _selectedIcon = 'savings';

  static const List<String> _colors = [
    '#4CAF50', '#FF9800', '#2196F3', '#F44336', '#9C27B0',
    '#00BCD4', '#8BC34A', '#E91E63', '#3F51B5', '#607D8B',
  ];

  static const List<Map<String, dynamic>> _iconOptions = [
    {'name': 'savings', 'label': 'Épargne'},
    {'name': 'flight', 'label': 'Voyage'},
    {'name': 'beach_access', 'label': 'Vacances'},
    {'name': 'home', 'label': 'Maison'},
    {'name': 'directions_car', 'label': 'Voiture'},
    {'name': 'school', 'label': 'Études'},
    {'name': 'child_care', 'label': 'Enfants'},
    {'name': 'fitness_center', 'label': 'Sport'},
    {'name': 'shopping_bag', 'label': 'Shopping'},
    {'name': 'pets', 'label': 'Animaux'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.goal != null) {
      _titleController.text = widget.goal!.title;
      _descriptionController.text = widget.goal!.description ?? '';
      _targetController.text = widget.goal!.targetAmount.toString();
      _currentController.text = widget.goal!.currentAmount.toString();
      _targetDate = widget.goal!.targetDate;
      _selectedColor = widget.goal!.color ?? '#4CAF50';
      _selectedIcon = widget.goal!.iconName ?? 'savings';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    _currentController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (date != null) {
      setState(() => _targetDate = date);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    
    final goal = SavingsGoal(
      id: widget.goal?.id,
      userId: userId,
      title: _titleController.text,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      targetAmount: double.tryParse(_targetController.text.replaceAll(',', '.')) ?? 0,
      currentAmount: double.tryParse(_currentController.text.replaceAll(',', '.')) ?? 0,
      targetDate: _targetDate,
      iconName: _selectedIcon,
      color: _selectedColor,
      isCompleted: widget.goal?.isCompleted ?? false,
      completedAt: widget.goal?.completedAt,
    );

    widget.onSave(goal);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
                widget.goal == null 
                    ? 'Nouvel objectif d\'épargne'
                    : 'Modifier l\'objectif',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Titre
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Nom de l\'objectif',
                  hintText: 'Ex: Vacances d\'été',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un nom';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (optionnelle)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Montants
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _targetController,
                      decoration: InputDecoration(
                        labelText: 'Objectif',
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
                        final amount = double.tryParse(value.replaceAll(',', '.'));
                        if (amount == null || amount <= 0) {
                          return 'Invalide';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _currentController,
                      decoration: InputDecoration(
                        labelText: 'Déjà épargné',
                        suffixText: '€',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Date cible
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date cible (optionnelle)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _targetDate != null
                        ? '${_targetDate!.day.toString().padLeft(2, '0')}/${_targetDate!.month.toString().padLeft(2, '0')}/${_targetDate!.year}'
                        : 'Aucune date définie',
                    style: TextStyle(
                      color: _targetDate != null 
                          ? colorScheme.onSurface 
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Icône
              Text(
                'Icône',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _iconOptions.map((opt) {
                  final iconName = opt['name'] as String;
                  final icon = getIconByName(iconName);
                  final isSelected = _selectedIcon == iconName;
                  final selectedColor = getColorFromHex(_selectedColor);
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = iconName),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? selectedColor.withValues(alpha: 0.2)
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: selectedColor, width: 2)
                            : null,
                      ),
                      child: Icon(
                        icon,
                        color: isSelected ? selectedColor : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Couleur
              Text(
                'Couleur',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _colors.map((colorHex) {
                  final color = getColorFromHex(colorHex);
                  final isSelected = _selectedColor == colorHex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = colorHex),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: colorScheme.onSurface, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
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
                  child: Text(widget.goal == null ? 'Créer l\'objectif' : 'Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
