import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/demo/demo_mode.dart';
import '../../data/demo_templates.dart';
import '../../data/repositories/api_templates_repository.dart';
import '../../domain/entities/template.dart';

/// The org's templates for the gallery (Milestone 9.4). Fetched on demand
/// and invalidated after a new template is saved from the editor.
final templatesProvider = FutureProvider.autoDispose<List<TemplateSummary>>(
  (ref) async {
    if (ref.watch(demoModeProvider)) return demoTemplates;
    return ref.watch(templatesRepositoryProvider).list();
  },
);
