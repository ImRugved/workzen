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
import '../models/newsletter_model.dart';
import '../providers/company_info_provider.dart';
import 'rich_text_view.dart';

// The newsletter: company news (visits, milestones, achievements, updates).
//
// - [NewsletterCard]: one post in full (picture, date, title, text).
// - [NewsletterSummaryCard]: the small card on the admin Info page.
// - [NewsletterSection]: the card on the employee Info page (latest posts).

/// One newsletter post. An editor also sees whether it is hidden and gets a
/// button to hide or show it (nothing is deleted).
class NewsletterCard extends StatelessWidget {
  final NewsletterModel post;
  final bool canEdit;

  const NewsletterCard({super.key, required this.post, this.canEdit = false});

  Future<void> _toggle(BuildContext context) async {
    final saved = await context.read<CompanyInfoProvider>().setNewsletterActive(
      post.id,
      !post.isActive,
    );
    if (!saved) ConstantSnackbar.showError(title: 'Failed to change');
  }

  @override
  Widget build(BuildContext context) {
    final image = post.imageUrl;
    final date = post.eventDate ?? post.createdAt;

    return Opacity(
      opacity: post.isActive ? 1 : 0.6,
      child: NeuCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image != null)
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(NeuStyle.radiusMedium.r),
                ),
                child: CachedNetworkImage(
                  imageUrl: image,
                  width: double.infinity,
                  height: 180.h,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => SizedBox(
                    height: 180.h,
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
              ),
            Padding(
              padding: EdgeInsets.all(14.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.event_outlined,
                        size: 14.r,
                        color: ConstColors.textColorLight,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        DateFormat('dd MMM yyyy').format(date),
                        style: getTextTheme().labelSmall?.copyWith(
                          color: ConstColors.textColorLight,
                        ),
                      ),
                      const Spacer(),
                      if (canEdit && !post.isActive)
                        Text(
                          'Hidden',
                          style: getTextTheme().labelSmall?.copyWith(
                            color: ConstColors.inProgressOrange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    post.title,
                    style: getTextTheme().titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: ConstColors.textColor,
                    ),
                  ),
                  if (post.bodyJson != null) ...[
                    SizedBox(height: 8.h),
                    RichTextView(contentJson: post.bodyJson!),
                  ],
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          post.postedBy.isEmpty
                              ? ''
                              : 'Posted by ${post.postedBy}',
                          style: getTextTheme().labelSmall?.copyWith(
                            color: ConstColors.textColorLight,
                          ),
                        ),
                      ),
                      if (canEdit)
                        TextButton.icon(
                          onPressed: () => _toggle(context),
                          icon: Icon(
                            post.isActive
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18.r,
                          ),
                          label: Text(post.isActive ? 'Hide' : 'Show'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Admin Info page: how many posts there are and the latest one, in one
/// tappable card. Tapping opens [onTap], the Newsletter screen (read, and post
/// or hide).
class NewsletterSummaryCard extends StatelessWidget {
  final VoidCallback onTap;

  const NewsletterSummaryCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        child: Consumer<CompanyInfoProvider>(
          builder: (context, info, _) {
            final shown = info.newsletter.where((p) => p.isActive).toList();
            final hidden = info.newsletter.length - shown.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.newspaper_outlined,
                      color: ConstColors.primary,
                      size: 22.r,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Newsletter',
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
                if (!info.newsletterLoaded)
                  Text(
                    'Loading...',
                    style: getTextTheme().bodySmall?.copyWith(
                      color: ConstColors.textColorLight,
                    ),
                  )
                else if (info.newsletter.isEmpty)
                  Text(
                    'Nothing posted yet. Tap to share company news, a visit '
                    'or a milestone.',
                    style: getTextTheme().bodySmall?.copyWith(
                      color: ConstColors.textColorLight,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${shown.length}',
                        style: getTextTheme().headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ConstColors.primaryDeep,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Padding(
                        padding: EdgeInsets.only(bottom: 4.h),
                        child: Text(
                          'posts',
                          style: getTextTheme().bodyMedium?.copyWith(
                            color: ConstColors.textColorLight,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (hidden > 0)
                        Padding(
                          padding: EdgeInsets.only(bottom: 4.h),
                          child: Text(
                            '$hidden hidden',
                            style: getTextTheme().bodySmall?.copyWith(
                              color: ConstColors.textColorLight,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (shown.isNotEmpty) ...[
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Text(
                          'Latest:',
                          style: getTextTheme().bodySmall?.copyWith(
                            color: ConstColors.textColorLight,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            shown.first.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: getTextTheme().bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Employee Info page: the latest posts as short rows (picture, category,
/// title, date). Tapping opens [onTap], the Newsletter screen with everything.
class NewsletterSection extends StatelessWidget {
  final VoidCallback onTap;

  /// How many posts are listed here.
  static const int _shown = 3;

  const NewsletterSection({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        child: Consumer<CompanyInfoProvider>(
          builder: (context, info, _) {
            final posts = info.newsletter.where((p) => p.isActive).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.newspaper_outlined,
                      color: ConstColors.primary,
                      size: 22.r,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Newsletter',
                        style: getTextTheme().titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      'See all',
                      style: getTextTheme().labelMedium?.copyWith(
                        color: ConstColors.primaryDeep,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: ConstColors.primaryDeep,
                      size: 20.r,
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                if (!info.newsletterLoaded)
                  Text(
                    'Loading...',
                    style: getTextTheme().bodySmall?.copyWith(
                      color: ConstColors.textColorLight,
                    ),
                  )
                else if (posts.isEmpty)
                  Text(
                    'No company news yet',
                    style: getTextTheme().bodySmall?.copyWith(
                      color: ConstColors.textColorLight,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  for (final post in posts.take(_shown))
                    _PostRow(post: post),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PostRow extends StatelessWidget {
  final NewsletterModel post;

  const _PostRow({required this.post});

  @override
  Widget build(BuildContext context) {
    final image = post.imageUrl;
    final date = post.eventDate ?? post.createdAt;

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: image == null
                ? Container(
                    width: 52.r,
                    height: 52.r,
                    color: ConstColors.primary.withValues(alpha: 0.3),
                    child: const Icon(
                      Icons.newspaper_outlined,
                      color: ConstColors.primaryDeep,
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: image,
                    width: 52.r,
                    height: 52.r,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      width: 52.r,
                      height: 52.r,
                      color: ConstColors.lightShade,
                    ),
                  ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: getTextTheme().bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(date),
                  style: getTextTheme().labelSmall?.copyWith(
                    color: ConstColors.textColorLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
