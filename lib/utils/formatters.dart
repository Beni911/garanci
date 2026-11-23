import 'package:intl/intl.dart';

String formatHungarianDate(DateTime date) =>
    DateFormat.yMMMMd('hu').format(date);

String formatForint(double amount) =>
    '${NumberFormat.decimalPattern('hu_HU').format(amount)} Ft';
