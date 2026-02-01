import 'package:flutter/services.dart';

/// Call at the start of any button onPressed to give haptic feedback.
void tapFeedback() {
  HapticFeedback.selectionClick();
}

/// Call for light impact (e.g. secondary actions).
void lightImpact() {
  HapticFeedback.lightImpact();
}
