import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static String kcal(double value) => '${value.round().toString()} kcal';

  static String grams(double value) {
    if (value >= 100) return '${value.round()} g';
    if (value == value.roundToDouble()) return '${value.round()} g';
    return '${value.toStringAsFixed(1)} g';
  }

  static String weight(double value) => '${value.toStringAsFixed(1)} kg';

  static String meters(double value) => '${value.toStringAsFixed(2)} m';

  static String cm(double value) => '${value.toStringAsFixed(1)} cm';

  static String ml(double value) => '${value.round()} ml';

  static String liters(double value) => '${value.toStringAsFixed(2)} L';

  static String percent(double value) => '${value.round()}%';

  static String dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  static String dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Ontem';
    if (diff == -1) return 'Amanhã';
    return DateFormat('EEEE, dd/MM').format(d);
  }

  static String shortDay(DateTime d) => DateFormat('dd MMM').format(d);

  static String time(DateTime d) => DateFormat('HH:mm').format(d);

  static String dateShort(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
}