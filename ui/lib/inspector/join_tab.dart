import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'inspector_controller.dart';
import 'widgets.dart';

/// Join tab: ordered fragments in, one joined path out.
class JoinTab extends StatelessWidget {
  /// Creates the tab.
  const JoinTab({super.key, required this.controller});

  final InspectorController controller;

  void _commit() {
    final text = controller.fragmentField.text;
    controller.fragmentField.clear();
    controller.addFragments(text);
  }

  void _onChanged(String text) {
    // Typing or pasting a separator splits right away.
    final seps = [controller.separator, if (controller.separator == r'\') '/'];
    if (seps.any(text.contains)) _commit();
  }

  @override
  Widget build(BuildContext context) {
    final c = ipColors(context);
    final fragments = controller.fragments;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(PvSpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Fragments, in order',
            style: TextStyle(
              color: c.onSurfaceMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: PvSpace.sm),
          if (fragments.isNotEmpty) ...[
            Wrap(
              spacing: PvSpace.sm,
              runSpacing: PvSpace.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < fragments.length; i++) ...[
                  if (i > 0)
                    Text(
                      controller.separator,
                      style: ipMono(context, color: c.onSurfaceSubtle),
                    ),
                  _FragmentChip(
                    key: ValueKey('fragment-$i'),
                    text: fragments[i],
                    onRemove: () => controller.removeFragment(i),
                  ),
                ],
              ],
            ),
            const SizedBox(height: PvSpace.md),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('fragment-field'),
                  controller: controller.fragmentField,
                  autofocus: true,
                  style: ipMono(context),
                  onChanged: _onChanged,
                  onSubmitted: (_) => _commit(),
                  decoration: ipFieldDecoration(
                    context,
                    hint: 'Next fragment, then Enter',
                  ),
                ),
              ),
              const SizedBox(width: PvSpace.sm),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _commit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.onSurface,
                    side: BorderSide(color: c.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PvRadius.control),
                    ),
                  ),
                  child: const Text('Add'),
                ),
              ),
            ],
          ),
          const SizedBox(height: PvSpace.sm),
          Text(
            'Paste a whole path here and it splits into fragments. '
            'Drop a folder to start from it.',
            style: TextStyle(color: c.onSurfaceSubtle, fontSize: 12),
          ),
          const SizedBox(height: PvSpace.xl),
          _result(context),
        ],
      ),
    );
  }

  Widget _result(BuildContext context) {
    final error = controller.joinError;
    if (error != null) return ErrorBox(message: error);
    final joined = controller.joined;
    if (controller.fragments.isEmpty || joined == null) {
      return const EmptyHint(title: 'Add a fragment to see the joined path.');
    }
    return OutlinedCard(
      child: ResultRow(
        label: 'Joined',
        value: joined,
        valueSize: 17,
        onFocused: () => controller.focusValue(joined),
        trailing: [
          SizedBox.square(
            dimension: 40,
            child: IconButton(
              tooltip: 'Inspect joined path',
              padding: EdgeInsets.zero,
              iconSize: 18,
              color: ipColors(context).onSurfaceMuted,
              onPressed: joined.isEmpty
                  ? null
                  : () => controller.loadPath(joined),
              icon: const Icon(Icons.search),
            ),
          ),
        ],
      ),
    );
  }
}

class _FragmentChip extends StatelessWidget {
  const _FragmentChip({super.key, required this.text, required this.onRemove});

  final String text;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = ipColors(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: PvSpace.md + 2, right: 3),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        border: Border.all(color: c.outline),
        borderRadius: BorderRadius.circular(PvRadius.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ipMono(context),
            ),
          ),
          const SizedBox(width: PvSpace.xs),
          SizedBox.square(
            dimension: 38,
            child: IconButton(
              tooltip: 'Remove $text',
              padding: EdgeInsets.zero,
              iconSize: 16,
              color: c.onSurfaceSubtle,
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}
