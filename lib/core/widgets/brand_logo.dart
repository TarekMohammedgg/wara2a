import 'package:flutter/material.dart';

import '../constants/app_images.dart';
import '../theme/app_colors.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 34 : 42,
          height: compact ? 34 : 42,
          padding: EdgeInsets.all(compact ? 6 : 7),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(compact ? 11 : 14),
          ),
          child: Image.asset(AppImages.wara2aLogo, fit: BoxFit.contain),
        ),
        if (!compact) ...[
          const SizedBox(width: 10),
          Text(
            'wara2a',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.navy,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ],
    );
  }
}
