import 'package:flutter/material.dart';

import '../constants/app_images.dart';
import '../../l10n/app_localizations.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 116.0 : 154.0;
    final height = compact ? 34.0 : 44.0;
    return Semantics(
      label: AppLocalizations.of(context).appName,
      image: true,
      child: SizedBox(
        width: width,
        height: height,
        child: Image.asset(
          AppImages.wara2aLogo,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
