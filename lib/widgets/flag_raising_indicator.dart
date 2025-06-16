import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/flag_raising_provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math' as math;

/// Widget to display flag raising progress
class FlagRaisingIndicator extends ConsumerWidget {
  const FlagRaisingIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flagState = ref.watch(flagRaisingProvider);
    
    // Don't show anything if no flag is being raised
    if (!flagState.isRaisingFlag && !flagState.hasPlantedFlag && !flagState.isAtApex) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: ScreenUtil().statusBarHeight + 80.h,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 200.w,
          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: flagState.teamColor.withOpacity(0.7),
              width: 2.w,
            ),
          ),
          child: flagState.hasPlantedFlag
              ? _buildFlagPlantedContent(flagState)
              : flagState.isRaisingFlag
                  ? _buildFlagRaisingContent(flagState)
                  : _buildReadyToRaiseContent(flagState),
        ),
      ),
    );
  }

  Widget _buildFlagRaisingContent(FlagRaisingState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flag,
              color: state.teamColor,
              size: 16.sp,
            ),
            SizedBox(width: 6.w),
            Text(
              '${state.teamName} Captain Raising Flag',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4.r),
                child: LinearProgressIndicator(
                  value: state.flagRaiseProgress,
                  backgroundColor: Colors.grey.shade800,
                  valueColor: AlwaysStoppedAnimation<Color>(state.teamColor),
                  minHeight: 8.h,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              state.progressText,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Text(
          'Time remaining: ${state.timeRemaining}',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildFlagPlantedContent(FlagRaisingState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPulsingIcon(
          Icon(
            Icons.flag,
            color: state.teamColor,
            size: 18.sp,
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          '${state.teamName} Flag Planted!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(width: 8.w),
        _buildPulsingIcon(
          Icon(
            Icons.flag,
            color: state.teamColor,
            size: 18.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildReadyToRaiseContent(FlagRaisingState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.flag_outlined,
          color: state.teamColor,
          size: 16.sp,
        ),
        SizedBox(width: 6.w),
        Text(
          '${state.teamName} Captain at Apex',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(width: 6.w),
        Icon(
          Icons.touch_app,
          color: Colors.white70,
          size: 14.sp,
        ),
      ],
    );
  }

  Widget _buildPulsingIcon(Widget icon) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.8, end: 1.2),
      duration: const Duration(seconds: 1),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: icon,
      onEnd: () {},
    );
  }
}