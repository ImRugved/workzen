import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../app_constants.dart';
import '../constants/app_theme.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_colors.dart';
import '../models/birthday_model.dart';
import '../providers/auth_provider.dart';
import '../providers/organization_provider.dart';

/// A banner for today's birthdays on the home screens. It wishes the signed-in
/// user directly on their own birthday and otherwise lists whose birthday it
/// is. It takes no space when nobody has a birthday today.
class BirthdayBanner extends StatefulWidget {
  const BirthdayBanner({super.key});

  @override
  State<BirthdayBanner> createState() => _BirthdayBannerState();
}

class _BirthdayBannerState extends State<BirthdayBanner> {
  late final Stream<List<BirthdayModel>> _stream = context
      .read<OrganizationProvider>()
      .todaysBirthdaysStream();

  @override
  Widget build(BuildContext context) {
    final myId = context.read<AuthProvider>().user?.uid;

    return StreamBuilder<List<BirthdayModel>>(
      stream: _stream,
      builder: (context, snapshot) {
        final birthdays = snapshot.data ?? const <BirthdayModel>[];
        if (birthdays.isEmpty) return const SizedBox.shrink();

        final mine = birthdays.any((b) => b.userId == myId);
        final others = birthdays.where((b) => b.userId != myId).toList();

        // Your own birthday wishes you; someone else's names them and asks you
        // to wish them, worded by their gender
        final String title;
        final String subtitle;
        if (mine) {
          title = 'Happy Birthday!';
          subtitle = others.isEmpty
              ? 'Wishing you a wonderful year ahead'
              : 'Also today: ${_names(others)}';
        } else if (others.length == 1) {
          title = "Today is ${others.first.name}'s Birthday";
          subtitle = 'Wish ${_pronoun(others.first.gender)} a happy birthday!';
        } else {
          title = 'Birthdays today';
          subtitle = '${_names(others)}. Wish them a happy birthday!';
        }

        return Padding(
          padding: EdgeInsets.only(bottom: 16.h),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: ConstColors.secondary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(NeuStyle.radiusMedium.r),
              border: Border.all(
                color: ConstColors.secondary.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44.r,
                  height: 44.r,
                  decoration: const BoxDecoration(
                    color: ConstColors.cardBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cake_outlined,
                    size: 24.r,
                    color: ConstColors.inProgressOrange,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: getTextTheme().titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ConstColors.textColor,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: getTextTheme().bodySmall?.copyWith(
                          color: ConstColors.textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.celebration_outlined,
                  size: 22.r,
                  color: ConstColors.inProgressOrange,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // The object pronoun for a gender: him, her, or them when unknown / other
  String _pronoun(String? gender) {
    switch (gender) {
      case AppConstants.genderMale:
        return 'him';
      case AppConstants.genderFemale:
        return 'her';
      default:
        return 'them';
    }
  }

  // "A, B and C", or "A, B and 2 more" past three names
  String _names(List<BirthdayModel> people) {
    final names = people.map((p) => p.name).toList();
    if (names.length == 1) return names.first;
    if (names.length <= 3) {
      return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
    }
    return '${names.take(3).join(', ')} and ${names.length - 3} more';
  }
}
