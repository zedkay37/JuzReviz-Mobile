import 'package:flutter/material.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';

/// Bottom sheet thémé Lanterne.
Future<T?> showLanternSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  final t = context.lantern;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: t.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(LanternSpace.radius)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(LanternSpace.md),
        child: builder(ctx),
      ),
    ),
  );
}
