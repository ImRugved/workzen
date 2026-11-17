import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_button.dart';
import '../constants/constant_colors.dart';
import '../constants/constant_dropdown.dart';
import '../constants/constant_snackbar.dart';
import '../models/past_request_entry.dart';

// Value of a picked day that is a full day (the others are the two halves)
const String _fullDay = 'Full Day';

// Choices being made in the form. Scoped to the form.
class _MonthDraft with ChangeNotifier {
  PastRequestKind kind = PastRequestKind.cl;

  /// First day of the chosen month, or null.
  DateTime? month;

  /// The picked days of the month: day number -> full day or which half.
  final Map<int, String> picked = {};

  /// Days left of PL / SL / CL in the chosen month's year; null while loading
  /// or when the employee has no leave document for that year (then no type
  /// is hidden).
  Map<PastRequestKind, num>? balances;

  void setBalances(Map<PastRequestKind, num>? value) {
    balances = value;
    notifyListeners();
  }

  void setKind(PastRequestKind value) {
    kind = value;
    // Work from home has no half day
    if (!kind.supportsHalfDay) picked.updateAll((_, _) => _fullDay);
    notifyListeners();
  }

  void setMonth(DateTime value) {
    month = value;
    picked.clear();
    notifyListeners();
  }

  void toggle(int day) {
    if (picked.containsKey(day)) {
      picked.remove(day);
    } else {
      picked[day] = _fullDay;
    }
    notifyListeners();
  }

  void setMode(int day, String mode) {
    picked[day] = mode;
    notifyListeners();
  }

  void clearPicked() {
    picked.clear();
    notifyListeners();
  }
}

/// The form of Update Leaves for adding leave month by month: pick a month, a
/// type, then tap the days of that month the employee was away. Each picked day
/// can be a full day or a first / second half. "Add" turns the picked days into
/// records (days next to each other that are full days become one record); the
/// month stays chosen, so the type can be changed and more days added.
class MonthLeaveForm extends StatefulWidget {
  /// Earliest month that can be chosen (the joining month).
  final DateTime firstDate;

  /// Records already added and not saved, so their days are marked taken.
  final List<PastRequestEntry> existing;
  final ValueChanged<List<PastRequestEntry>> onAdd;

  /// Days left of PL / SL / CL of the employee in a year, or null when there is
  /// no leave document for that year. A type with none left is not offered.
  final Future<Map<PastRequestKind, num>?> Function(int year) loadBalances;

  const MonthLeaveForm({
    super.key,
    required this.firstDate,
    required this.existing,
    required this.onAdd,
    required this.loadBalances,
  });

  @override
  State<MonthLeaveForm> createState() => _MonthLeaveFormState();
}

class _MonthLeaveFormState extends State<MonthLeaveForm> {
  final _MonthDraft _draft = _MonthDraft();
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _draft.dispose();
    _reason.dispose();
    super.dispose();
  }

  static Color _kindColor(PastRequestKind kind) {
    switch (kind) {
      case PastRequestKind.pl:
        return ConstColors.primary;
      case PastRequestKind.sl:
        return ConstColors.successGreen;
      case PastRequestKind.cl:
        return ConstColors.inProgressOrange;
      case PastRequestKind.ul:
        return ConstColors.calendarUnpaidLeave;
      case PastRequestKind.co:
      case PastRequestKind.compOff:
        return ConstColors.calendarCompOff;
      case PastRequestKind.wfh:
        return ConstColors.calendarWfh;
    }
  }

  // Balances already loaded, by year (null = no document for that year)
  final Map<int, Map<PastRequestKind, num>?> _balanceCache = {};

  Future<void> _onMonthChosen(DateTime month) async {
    _draft.setMonth(month);
    final year = month.year;
    if (!_balanceCache.containsKey(year)) {
      _draft.setBalances(null);
      _balanceCache[year] = await widget.loadBalances(year);
    }
    // Only if the month was not changed to another year meanwhile
    if (!mounted || _draft.month?.year != year) return;
    _draft.setBalances(_balanceCache[year]);
  }

  // Days of a type already taken by the records added in this form, in a year
  num _heldByAdded(PastRequestKind kind, int year) => widget.existing
      .where((e) => e.kind == kind && e.from.year == year)
      .fold<num>(0, (sum, e) => sum + e.days);

  // Days left of a type for the chosen month, or null when not limited
  num? _left(PastRequestKind kind) {
    final month = _draft.month;
    final balances = _draft.balances;
    if (month == null || balances == null) return null;
    if (kind != PastRequestKind.pl &&
        kind != PastRequestKind.sl &&
        kind != PastRequestKind.cl) {
      return null;
    }
    final left = (balances[kind] ?? 0) - _heldByAdded(kind, month.year);
    return left < 0 ? 0 : left;
  }

  // The types to offer: PL, SL and CL only while some days are left (so once
  // they are used up only Unpaid Leave, comp off and WFH remain)
  List<PastRequestKind> _kinds() => [
    for (final k in PastRequestKind.values)
      if (k != PastRequestKind.compOff && (_left(k) ?? 1) > 0) k,
  ];

  // The chosen type, or the first offered one when it is no longer offered
  PastRequestKind _kind() {
    final kinds = _kinds();
    return kinds.contains(_draft.kind) ? _draft.kind : kinds.first;
  }

  // The months that can be chosen: this month back to the joining month
  List<DateTime> _months() {
    final now = DateTime.now();
    final first = DateTime(widget.firstDate.year, widget.firstDate.month);
    final months = <DateTime>[];
    var month = DateTime(now.year, now.month);
    while (!month.isBefore(first)) {
      months.add(month);
      month = DateTime(month.year, month.month - 1);
    }
    return months;
  }

  // Days of [month] that a record added earlier already covers
  Set<int> _takenDays(DateTime month) {
    final taken = <int>{};
    for (final entry in widget.existing) {
      if (!entry.kind.isLeave && entry.kind != PastRequestKind.wfh) continue;
      var day = DateTime(entry.from.year, entry.from.month, entry.from.day);
      final last = DateTime(entry.to.year, entry.to.month, entry.to.day);
      while (!day.isAfter(last)) {
        if (day.year == month.year && day.month == month.month) {
          taken.add(day.day);
        }
        day = day.add(const Duration(days: 1));
      }
    }
    return taken;
  }

  // The picked days as records: a half day is one record, and full days that
  // follow each other are one record
  List<PastRequestEntry> _buildEntries(DateTime month) {
    final kind = _kind();
    final days = _draft.picked.keys.toList()..sort();
    final reason = _reason.text.trim();
    final entries = <PastRequestEntry>[];
    DateTime date(int d) => DateTime(month.year, month.month, d);

    var i = 0;
    while (i < days.length) {
      final day = days[i];
      final mode = _draft.picked[day]!;
      if (mode != _fullDay) {
        entries.add(
          PastRequestEntry(
            id: const Uuid().v4(),
            kind: kind,
            isHalfDay: true,
            half: mode,
            from: date(day),
            to: date(day),
            reason: reason,
          ),
        );
        i++;
        continue;
      }
      // Extend over the full days that follow
      var end = i;
      while (end + 1 < days.length &&
          days[end + 1] == days[end] + 1 &&
          _draft.picked[days[end + 1]] == _fullDay) {
        end++;
      }
      entries.add(
        PastRequestEntry(
          id: const Uuid().v4(),
          kind: kind,
          isHalfDay: false,
          from: date(day),
          to: date(days[end]),
          reason: reason,
        ),
      );
      i = end + 1;
    }
    return entries;
  }

  void _add() {
    final month = _draft.month;
    if (month == null) {
      ConstantSnackbar.showError(title: 'Select the month');
      return;
    }
    if (_draft.picked.isEmpty) {
      ConstantSnackbar.showError(title: 'Select the days');
      return;
    }
    widget.onAdd(_buildEntries(month));
    // The month and type stay, so more days can be added
    _draft.clearPicked();
    _reason.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _draft,
      child: Consumer<_MonthDraft>(
        builder: (context, draft, _) {
          final month = draft.month;
          final kinds = _kinds();
          final kind = _kind();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstantDropdown<DateTime>(
                label: 'Month',
                hint: 'Select month',
                value: month,
                items: _months(),
                itemLabel: (m) => DateFormat('MMMM yyyy').format(m),
                onChanged: (m) {
                  if (m != null) _onMonthChosen(m);
                },
              ),
              SizedBox(height: 12.h),
              ConstantDropdown<PastRequestKind>(
                label: 'Type',
                value: kind,
                // PL, SL and CL show only while days are left; Unpaid Leave
                // is always there. Comp off credit earned on a day off is not
                // added here.
                items: kinds,
                itemLabel: (k) {
                  final left = _left(k);
                  return left == null
                      ? k.label
                      : '${k.label} • ${left % 1 == 0 ? left.toInt() : left} left';
                },
                onChanged: (k) {
                  if (k != null) draft.setKind(k);
                },
              ),
              if (month != null) ...[
                SizedBox(height: 14.h),
                Text(
                  'Tap the days of ${DateFormat('MMMM').format(month)}',
                  style: getTextTheme().bodySmall?.copyWith(
                    color: ConstColors.textColorLight,
                  ),
                ),
                SizedBox(height: 8.h),
                _MonthGrid(
                  month: month,
                  color: _kindColor(kind),
                  picked: draft.picked.keys.toSet(),
                  taken: _takenDays(month),
                  onTap: draft.toggle,
                ),
                if (draft.picked.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  _PickedDays(month: month, draft: draft, kind: kind),
                ],
              ],
              SizedBox(height: 12.h),
              TextField(
                controller: _reason,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                ),
              ),
              SizedBox(height: 16.h),
              SizedBox(
                width: double.infinity,
                child: ConstantButton(
                  text: draft.picked.isEmpty
                      ? 'Add'
                      : 'Add ${draft.picked.length} '
                            '${draft.picked.length == 1 ? 'day' : 'days'}',
                  backgroundColor: ConstColors.primary,
                  onPressed: _add,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// The days of a month as a grid under the weekday letters; a tap picks or
// drops a day. Days after today and days a record already covers can not be
// picked.
class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final Color color;
  final Set<int> picked;
  final Set<int> taken;
  final ValueChanged<int> onTap;

  const _MonthGrid({
    required this.month,
    required this.color,
    required this.picked,
    required this.taken,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday first: DateTime.weekday is 1 for Monday
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday - 1;
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    return Column(
      children: [
        Row(
          children: [
            for (final letter in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Center(
                  child: Text(
                    letter,
                    style: getTextTheme().labelSmall?.copyWith(
                      color: ConstColors.textColorLight,
                    ),
                  ),
                ),
              ),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemCount: leadingBlanks + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();
            final day = index - leadingBlanks + 1;
            final isFuture = DateTime(
              month.year,
              month.month,
              day,
            ).isAfter(todayDay);
            final isTaken = taken.contains(day);
            final isPicked = picked.contains(day);
            final enabled = !isFuture && !isTaken;

            return GestureDetector(
              onTap: enabled ? () => onTap(day) : null,
              child: Container(
                margin: EdgeInsets.all(3.r),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPicked
                      ? color
                      : isTaken
                      ? ConstColors.borderColor
                      : Colors.transparent,
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: getTextTheme().bodyMedium?.copyWith(
                      color: isPicked
                          ? Colors.white
                          : enabled
                          ? ConstColors.textColor
                          : ConstColors.textColorLight,
                      fontWeight: isPicked ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// The picked days with a choice of full day or half for each, and the total
class _PickedDays extends StatelessWidget {
  final DateTime month;
  final _MonthDraft draft;

  final PastRequestKind kind;

  const _PickedDays({
    required this.month,
    required this.draft,
    required this.kind,
  });

  @override
  Widget build(BuildContext context) {
    final days = draft.picked.keys.toList()..sort();
    final total = draft.picked.values.fold<double>(
      0,
      (sum, mode) => sum + (mode == _fullDay ? 1 : 0.5),
    );
    final canHalf = kind.supportsHalfDay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selected: ${total % 1 == 0 ? total.toInt() : total} '
          '${total == 1 ? 'day' : 'days'}',
          style: getTextTheme().bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: ConstColors.textColor,
          ),
        ),
        SizedBox(height: 6.h),
        for (final day in days)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 3.h),
            child: Row(
              children: [
                SizedBox(
                  width: 84.w,
                  child: Text(
                    DateFormat(
                      'EEE, d MMM',
                    ).format(DateTime(month.year, month.month, day)),
                    style: getTextTheme().bodySmall,
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 6.w,
                    children: [
                      for (final mode in canHalf
                          ? const [
                              _fullDay,
                              PastRequestEntry.firstHalf,
                              PastRequestEntry.secondHalf,
                            ]
                          : const [_fullDay])
                        ChoiceChip(
                          label: Text(
                            mode == _fullDay
                                ? 'Full'
                                : mode == PastRequestEntry.firstHalf
                                ? '1st half'
                                : '2nd half',
                            style: getTextTheme().labelSmall,
                          ),
                          selected: draft.picked[day] == mode,
                          onSelected: (_) => draft.setMode(day, mode),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
