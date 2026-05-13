import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _titleController = TextEditingController();
  Bank? _selectedBank;
  List<Bank> _banks = [];
  bool _loading = false;
  bool _saving = false;
  String? _mappedFamily;

  @override
  void initState() {
    super.initState();
    _loadBanks();
  }

  Future<void> _loadBanks() async {
    setState(() => _loading = true);
    final banks = await ref.read(firestoreServiceProvider).fetchBanks();
    setState(() { _banks = banks; _loading = false; });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _selectedBank == null) return;

    setState(() => _saving = true);
    try {
      final uid = ref.read(authServiceProvider).currentUser!.uid;
      await ref.read(firestoreServiceProvider).completeProfile(
            uid: uid,
            linkedinTitle: title,
            bankId: _selectedBank!.id,
          );
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.negative),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Set Up Profile')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tell us about your role',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Used only to map you to a Business Family. Not stored as-is.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 28),

                    // Title field
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'LinkedIn Job Title',
                        hintText: 'e.g. Senior Software Engineer',
                      ),
                      onChanged: (_) => setState(() => _mappedFamily = null),
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 24),

                    // Bank picker
                    Text('Your Bank',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 12),
                    _BankPicker(
                      banks: _banks,
                      selected: _selectedBank,
                      onSelect: (b) => setState(() => _selectedBank = b),
                    ),
                    const SizedBox(height: 40),

                    ElevatedButton(
                      onPressed:
                          (_saving || _titleController.text.isEmpty || _selectedBank == null)
                              ? null
                              : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Continue'),
                    ),
                  ],
                ),
              ),
      );
}

class _BankPicker extends StatelessWidget {
  const _BankPicker({
    required this.banks,
    required this.selected,
    required this.onSelect,
  });
  final List<Bank> banks;
  final Bank? selected;
  final ValueChanged<Bank> onSelect;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: banks
            .map((b) => ChoiceChip(
                  label: Text(b.name),
                  selected: selected?.id == b.id,
                  onSelected: (_) => onSelect(b),
                ))
            .toList(),
      );
}
