import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/constant_colors.dart';

class DotIndicator extends StatelessWidget {
  final int itemCount;
  final int currentIndex;

  const DotIndicator({
    super.key,
    required this.itemCount,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        itemCount,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          width: currentIndex == index ? 10.w : 8.w,
          height: 5.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4.r),
            color: currentIndex == index
                ? ConstColors.primary
                : ConstColors.primary.withOpacity(0.3),
          ),
        ),
      ),
    );
  }
}

