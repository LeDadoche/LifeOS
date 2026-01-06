import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/event_model.dart';

/// Widget de sélection de rappel avec BottomSheet élégant
/// Inclut Haptic Feedback et support d'accessibilité
class ReminderPicker extends StatelessWidget {
  final ReminderOption selectedOption;
  final ValueChanged<ReminderOption> onChanged;

  const ReminderPicker({
    super.key,
    required this.selectedOption,
    required this.onChanged,
  });

  /// Affiche le BottomSheet de sélection
  static Future<ReminderOption?> show(
    BuildContext context, {
    required ReminderOption currentOption,
  }) async {
    return showModalBottomSheet<ReminderOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReminderBottomSheet(
        currentOption: currentOption,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Sélectionner un rappel. Actuellement : ${selectedOption.label}',
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          HapticFeedback.selectionClick();
          final result = await show(context, currentOption: selectedOption);
          if (result != null) {
            onChanged(result);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Icon(
                selectedOption.icon,
                size: 20,
                color: selectedOption == ReminderOption.none
                    ? colorScheme.outline
                    : colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rappel',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedOption.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: selectedOption == ReminderOption.none
                                ? colorScheme.outline
                                : colorScheme.onSurface,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// BottomSheet interne pour la sélection
class _ReminderBottomSheet extends StatefulWidget {
  final ReminderOption currentOption;

  const _ReminderBottomSheet({
    required this.currentOption,
  });

  @override
  State<_ReminderBottomSheet> createState() => _ReminderBottomSheetState();
}

class _ReminderBottomSheetState extends State<_ReminderBottomSheet> {
  late ReminderOption _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentOption;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Poignée de drag
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outline.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Titre
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Choisir un rappel',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Options de rappel
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ReminderOption.values.length,
            itemBuilder: (context, index) {
              final option = ReminderOption.values[index];
              final isSelected = option == _selected;

              return Semantics(
                label: option.label,
                selected: isSelected,
                button: true,
                hint: 'Appuyer pour sélectionner ce rappel',
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      option.icon,
                      size: 20,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outline,
                    ),
                  ),
                  title: Text(
                    option.label,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle,
                          color: colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    // Haptic feedback premium
                    HapticFeedback.lightImpact();
                    setState(() => _selected = option);
                  },
                ),
              );
            },
          ),

          const Divider(height: 1),

          // Boutons d'action
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.of(context).pop(_selected);
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Confirmer'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
