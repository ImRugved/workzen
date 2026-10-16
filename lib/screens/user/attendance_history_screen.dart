import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';

import '../../constants/apploading_indicator.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_colors.dart';
import '../../constants/constant_date_time_picker.dart';
import '../../constants/constant_dropdown.dart';
import '../../constants/constant_snackbar.dart';
import '../../providers/attendance_history_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/logger.dart';

// status key -> label, in the order shown by the filter chips
const Map<String, String> _statusLabels = {
  'present': 'Present',
  'late': 'Late',
  'halfDay': 'Half Day',
  'leave': 'Leave',
  'compOff': 'Comp Off',
  'absent': 'Absent',
  'wfh': 'WFH',
  'holiday': 'Holiday',
  'weekend': 'Weekly Off',
};

Color _statusColor(String status) {
  switch (status) {
    case 'present':
      return ConstColors.calendarPresent;
    case 'late':
      return ConstColors.calendarLate;
    case 'halfDay':
      return ConstColors.calendarHalfDay;
    case 'leave':
      return ConstColors.calendarLeave;
    case 'compOff':
      return ConstColors.calendarCompOff;
    case 'absent':
      return ConstColors.calendarAbsent;
    case 'wfh':
      return ConstColors.calendarWfh;
    case 'holiday':
      return ConstColors.calendarHoliday;
    case 'weekend':
      return ConstColors.calendarWeekend;
    default:
      return ConstColors.grey;
  }
}

String _time(DateTime? t) => t == null ? '-' : DateFormat('hh:mm a').format(t);

String _hours(Duration? d) =>
    d == null ? '-' : '${d.inHours}h ${d.inMinutes.remainder(60)}m';

/// Attendance history table. All state (range, filters, search, rows) lives in
/// [AttendanceHistoryProvider], scoped to this screen.
class AttendanceHistoryScreen extends StatelessWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().userModel;

    return ChangeNotifierProvider(
      create: (_) {
        final provider = AttendanceHistoryProvider();
        if (user != null) provider.load(user);
        return provider;
      },
      child: const _HistoryView(),
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView();

  Future<void> _pickRange(BuildContext context) async {
    final provider = context.read<AttendanceHistoryProvider>();
    final user = context.read<AuthProvider>().userModel;
    if (user == null) return;

    final picked = await ConstantDateRangePicker.pick(
      context,
      initialRange: DateTimeRange(start: provider.from, end: provider.to),
      // The earliest day to pick is the joining date
      firstDate: AttendanceHistoryProvider.joiningDateOf(user) ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    await provider.setRange(user, picked.start, picked.end);
  }

  Future<void> _exportPdf(BuildContext context) async {
    final provider = context.read<AttendanceHistoryProvider>();
    final rows = provider.visibleRows(_statusLabels);

    if (rows.isEmpty) {
      ConstantSnackbar.show(
        title: 'No attendance records to export',
        backgroundColor: Colors.orange,
      );
      return;
    }

    provider.setExporting(true);
    try {
      final name = context.read<AuthProvider>().userModel!.name;
      final dateFmt = DateFormat('dd MMM yyyy');

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (_) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Attendance Report',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Text(
              name,
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue700,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '${dateFmt.format(provider.from)} - ${dateFmt.format(provider.to)}',
            ),
            pw.SizedBox(height: 14),
            pw.TableHelper.fromTextArray(
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue300,
              ),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headers: [
                'Date',
                'Day',
                'Status',
                'In',
                'Out',
                'Hours',
                'Remarks',
              ],
              data: rows
                  .map(
                    (r) => [
                      dateFmt.format(r.date),
                      DateFormat('EEE').format(r.date),
                      _statusLabels[r.day.status] ?? r.day.status,
                      _time(r.day.punchIn),
                      _time(r.day.punchOut),
                      _hours(r.day.worked),
                      r.day.label,
                    ],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Summary',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            ..._statusLabels.entries.map(
              (e) => pw.Bullet(
                text:
                    '${e.value}: ${rows.where((r) => r.day.status == e.key).length}',
              ),
            ),
          ],
        ),
      );

      final dir = await getTemporaryDirectory();
      final fileName =
          'attendance_${name.replaceAll(' ', '_')}_${DateFormat('dd_MM_yyyy').format(DateTime.now())}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
      ConstantSnackbar.showSuccess(title: 'PDF generated successfully');
    } catch (e) {
      logDebug('Error generating PDF: $e');
      ConstantSnackbar.showError(title: 'Error generating PDF');
    } finally {
      provider.setExporting(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        actions: [
          // Only the export / loading flags drive the app bar buttons
          Selector<AttendanceHistoryProvider, bool>(
            selector: (_, p) => p.isExporting,
            builder: (context, isExporting, _) => IconButton(
              icon: isExporting
                  ? SizedBox(
                      width: 18.r,
                      height: 18.r,
                      child: const AppLoadingIndicator(
                        size: 18,
                        color: ConstColors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Export PDF',
              onPressed: isExporting ? null : () => _exportPdf(context),
            ),
          ),
          Selector<AttendanceHistoryProvider, bool>(
            selector: (_, p) => p.isLoading,
            builder: (context, isLoading, _) => IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: isLoading
                  ? null
                  : () {
                      final user = context.read<AuthProvider>().userModel;
                      if (user != null) {
                        context
                            .read<AttendanceHistoryProvider>()
                            .load(user, force: true);
                      }
                    },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _RangePicker(onTap: () => _pickRange(context)),
          const _SearchField(),
          const _StatusChips(),
          const Divider(height: 1),
          const Expanded(child: _HistoryBody()),
        ],
      ),
    );
  }
}

class _RangePicker extends StatelessWidget {
  final VoidCallback onTap;

  const _RangePicker({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(
            children: [
              Icon(Icons.date_range, size: 18.r, color: ConstColors.primary),
              SizedBox(width: 8.w),
              Expanded(
                child: Selector<AttendanceHistoryProvider, (DateTime, DateTime)>(
                  selector: (_, p) => (p.from, p.to),
                  builder: (context, range, _) => Text(
                    '${fmt.format(range.$1)}  -  ${fmt.format(range.$2)}',
                    style: getTextTheme().bodyMedium,
                  ),
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }
}

/// Owns the text controller (a lifecycle object); the search text itself is
/// kept in the provider.
class _SearchField extends StatefulWidget {
  const _SearchField();

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AttendanceHistoryProvider>();

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 4.h),
      child: TextField(
        controller: _controller,
        onChanged: provider.setSearch,
        decoration: InputDecoration(
          hintText: 'Search date, day, status or remark',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Selector<AttendanceHistoryProvider, bool>(
            selector: (_, p) => p.search.isNotEmpty,
            builder: (context, hasText, _) => hasText
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _controller.clear();
                      provider.setSearch('');
                    },
                  )
                : const SizedBox.shrink(),
          ),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
        ),
      ),
    );
  }
}

// Status filter dropdown; each entry shows how many days have that status
class _StatusChips extends StatelessWidget {
  const _StatusChips();

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceHistoryProvider>(
      builder: (context, provider, _) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: ConstantDropdown<String>(
          label: 'Status',
          isDense: true,
          value: provider.statusFilter,
          items: ['all', ..._statusLabels.keys],
          itemLabel: (key) => key == 'all'
              ? 'All (${provider.allRows.length})'
              : '${_statusLabels[key]} (${provider.count(key)})',
          itemBuilder: (key) {
            if (key == 'all') {
              return Text(
                'All (${provider.allRows.length})',
                style: getTextTheme().bodyMedium,
              );
            }
            return Row(
              children: [
                CircleAvatar(radius: 6.r, backgroundColor: _statusColor(key)),
                SizedBox(width: 8.w),
                Text(
                  '${_statusLabels[key]} (${provider.count(key)})',
                  style: getTextTheme().bodyMedium,
                ),
              ],
            );
          },
          onChanged: (value) {
            if (value != null) provider.setStatusFilter(value);
          },
        ),
      ),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody();

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceHistoryProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: AppLoadingIndicator(size: 40));
        }

        if (provider.hasError) {
          return Center(
            child: Text(
              'Failed to load attendance history',
              style: getTextTheme().bodyMedium?.copyWith(color: Colors.red),
            ),
          );
        }

        final rows = provider.visibleRows(_statusLabels);
        if (rows.isEmpty) {
          return Center(
            child: Text(
              provider.allRows.isEmpty
                  ? 'No attendance records for this period'
                  : 'No records match your filter',
              style: getTextTheme().bodyMedium?.copyWith(color: Colors.grey),
            ),
          );
        }

        return SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              sortColumnIndex: 0,
              sortAscending: provider.sortAscending,
              columnSpacing: 24.w,
              headingRowColor: WidgetStatePropertyAll(
                ConstColors.primary.withValues(alpha: 0.08),
              ),
              columns: [
                DataColumn(
                  label: const Text('Date'),
                  onSort: (_, ascending) => provider.setSortAscending(ascending),
                ),
                const DataColumn(label: Text('Day')),
                const DataColumn(label: Text('Status')),
                const DataColumn(label: Text('In')),
                const DataColumn(label: Text('Out')),
                const DataColumn(label: Text('Hours')),
                const DataColumn(label: Text('Remarks')),
              ],
              rows: rows.map(_buildDataRow).toList(),
            ),
          ),
        );
      },
    );
  }

  DataRow _buildDataRow(AttendanceHistoryRow row) {
    final color = _statusColor(row.day.status);

    return DataRow(
      cells: [
        DataCell(Text(DateFormat('dd MMM yyyy').format(row.date))),
        DataCell(Text(DateFormat('EEE').format(row.date))),
        DataCell(
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              border: Border.all(color: color),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              _statusLabels[row.day.status] ?? row.day.status,
              style: getTextTheme().labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        DataCell(Text(_time(row.day.punchIn))),
        DataCell(Text(_time(row.day.punchOut))),
        DataCell(Text(_hours(row.day.worked))),
        DataCell(
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 180.w),
            child: Text(
              row.day.label.isEmpty ? '-' : row.day.label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
