import '../models/canvas_document.dart';

class CanvasEditorState {
  const CanvasEditorState({required this.document, this.selectedLayerId});

  final CanvasDocument document;
  final String? selectedLayerId;
}
