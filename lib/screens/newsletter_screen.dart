import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../constants/apploading_indicator.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_colors.dart';
import '../constants/permissions.dart';
import '../providers/auth_provider.dart';
import '../providers/company_info_provider.dart';
import '../widgets/newsletter_widgets.dart';

/// All the newsletter posts, newest first. Everyone reads it; an admin, or a
/// sub admin with the company info permission, also sees hidden posts, can hide
/// or show a post, and gets the button to write a new one.
class NewsletterScreen extends StatefulWidget {
  const NewsletterScreen({super.key});

  @override
  State<NewsletterScreen> createState() => _NewsletterScreenState();
}

class _NewsletterScreenState extends State<NewsletterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyInfoProvider>().start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = context.select<AuthProvider, bool>(
      (auth) => auth.can(Permissions.companyInfo),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Newsletter',
          style: getTextTheme().titleLarge?.copyWith(
            color: ConstColors.textColor,
          ),
        ),
      ),
      backgroundColor: ConstColors.backgroundColor,
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => Get.toNamed('/newsletter_editor_screen'),
              icon: Icon(Icons.add, size: 20.r, color: ConstColors.textColor),
              label: Text(
                'Post',
                style: getTextTheme().labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ConstColors.textColor,
                ),
              ),
              backgroundColor: ConstColors.primary,
              foregroundColor: ConstColors.textColor,
            )
          : null,
      body: Consumer<CompanyInfoProvider>(
        builder: (context, info, _) {
          if (!info.newsletterLoaded) {
            return const Center(child: AppLoadingIndicator(size: 40));
          }

          // Readers see only the posts that are not hidden
          final posts = canEdit
              ? info.newsletter
              : info.newsletter.where((p) => p.isActive).toList();

          if (posts.isEmpty) {
            return Center(
              child: Text(
                'Nothing has been posted yet',
                style: getTextTheme().bodyMedium?.copyWith(
                  color: ConstColors.textColorLight,
                ),
              ),
            );
          }

          return ListView(
            padding: AppSpacing.screen,
            children: [
              for (final post in posts) ...[
                NewsletterCard(post: post, canEdit: canEdit),
                SizedBox(height: 14.h),
              ],
              // Room so the Post button never covers the last card
              SizedBox(height: 70.h),
            ],
          );
        },
      ),
    );
  }
}
