import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat('#,###', 'en_US');
  
  static String format(dynamic amount) {
    int value = amount is int ? amount : int.tryParse(amount.toString()) ?? 0;
    return 'Rp. ${_formatter.format(value)}';
  }
  
  static String formatNumber(dynamic amount) {
    int value = amount is int ? amount : int.tryParse(amount.toString()) ?? 0;
    return _formatter.format(value);
  }
  
  static String formatForInput(dynamic amount) {
    return formatNumber(amount);
  }
}