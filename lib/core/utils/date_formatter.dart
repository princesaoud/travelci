import 'package:intl/intl.dart';

class DateFormatter {
  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy', 'fr').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('dd MMM yyyy à HH:mm', 'fr').format(date);
  }

  static String formatShortDate(DateTime date) {
    return DateFormat('dd/MM/yyyy', 'fr').format(date);
  }
}

