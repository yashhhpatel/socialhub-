import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/repositories/api_brand_kit_repository.dart';
import '../../domain/entities/brand_kit.dart';
import '../state/brand_kit_controller.dart';

/// Brand kit editor (Milestone 9.3) — edit the org's colours, fonts and
/// logo. Loads the kit once into local editable state, then PATCHes the
/// whole thing on Save. The designs pull from this via the editor's
/// "apply brand kit" action (see editor/canvas/brand_kit_application.dart).
class BrandKitScreen extends ConsumerStatefulWidget {
  const BrandKitScreen({super.key});

  @override
  ConsumerState<BrandKitScreen> createState() => _BrandKitScreenState();
}

class _BrandKitScreenState extends ConsumerState<BrandKitScreen> {
  List<String>? _colors;
  List<String>? _fonts;
  String? _logoUrl;
  bool _saving = false;

  final _colorController = TextEditingController();
  final _fontController = TextEditingController();
  final _logoController = TextEditingController();

  @override
  void dispose() {
    _colorController.dispose();
    _fontController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  /// Seeds local editable state from the loaded kit exactly once.
  void _hydrate(BrandKit kit) {
    _colors ??= [...kit.colors];
    _fonts ??= [...kit.fonts];
    _logoUrl ??= kit.logoUrl;
  }

  bool _isValidHex(String value) {
    final v = value.trim();
    return RegExp(r'^#([0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(v);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(brandKitRepositoryProvider).update(
            colors: _colors,
            fonts: _fonts,
            logoUrl: _logoUrl,
          );
      ref.invalidate(brandKitProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brand kit saved.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: ${describeApiError(error)}')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kitAsync = ref.watch(brandKitProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: kitAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Could not load your brand kit: ${describeApiError(error)}'),
        ),
        data: (kit) {
          _hydrate(kit);
          return ListView(
            children: [
              Text('Brand Kit', style: theme.textTheme.headlineMedium),
              const SizedBox(height: SpacingTokens.xs),
              Text(
                'Your colours, fonts and logo — apply them to any design from the editor.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: SpacingTokens.lg),
              _ColorsSection(
                colors: _colors!,
                controller: _colorController,
                onAdd: () {
                  final value = _colorController.text.trim();
                  if (!_isValidHex(value)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter a valid hex colour, e.g. #1A2B3C.')),
                    );
                    return;
                  }
                  setState(() {
                    _colors!.add(value);
                    _colorController.clear();
                  });
                },
                onRemove: (c) => setState(() => _colors!.remove(c)),
              ),
              const SizedBox(height: SpacingTokens.lg),
              _FontsSection(
                fonts: _fonts!,
                controller: _fontController,
                onAdd: () {
                  final value = _fontController.text.trim();
                  if (value.isEmpty) return;
                  setState(() {
                    _fonts!.add(value);
                    _fontController.clear();
                  });
                },
                onRemove: (f) => setState(() => _fonts!.remove(f)),
              ),
              const SizedBox(height: SpacingTokens.lg),
              _LogoSection(
                logoUrl: _logoUrl,
                controller: _logoController,
                onSet: () {
                  final value = _logoController.text.trim();
                  if (value.isEmpty) return;
                  setState(() {
                    _logoUrl = value;
                    _logoController.clear();
                  });
                },
                onClear: () => setState(() => _logoUrl = null),
              ),
              const SizedBox(height: SpacingTokens.xl),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save brand kit'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ColorsSection extends StatelessWidget {
  const _ColorsSection({
    required this.colors,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> colors;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final void Function(String) onRemove;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Colours',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (colors.isEmpty)
            const Text('No colours yet.')
          else
            Wrap(
              spacing: SpacingTokens.sm,
              runSpacing: SpacingTokens.sm,
              children: [
                for (final c in colors)
                  Chip(
                    avatar: CircleAvatar(backgroundColor: _swatch(c)),
                    label: Text(c),
                    onDeleted: () => onRemove(c),
                  ),
              ],
            ),
          const SizedBox(height: SpacingTokens.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: '#1A2B3C',
                    labelText: 'Add a hex colour',
                  ),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: SpacingTokens.sm),
              OutlinedButton(onPressed: onAdd, child: const Text('Add')),
            ],
          ),
        ],
      ),
    );
  }

  Color _swatch(String hex) {
    var v = hex.replaceFirst('#', '');
    if (v.length == 3 || v.length == 4) {
      v = v.split('').map((c) => '$c$c').join();
    }
    if (v.length == 6) {
      v = 'FF$v';
    } else if (v.length == 8) {
      v = v.substring(6, 8) + v.substring(0, 6);
    }
    final parsed = int.tryParse(v, radix: 16);
    return parsed == null ? Colors.grey : Color(parsed);
  }
}

class _FontsSection extends StatelessWidget {
  const _FontsSection({
    required this.fonts,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> fonts;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final void Function(String) onRemove;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Fonts',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fonts.isEmpty)
            const Text('No fonts yet.')
          else
            Wrap(
              spacing: SpacingTokens.sm,
              runSpacing: SpacingTokens.sm,
              children: [
                for (final f in fonts)
                  Chip(label: Text(f), onDeleted: () => onRemove(f)),
              ],
            ),
          const SizedBox(height: SpacingTokens.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'Inter',
                    labelText: 'Add a font family',
                  ),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: SpacingTokens.sm),
              OutlinedButton(onPressed: onAdd, child: const Text('Add')),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogoSection extends StatelessWidget {
  const _LogoSection({
    required this.logoUrl,
    required this.controller,
    required this.onSet,
    required this.onClear,
  });

  final String? logoUrl;
  final TextEditingController controller;
  final VoidCallback onSet;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Logo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (logoUrl != null) ...[
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    logoUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
                  ),
                ),
                const SizedBox(width: SpacingTokens.md),
                Expanded(child: Text(logoUrl!, overflow: TextOverflow.ellipsis)),
                TextButton(onPressed: onClear, child: const Text('Remove')),
              ],
            ),
            const SizedBox(height: SpacingTokens.sm),
          ] else
            const Text('No logo set.'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'https://…/logo.png',
                    labelText: 'Logo image URL',
                  ),
                  onSubmitted: (_) => onSet(),
                ),
              ),
              const SizedBox(width: SpacingTokens.sm),
              OutlinedButton(onPressed: onSet, child: const Text('Set')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: SpacingTokens.sm),
          child,
        ],
      ),
    );
  }
}
