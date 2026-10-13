import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Copies [text] to the clipboard and confirms with a SnackBar showing
/// [message].
Future<void> copyToClipboard(
  BuildContext context,
  String text, {
  required String message,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  await Clipboard.setData(ClipboardData(text: text));
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
}
