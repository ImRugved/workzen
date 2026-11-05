import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../constants/apploading_indicator.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_colors.dart';
import '../constants/constant_snackbar.dart';
import '../models/announcement_model.dart';
import '../providers/company_info_provider.dart';
import 'company_info_forms.dart';
import 'rich_text_view.dart';

// What the admin publishes on the Info page. The same cards are used on the
// admin page ([canEdit] true: add, edit and delete controls) and on the
// employee page (read-only). They read [CompanyInfoProvider].

/// Heading row of a card: icon, title and, for an editor, an add button.
class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onAdd;
  final String addLabel;

  const _CardHeader({
    required this.icon,
    required this.title,
    required this.addLabel,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: ConstColors.primary, size: 22.r),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            title,
            style: getTextTheme().titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (onAdd != null)
          TextButton.icon(
            onPressed: onAdd,
            icon: Icon(Icons.add, size: 18.r, color: ConstColors.primaryDeep),
            label: Text(
              addLabel,
              style: getTextTheme().labelMedium?.copyWith(
                color: ConstColors.primaryDeep,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

Widget _muted(String text) => Text(
  text,
  style: getTextTheme().bodySmall?.copyWith(
    color: ConstColors.textColorLight,
    fontStyle: FontStyle.italic,
  ),
);

// --- Announcements ---

class AnnouncementsSection extends StatelessWidget {
  final bool canEdit;

  const AnnouncementsSection({super.key, this.canEdit = false});

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        child: Consumer<CompanyInfoProvider>(
          builder: (context, info, _) {
            // An editor sees all of them (active, inactive, expired); everyone
            // else sees only the ones that are active right now
            final now = DateTime.now();
            final items = canEdit
                ? info.announcements
                : info.announcements.where((a) => a.isShownAt(now)).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardHeader(
                  icon: Icons.campaign_outlined,
                  title: 'Announcements',
                  addLabel: 'Post',
                  onAdd: canEdit
                      ? () => CompanyInfoForms.addAnnouncement(context)
                      : null,
                ),
                SizedBox(height: 10.h),
                if (!info.announcementsLoaded)
                  _muted('Loading...')
                else if (items.isEmpty)
                  _muted(
                    canEdit ? 'No announcements yet' : 'No announcements now',
                  )
                else
                  for (final item in items)
                    AnnouncementTile(announcement: item, canEdit: canEdit),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Admin Info page: how the announcements stand, in one tappable card. Shows
/// how many are active now, how many are inactive or expired, when the latest
/// was posted and when the next active one ends. Tapping opens [onTap], the
/// Announcements screen with all of them.
class AnnouncementsSummaryCard extends StatelessWidget {
  final VoidCallback onTap;

  const AnnouncementsSummaryCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        child: Consumer<CompanyInfoProvider>(
          builder: (context, info, _) {
            final now = DateTime.now();
            final all = info.announcements;
            final active = all
                .where((a) => a.statusAt(now) == AnnouncementStatus.active)
                .toList();
            final inactive = all
                .where((a) => a.statusAt(now) == AnnouncementStatus.inactive)
                .length;
            final expired = all
                .where((a) => a.statusAt(now) == AnnouncementStatus.expired)
                .length;

            // The active one that ends first
            final ending =
                active.map((a) => a.endsAt).whereType<DateTime>().toList()
                  ..sort();
            final format = DateFormat('dd MMM, hh:mm a');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.campaign_outlined,
                      color: ConstColors.primary,
                      size: 22.r,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Announcements',
                        style: getTextTheme().titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: ConstColors.textColorLight,
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                if (!info.announcementsLoaded)
                  _muted('Loading...')
                else if (all.isEmpty)
                  _muted('No announcements yet. Tap to post one.')
                else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${active.length}',
                        style: getTextTheme().headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ConstColors.successGreen,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Padding(
                        padding: EdgeInsets.only(bottom: 4.h),
                        child: Text(
                          'active now',
                          style: getTextTheme().bodyMedium?.copyWith(
                            color: ConstColors.textColorLight,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: EdgeInsets.only(bottom: 4.h),
                        child: Text(
                          '$inactive inactive • $expired expired',
                          style: getTextTheme().bodySmall?.copyWith(
                            color: ConstColors.textColorLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Latest posted ${format.format(all.first.createdAt)}',
                    style: getTextTheme().labelSmall?.copyWith(
                      color: ConstColors.textColorLight,
                    ),
                  ),
                  if (ending.isNotEmpty)
                    Text(
                      'Next one ends ${format.format(ending.first)}',
                      style: getTextTheme().labelSmall?.copyWith(
                        color: ConstColors.textColorLight,
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One announcement as a card: picture, title, message, who posted it and when,
/// its end time and, for an editor, its state and the buttons to change it.
class AnnouncementTile extends StatelessWidget {
  final AnnouncementModel announcement;
  final bool canEdit;

  /// Shows the Active / Inactive / Expired tag. An editor always sees it; the
  /// Notifications screen asks for it so an expired card is marked.
  final bool showStatus;

  const AnnouncementTile({
    super.key,
    required this.announcement,
    required this.canEdit,
    this.showStatus = false,
  });

  // Switches it off or on by hand; nothing is deleted
  Future<void> _toggleActive(BuildContext context, bool makeActive) async {
    final saved = await context
        .read<CompanyInfoProvider>()
        .setAnnouncementActive(announcement.id, makeActive);
    if (!saved) ConstantSnackbar.showError(title: 'Failed to change');
  }

  @override
  Widget build(BuildContext context) {
    final image = announcement.imageUrl;
    final status = announcement.statusAt(DateTime.now());
    final ends = announcement.endsAt;
    return Opacity(
      // An inactive or expired one is dimmed so the live ones stand out
      opacity: status == AnnouncementStatus.active ? 1 : 0.65,
      child: _tileBody(context, image, status, ends),
    );
  }

  Widget _tileBody(
    BuildContext context,
    String? image,
    AnnouncementStatus status,
    DateTime? ends,
  ) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: ConstColors.lightShade.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: ConstColors.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (image != null)
            CachedNetworkImage(
              imageUrl: image,
              width: double.infinity,
              height: 170.h,
              fit: BoxFit.cover,
              placeholder: (context, url) => SizedBox(
                height: 170.h,
                child: const Center(child: AppLoadingIndicator(size: 30)),
              ),
              errorWidget: (context, url, error) => SizedBox(
                height: 80.h,
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: ConstColors.textColorLight,
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(12.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        announcement.title,
                        style: getTextTheme().titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ConstColors.textColor,
                        ),
                      ),
                    ),
                    // An editor needs to know the state; so does a reader of
                    // the Notifications screen (to see an expired one)
                    if (canEdit || showStatus) _StatusChip(status: status),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(announcement.message, style: getTextTheme().bodyMedium),
                SizedBox(height: 8.h),
                Text(
                  '${announcement.postedBy.isEmpty ? '' : '${announcement.postedBy} • '}'
                  '${DateFormat('dd MMM yyyy, hh:mm a').format(announcement.createdAt)}',
                  style: getTextTheme().labelSmall?.copyWith(
                    color: ConstColors.textColorLight,
                  ),
                ),
                if (ends != null)
                  Text(
                    status == AnnouncementStatus.expired
                        ? 'Ended ${DateFormat('dd MMM yyyy, hh:mm a').format(ends)}'
                        : 'Until ${DateFormat('dd MMM yyyy, hh:mm a').format(ends)}',
                    style: getTextTheme().labelSmall?.copyWith(
                      color: ConstColors.textColorLight,
                    ),
                  ),
                if (canEdit) ...[
                  SizedBox(height: 6.h),
                  Wrap(
                    spacing: 4.w,
                    children: [
                      // Switch on or off by hand (an expired one is extended)
                      if (status != AnnouncementStatus.expired)
                        TextButton.icon(
                          onPressed: () => _toggleActive(
                            context,
                            status == AnnouncementStatus.inactive,
                          ),
                          icon: Icon(
                            status == AnnouncementStatus.inactive
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18.r,
                          ),
                          label: Text(
                            status == AnnouncementStatus.inactive
                                ? 'Make active'
                                : 'Make inactive',
                          ),
                        ),
                      TextButton.icon(
                        onPressed: () => CompanyInfoForms.extendAnnouncement(
                          context,
                          announcement,
                        ),
                        icon: Icon(Icons.schedule, size: 18.r),
                        label: const Text('Change end time'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Active" / "Inactive" / "Expired" tag of an announcement.
class _StatusChip extends StatelessWidget {
  final AnnouncementStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AnnouncementStatus.active => ('Active', ConstColors.successGreen),
      AnnouncementStatus.inactive => ('Inactive', ConstColors.textColorLight),
      AnnouncementStatus.expired => ('Expired', ConstColors.inProgressOrange),
    };
    return Container(
      margin: EdgeInsets.only(left: 8.w),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Text(
        label,
        style: getTextTheme().labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// The employee of the month widgets live in employee_of_month_widgets.dart.

// --- Company rules ---

/// The company rules as one formatted document, exactly as the admin wrote or
/// pasted it (bold, italic, headings, lists...). [onEdit] is given only to an
/// editor: it adds an Add / Edit button that opens the Company Rules screen.
/// Nobody edits or deletes a rule from here.
class CompanyRulesSection extends StatelessWidget {
  final VoidCallback? onEdit;

  const CompanyRulesSection({super.key, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        child: Consumer<CompanyInfoProvider>(
          builder: (context, info, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(
                icon: Icons.gavel_outlined,
                title: 'Company Rules',
                addLabel: info.rules.isEmpty ? 'Add' : 'Edit',
                onAdd: onEdit,
              ),
              SizedBox(height: 10.h),
              if (!info.rulesLoaded)
                _muted('Loading...')
              else if (info.rules.isEmpty)
                _muted('Company rules have not been added yet')
              else
                RichTextView(contentJson: info.rules.contentJson!),
            ],
          ),
        ),
      ),
    );
  }
}
