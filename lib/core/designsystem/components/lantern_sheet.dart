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
    constraints: const BoxConstraints(maxWidth: 640),
    backgroundColor: t.surface,
    showDragHandle: true,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(LanternSpace.radius),
      ),
    ),
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      final maxHeight = (media.size.height * 0.88 - media.viewInsets.bottom)
          .clamp(280.0, media.size.height)
          .toDouble();
      return AnimatedPadding(
        duration: LanternMotion.resolve(ctx, LanternMotion.fast),
        curve: LanternMotion.emphasized,
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                LanternSpace.md,
                0,
                LanternSpace.md,
                LanternSpace.md,
              ),
              child: builder(ctx),
            ),
          ),
        ),
      );
    },
  );
}
