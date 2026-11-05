import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../constants/constant_button.dart';
import '../constants/constant_colors.dart';
import '../constants/constant_date_time_picker.dart';
import '../constants/constant_dropdown.dart';
import '../constants/constant_snackbar.dart';
import '../models/past_request_entry.dart';

// Choices being made in the form. Scoped to the form.
class _FormDraft with ChangeNotifier {
  PastRequestKind kind;
  bool isHalfDay;
  String half;
  DateTime? from;
  // Null means the same day as [from]
  DateTime? to;
  DateTime? compOffDate;

  _FormDraft({
    required this.kind,
    required this.isHalfDay,
    required this.half,
    this.from,
    this.to,
    this.compOffDate,
  });

  void setKind(PastRequestKind value) {
    kind = value;
    // Work from home has no half day
    if (!kind.supportsHalfDay) isHalfDay = false;
    notifyListeners();
  }

  void setHalfDay(bool value) {
    isHalfDay = value;
    notifyListeners();
  }

  void setHalf(String value) {
    half = value;
    notifyListeners();
  }

  void setFrom(DateTime value) {
    from = value;
    notifyListeners();
  }

  void setTo(DateTime value) {
    to = value;
    notifyListeners();
  }

  void setCompOffDate(DateTime value) {
    compOffDate = value;
    notifyListeners();
  }
}

/// The form HR fills for one past record: the type, a full or half day, the
/// dates (the end date follows the start date until another one is picked) and
/// an optional reason. Used to add a record and, with [initial], to edit one.
class PastRequestForm extends StatefulWidget {
  final PastRequestEntry? initial;
  final String submitLabel;

  /// Earliest date that can be picked (the employee's joining date).
  final DateTime firstDate;
  final ValueChanged<PastRequestEntry> onSubmit;

  const PastRequestForm({
    super.key,
    required this.submitLabel,
    required this.firstDate,
    required this.onSubmit,
    this.initial,
  });

  @override
  State<PastRequestForm> createState() => _PastRequestFormState();
}

class _PastRequestFormState extends State<PastRequestForm> {
  late final _FormDraft _draft;
  late final TextEditingController _reason;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _draft = _FormDraft(
      kind: initial?.kind ?? PastRequestKind.cl,
      isHalfDay: initial?.isHalfDay ?? false,
      half: initial?.half ?? PastRequestEntry.firstHalf,
      from: initial?.from,
      to: initial == null || initial.isSingleDay ? null : initial.to,
      compOffDate: initial?.compOffDate,
    );
    _reason = TextEditingController(text: initial?.reason ?? '');
  }

  @override
  void dispose() {
    _draft.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final from = _draft.from;
    if (from == null) {
      ConstantSnackbar.showError(
        title: _draft.kind == PastRequestKind.compOff
            ? 'Select the day worked'
            : 'Select the date',
      );
      return;
    }

    if (_draft.kind == PastRequestKind.compOff) {
      final off = _draft.compOffDate;
      if (off == null) {
        ConstantSnackbar.showError(title: 'Select the comp off date');
        return;
      }
      widget.onSubmit(
        PastRequestEntry(
          id: widget.initial?.id ?? const Uuid().v4(),
          kind: _draft.kind,
          isHalfDay: _draft.isHalfDay,
          from: from,
          to: from,
          compOffDate: off,
          reason: _reason.text.trim(),
        ),
      );
      return;
    }

    // One day unless another end date was picked; a half day is always one
    // day. If the two dates come in the wrong order they are swapped, so no
    // date is refused.
    final picked = _draft.isHalfDay ? from : (_draft.to ?? from);
    final start = picked.isBefore(from) ? picked : from;
    final end = picked.isBefore(from) ? from : picked;
    widget.onSubmit(
      PastRequestEntry(
        id: widget.initial?.id ?? const Uuid().v4(),
        kind: _draft.kind,
        isHalfDay: _draft.isHalfDay,
        half: _draft.isHalfDay ? _draft.half : null,
        from: start,
        to: end,
        reason: _reason.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Any date can be picked, past years included: HR may be adding old leave
    final lastDate = DateTime(2100);

    return ChangeNotifierProvider.value(
      value: _draft,
      child: Consumer<_FormDraft>(
        builder: (context, draft, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstantDropdown<PastRequestKind>(
              label: 'Type',
              value: draft.kind,
              // One comp off choice: "Comp Off Leave". The "worked on a day
              // off" record gave the same result (earned and used at once, the
              // balance unchanged), so it is no longer offered.
              items: [
                for (final kind in PastRequestKind.values)
                  if (kind != PastRequestKind.compOff) kind,
              ],
              itemLabel: (kind) => kind.label,
              onChanged: (kind) {
                if (kind != null) draft.setKind(kind);
              },
            ),
            if (draft.kind.supportsHalfDay) ...[
              SizedBox(height: 12.h),
              ConstantDropdown<bool>(
                label: 'Day',
                value: draft.isHalfDay,
                items: const [false, true],
                itemLabel: (half) => half ? 'Half day' : 'Full day',
                onChanged: (half) {
                  if (half != null) draft.setHalfDay(half);
                },
              ),
            ],
            SizedBox(height: 12.h),
            ..._dateFields(draft, lastDate),
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
                text: widget.submitLabel,
                backgroundColor: ConstColors.primary,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // The date fields that fit the type and the full or half day
  List<Widget> _dateFields(_FormDraft draft, DateTime lastDate) {
    // Comp off: the day worked and the day off taken in return
    if (draft.kind == PastRequestKind.compOff) {
      return [
        ConstantDatePicker(
          label: 'Worked on',
          value: draft.from,
          firstDate: widget.firstDate,
          lastDate: lastDate,
          onChanged: draft.setFrom,
        ),
        SizedBox(height: 12.h),
        ConstantDatePicker(
          label: 'Comp off taken on',
          value: draft.compOffDate,
          firstDate: widget.firstDate,
          lastDate: lastDate,
          onChanged: draft.setCompOffDate,
        ),
      ];
    }

    // Half day: one date, and which half
    if (draft.isHalfDay) {
      return [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: ConstantDatePicker(
                label: 'Date',
                value: draft.from,
                firstDate: widget.firstDate,
                lastDate: lastDate,
                onChanged: draft.setFrom,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              flex: 2,
              child: ConstantDropdown<String>(
                label: 'Half',
                value: draft.half,
                items: const [
                  PastRequestEntry.firstHalf,
                  PastRequestEntry.secondHalf,
                ],
                itemLabel: (half) => half == PastRequestEntry.secondHalf
                    ? 'Second half'
                    : 'First half',
                onChanged: (half) {
                  if (half != null) draft.setHalf(half);
                },
              ),
            ),
          ],
        ),
      ];
    }

    // Full days: from and to; "to" shows the same day until another is picked
    final from = draft.from;
    return [
      Row(
        children: [
          Expanded(
            child: ConstantDatePicker(
              label: 'From date',
              value: from,
              firstDate: widget.firstDate,
              lastDate: lastDate,
              onChanged: draft.setFrom,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: ConstantDatePicker(
              label: 'To date',
              value: draft.to ?? from,
              hint: 'Select date',
              firstDate: widget.firstDate,
              lastDate: lastDate,
              isEnabled: from != null,
              onChanged: draft.setTo,
            ),
          ),
        ],
      ),
    ];
  }
}
