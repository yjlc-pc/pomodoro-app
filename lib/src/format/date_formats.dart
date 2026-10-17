import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Locale the app formats dates in.
const String _locale = 'zh_CN';

bool _symbolsLoaded = false;

/// Loads intl's date symbols for the app's locale.
///
/// `intl` keeps its locale tables in a lazily-populated map and throws
/// `LocaleDataException` for any locale that was never loaded, so this has to
/// run before the first [DateFormat] is built. Despite the `Future` return
/// type, `initializeDateFormatting` does its work *synchronously* and then
/// returns `Future.value()` — which is why this can be called from a getter
/// rather than having to be awaited at some entry point. (Awaiting it in
/// `main()` looked correct but bought nothing, and left every other entry
/// point — most visibly widget tests — one forgotten call away from crashing.)
///
/// Safe to call repeatedly; the work happens once.
void ensureDateFormatting() {
  if (_symbolsLoaded) return;
  _symbolsLoaded = true;
  unawaited(initializeDateFormatting(_locale));
}

DateFormat? _fullDate;
DateFormat? _weekday;

/// Cached `yyyy年M月d日` formatter, e.g. 「2026年10月17日」.
///
/// Cached because building a [DateFormat] parses its pattern every time, and
/// these are read from `build` methods.
DateFormat get fullDateFormat {
  ensureDateFormatting();
  return _fullDate ??= DateFormat('yyyy年M月d日', _locale);
}

/// Cached `EEEE` formatter, e.g. 「星期六」.
DateFormat get weekdayFormat {
  ensureDateFormatting();
  return _weekday ??= DateFormat('EEEE', _locale);
}