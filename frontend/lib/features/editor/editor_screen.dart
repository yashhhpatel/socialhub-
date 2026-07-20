import 'package:flutter/material.dart';

import 'canvas/models/canvas_document.dart';
import 'canvas/widgets/canvas_surface.dart';
import 'panels/layer_panel.dart';
import 'panels/property_panel.dart';
import 'panels/toolbar.dart';

/// Assembles the canvas engine (Milestone 3.3) with the panels/toolbar
/// built in this milestone into one screen.
///
/// NOTE: the blueprint lists this file as "modified" for Milestone 3.4,
/// but it never existed before now — Milestone 3.3 built only the
/// canvas engine itself (files under canvas/), not a screen around it.
/// Created here instead, flagged the same way as every other case in
/// this project where the blueprint's literal file list didn't quite
/// match what the milestone needed to actually be buildable/verifiable.
///
/// `initialDocument` defaults to a blank 1080x1080 artboard — there's no
/// real asset-loading integration yet (that's part of wiring this
/// screen into a real ContentAsset, a reasonable next increment once
/// there's a route to reach this screen from). Not wired into
/// app_router.dart yet, matching this milestone's scope — only
/// content.controller.ts-adjacent frontend work was requested, not
/// routing.
class EditorScreen extends StatelessWidget {
  EditorScreen({super.key, CanvasDocument? initialDocument})
      : document = initialDocument ?? const CanvasDocument(width: 1080, height: 1080);

  final CanvasDocument document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EditorToolbar(document: document),
      body: Row(
        children: [
          LayerPanel(document: document),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: CanvasSurface(document: document),
            ),
          ),
          const VerticalDivider(width: 1),
          PropertyPanel(document: document),
        ],
      ),
    );
  }
}
