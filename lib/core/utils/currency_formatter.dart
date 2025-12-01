import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String formatXOF(int amount) {
    final formatter = NumberFormat.currency(
      locale: 'fr_CI',
      symbol: 'XOF',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  static String formatXOFCompact(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M XOF';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K XOF';
    }
    return '$amount XOF';
  }
}

