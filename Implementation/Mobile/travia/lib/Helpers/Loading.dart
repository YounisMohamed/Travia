import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:travia/Helpers/AppColors.dart';

class LoadingWidget extends StatelessWidget {
  final double size;
  final List<Color>? colors;

  const LoadingWidget({
    super.key,
    this.size = 20,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    const Color defaultColor1 = kDeepPinkLight;
    const Color defaultColor2 = kDeepPink;
    const Color defaultColor3 = kDeepPink;
    final Color color1 = (colors != null && colors!.isNotEmpty) ? colors![0] : defaultColor1;
    final Color color2 = (colors != null && colors!.length > 1) ? colors![1] : defaultColor2;
    final Color color3 = (colors != null && colors!.length > 2) ? colors![2] : defaultColor3;

    return Center(
      child: LoadingAnimationWidget.discreteCircle(
        size: size,
        color: color1,
        secondRingColor: color2,
        thirdRingColor: color3,
      ),
    );
  }
}
