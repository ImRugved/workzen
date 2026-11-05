import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/monthly_attendance_summary.dart';
import 'attendance_report_service.dart';

/// Writes an [AttendanceReport] to a PDF or an Excel file in the temporary
/// folder and returns the file. Both hold the same two parts: a summary (the
/// days of each status, hours and extra hours per employee, and the total) and
/// the day by day table.
class AttendanceExportService {
  static final DateFormat _date = DateFormat('dd MMM yyyy');
  static final DateFormat _time = DateFormat('hh:mm a');

  static String _duration(Duration? d) =>
      (d == null || d == Duration.zero)
      ? '-'
      : '${d.inHours}h ${d.inMinutes.remainder(60)}m';

  static String _period(AttendanceReport r) =>
      '${_date.format(r.from)} - ${_date.format(r.to)}';

  // "attendance_all_01Oct2026_30Oct2026"
  static String _baseName(AttendanceReport r, String suffix) {
    final who = r.isSingleEmployee
        ? r.totals.first.employee.name.replaceAll(RegExp(r'\s+'), '_')
        : 'all';
    final short = DateFormat('ddMMMyyyy');
    return 'attendance_${who}_${short.format(r.from)}_${short.format(r.to)}$suffix';
  }

  // Header of the per employee summary, shared by the PDF and the Excel file.
  // Working Days leaves out holidays and the weekly off (Saturday, Sunday);
  // Leave is the total of PL, SL, CL and UL (unpaid), which follow it; Comp Off is leave
  // taken from earned comp off.
  static List<String> _summaryHeaders() => [
    'Employee',
    'Emp ID',
    'Working Days',
    'Present',
    'Late',
    'Half Day',
    'Leave',
    'PL',
    'SL',
    'CL',
    'UL',
    'Comp Off',
    'Absent',
    'WFH',
    'Holiday',
    'Weekly Off',
    'Break',
    'Hours',
    'Extra Hrs',
  ];

  static List<String> _summaryRow(EmployeeAttendanceTotals t) => [
    t.employee.name,
    t.employee.employeeId ?? '-',
    '${t.workingDays}',
    '${t.count('present')}',
    '${t.count('late')}',
    '${t.count('halfDay')}',
    '${t.count('leave')}',
    '${t.leaveOf('pl')}',
    '${t.leaveOf('sl')}',
    '${t.leaveOf('cl')}',
    '${t.leaveOf('ul')}',
    '${t.count('compOff')}',
    '${t.count('absent')}',
    '${t.count('wfh')}',
    '${t.count('holiday')}',
    '${t.count('weekend')}',
    _duration(t.breaks),
    _duration(t.worked),
    _duration(t.extra),
  ];

  static List<String> _totalRow(AttendanceReport r) => [
    'Total',
    '',
    '${r.overallWorkingDays}',
    '${r.overallCount('present')}',
    '${r.overallCount('late')}',
    '${r.overallCount('halfDay')}',
    '${r.overallCount('leave')}',
    '${r.overallLeaveOf('pl')}',
    '${r.overallLeaveOf('sl')}',
    '${r.overallLeaveOf('cl')}',
    '${r.overallLeaveOf('ul')}',
    '${r.overallCount('compOff')}',
    '${r.overallCount('absent')}',
    '${r.overallCount('wfh')}',
    '${r.overallCount('holiday')}',
    '${r.overallCount('weekend')}',
    _duration(r.overallBreaks),
    _duration(r.overallWorked),
    _duration(r.overallExtra),
  ];

  // The status as shown in the table: a leave says which leave it is, "Leave
  // (PL)", and so does a half day taken as leave, "Half Day (SL)"
  static String _statusText(DaySummary day) {
    final base = attendanceStatusLabels[day.status] ?? day.status;
    final code = day.leaveType;
    if (code == null) return base;
    if (day.status == 'leave' || day.status == 'halfDay') {
      return '$base (${code.toUpperCase()})';
    }
    return base;
  }

  static List<String> _detailHeaders(bool withEmployee) => [
    if (withEmployee) 'Employee',
    'Date',
    'Day',
    'Status',
    'In',
    'Out',
    'Break',
    'Hours',
    'Extra Hrs',
    'Remarks',
  ];

  static List<String> _detailRow(AttendanceReportRow row, bool withEmployee) {
    final day = row.day;
    return [
      if (withEmployee) row.employee.name,
      _date.format(row.date),
      DateFormat('EEE').format(row.date),
      _statusText(day),
      day.shownPunchIn == null ? '-' : _time.format(day.shownPunchIn!),
      day.shownPunchOut == null ? '-' : _time.format(day.shownPunchOut!),
      _duration(day.shownBreak),
      _duration(day.worked),
      _duration(day.shownExtra),
      day.label.isEmpty ? '-' : day.label,
    ];
  }

  // --- PDF ---

  Future<File> toPdf(AttendanceReport report) async {
    final withEmployee = !report.isSingleEmployee;
    final pdf = pw.Document();

    pw.Widget table({
      required List<String> headers,
      required List<List<String>> data,
      double fontSize = 8,
      List<int> leftAligned = const [0],
    }) {
      return pw.TableHelper.fromTextArray(
        headers: headers,
        data: data,
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blue300),
        headerStyle: pw.TextStyle(
          color: PdfColors.white,
          fontSize: fontSize,
          fontWeight: pw.FontWeight.bold,
        ),
        cellStyle: pw.TextStyle(fontSize: fontSize),
        cellAlignment: pw.Alignment.center,
        cellAlignments: {
          for (final i in leftAligned) i: pw.Alignment.centerLeft,
        },
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        build: (_) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Attendance Report',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(
            'Period: ${_period(report)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Employees: ${report.employeeLabel}'),
          pw.SizedBox(height: 14),

          pw.Text(
            'Summary',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          table(
            headers: _summaryHeaders(),
            data: [
              for (final t in report.totals) _summaryRow(t),
              if (report.totals.length > 1) _totalRow(report),
            ],
            // 19 columns: a smaller font keeps them on one page width
            fontSize: 7,
            leftAligned: const [0],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Days counted: ${report.totalDays}. Working Days leave out '
            'holidays and the weekly off (Saturday, Sunday). Leave is the '
            'total of PL, SL, CL and UL (unpaid); Comp Off is leave taken from earned comp '
            'off. Hours are worked time after breaks; Extra Hrs is time worked '
            'after the office end time.',
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 18),

          pw.Text(
            'Attendance',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          table(
            headers: _detailHeaders(withEmployee),
            data: [for (final row in report.rows) _detailRow(row, withEmployee)],
            fontSize: 8,
            leftAligned: withEmployee ? const [0, 9] : const [8],
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_baseName(report, '.pdf')}');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // --- Excel ---

  Future<File> toExcel(AttendanceReport report) async {
    final withEmployee = !report.isSingleEmployee;
    final excel = Excel.createExcel();

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#8DBFF5'),
    );
    final boldStyle = CellStyle(bold: true);

    // Writes a row of texts, styling every cell when [style] is given
    void writeRow(
      Sheet sheet,
      int rowIndex,
      List<String> values, {
      CellStyle? style,
    }) {
      for (var c = 0; c < values.length; c++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex),
        );
        // Counts are written as numbers so they can be summed in the sheet
        final number = int.tryParse(values[c]);
        cell.value = number != null && values[c].isNotEmpty
            ? IntCellValue(number)
            : TextCellValue(values[c]);
        if (style != null) cell.cellStyle = style;
      }
    }

    // Sheet 1: summary
    excel.rename('Sheet1', 'Summary');
    final summary = excel['Summary'];
    writeRow(summary, 0, ['Attendance Report'], style: boldStyle);
    writeRow(summary, 1, ['Period', _period(report)]);
    writeRow(summary, 2, ['Employees', report.employeeLabel]);
    writeRow(summary, 3, ['Days counted', '${report.totalDays}']);
    writeRow(summary, 5, _summaryHeaders(), style: headerStyle);
    var rowIndex = 6;
    for (final t in report.totals) {
      writeRow(summary, rowIndex++, _summaryRow(t));
    }
    if (report.totals.length > 1) {
      writeRow(summary, rowIndex, _totalRow(report), style: boldStyle);
    }
    summary.setColumnWidth(0, 24);

    // Sheet 2: day by day
    final detail = excel['Attendance'];
    writeRow(detail, 0, _detailHeaders(withEmployee), style: headerStyle);
    for (var i = 0; i < report.rows.length; i++) {
      writeRow(detail, i + 1, _detailRow(report.rows[i], withEmployee));
    }
    for (var c = 0; c < _detailHeaders(withEmployee).length; c++) {
      detail.setColumnWidth(c, c == 0 && withEmployee ? 24 : 14);
    }

    final bytes = excel.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_baseName(report, '.xlsx')}');
    await file.writeAsBytes(bytes ?? const []);
    return file;
  }
}
