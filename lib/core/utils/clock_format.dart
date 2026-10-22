import 'package:flutter/material.dart';

/// Minutes after midnight rendered in the DEVICE's 12/24-hour preference.
///
/// `showTimePicker` already honours that preference, so anything that displays
/// a picked time has to as well — otherwise a user picks "5:00 PM" and the app
/// reads it back as "17:00". Storage and the wire keep the 24-hour form
/// (`RuleSchedule.formatHHmm`); this is display only.
///
/// A 12-hour clock drops a zero minute ("11 PM", "7:30 AM"); a 24-hour one
/// keeps it ("23:00").
String formatLocalTime(BuildContext context, int minutesAfterMidnight) {
  final t = TimeOfDay(
    hour: minutesAfterMidnight ~/ 60,
    minute: minutesAfterMidnight % 60,
  );
  final text = t.format(context);
  final format = MaterialLocalizations.of(context).timeOfDayFormat(
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return t.minute == 0 && hourFormat(of: format) == HourFormat.h
      ? text.replaceFirst(':00', '')
      : text;
}

/// Curried form, for the `TimeFormat` callbacks the rule summaries take.
String Function(int) localTimeFormat(BuildContext context) =>
    (m) => formatLocalTime(context, m);
