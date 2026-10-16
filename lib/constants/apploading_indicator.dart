import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'constant_colors.dart';

/// Loading animation styles available from `flutter_spinkit`.
enum AppLoadingType {
  chasingDots,
  circle,
  cubeGrid,
  dancingSquare,
  doubleBounce,
  dualRing,
  fadingCircle,
  fadingCube,
  fadingFour,
  fadingGrid,
  foldingCube,
  hourGlass,
  pianoWave,
  pouringHourGlass,
  pouringHourGlassRefined,
  pulse,
  pulsingGrid,
  pumpingHeart,
  ring,
  ripple,
  rotatingCircle,
  rotatingPlain,
  spinningCircle,
  spinningLines,
  squareCircle,
  threeBounce,
  threeInOut,
  wanderingCubes,
  wave,
  waveSpinner,
}

/// The app's one loading spinner. Use it everywhere instead of a bare
/// CircularProgressIndicator. Pass a [color] (defaults to the app primary)
/// and a [size]; the size is scaled with screenutil (`.r`).
class AppLoadingIndicator extends StatelessWidget {
  final AppLoadingType type;
  final Color? color;
  final double size;

  const AppLoadingIndicator({
    super.key,
    this.type = AppLoadingType.fadingCircle,
    this.color,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final Color tint = color ?? ConstColors.primary;
    final double scaledSize = size.r;

    switch (type) {
      case AppLoadingType.chasingDots:
        return SpinKitChasingDots(color: tint, size: scaledSize);
      case AppLoadingType.circle:
        return SpinKitCircle(color: tint, size: scaledSize);
      case AppLoadingType.cubeGrid:
        return SpinKitCubeGrid(color: tint, size: scaledSize);
      case AppLoadingType.dancingSquare:
        return SpinKitDancingSquare(color: tint, size: scaledSize);
      case AppLoadingType.doubleBounce:
        return SpinKitDoubleBounce(color: tint, size: scaledSize);
      case AppLoadingType.dualRing:
        return SpinKitDualRing(color: tint, size: scaledSize);
      case AppLoadingType.fadingCircle:
        return SpinKitFadingCircle(color: tint, size: scaledSize);
      case AppLoadingType.fadingCube:
        return SpinKitFadingCube(color: tint, size: scaledSize);
      case AppLoadingType.fadingFour:
        return SpinKitFadingFour(color: tint, size: scaledSize);
      case AppLoadingType.fadingGrid:
        return SpinKitFadingGrid(color: tint, size: scaledSize);
      case AppLoadingType.foldingCube:
        return SpinKitFoldingCube(color: tint, size: scaledSize);
      case AppLoadingType.hourGlass:
        return SpinKitHourGlass(color: tint, size: scaledSize);
      case AppLoadingType.pianoWave:
        return SpinKitPianoWave(color: tint, size: scaledSize);
      case AppLoadingType.pouringHourGlass:
        return SpinKitPouringHourGlass(color: tint, size: scaledSize);
      case AppLoadingType.pouringHourGlassRefined:
        return SpinKitPouringHourGlassRefined(color: tint, size: scaledSize);
      case AppLoadingType.pulse:
        return SpinKitPulse(color: tint, size: scaledSize);
      case AppLoadingType.pulsingGrid:
        return SpinKitPulsingGrid(color: tint, size: scaledSize);
      case AppLoadingType.pumpingHeart:
        return SpinKitPumpingHeart(color: tint, size: scaledSize);
      case AppLoadingType.ring:
        return SpinKitRing(color: tint, size: scaledSize);
      case AppLoadingType.ripple:
        return SpinKitRipple(color: tint, size: scaledSize);
      case AppLoadingType.rotatingCircle:
        return SpinKitRotatingCircle(color: tint, size: scaledSize);
      case AppLoadingType.rotatingPlain:
        return SpinKitRotatingPlain(color: tint, size: scaledSize);
      case AppLoadingType.spinningCircle:
        return SpinKitSpinningCircle(color: tint, size: scaledSize);
      case AppLoadingType.spinningLines:
        return SpinKitSpinningLines(color: tint, size: scaledSize);
      case AppLoadingType.squareCircle:
        return SpinKitSquareCircle(color: tint, size: scaledSize);
      case AppLoadingType.threeBounce:
        // threeBounce needs ~24 logical px; the fading circle stays readable
        // at the small sizes used inside buttons
        return SpinKitFadingCircle(color: tint, size: scaledSize);
      case AppLoadingType.threeInOut:
        return SpinKitThreeInOut(color: tint, size: scaledSize);
      case AppLoadingType.wanderingCubes:
        return SpinKitWanderingCubes(color: tint, size: scaledSize);
      case AppLoadingType.wave:
        return SpinKitWave(color: tint, size: scaledSize);
      case AppLoadingType.waveSpinner:
        return SpinKitWaveSpinner(color: tint, size: scaledSize);
    }
  }
}
