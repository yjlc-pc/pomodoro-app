import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Locales whose date symbols the app formats with.
///
/// `intl` keeps its locale tables in a separate, lazily-populated map: asking
/// for a `DateFormat` with a locale that was never passed to
/// [initializeDateFormatting] throws `LocaleDataException` at runtime rather
/// than at build time. Loading them once up front is the only fix.
const List<String> supportedDateLocales = <String>['zh_CN'];

const String _locale = 'zh_CN';

/// Loads the date symbols for [supportedDateLocales].
///
/// Must be awaited before the first [fullDateFormat] / [weekdayFormat] is
/// read. Safe to call more than once.
Future<void> ensureDateFormatting() async {
  for (final locale in supportedDateLocales) {
    await initializeDateFormatting(locale);
  }
}

DateFormat? _fullDate;
DateFormat? _weekday;

/// Cached `yyyy年M月d日` formatter, e.g. 「2026年10月17日」.
///
/// Cached because building a [DateFormat] parses its pattern every time, and
/// these are read from `build` methods.
DateFormat get fullDateFormat => _fullDate ??= DateFormat('yyyy年M月d日', _locale);

/// Cached `EEEE` formatter, e.g. 「星期六」.
DateFormat get weekdayFormat => _weekday ??= DateFormat('EEEE', _locale);