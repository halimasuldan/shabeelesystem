import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/asset_paths.dart';

class SchoolBrand extends StatelessWidget {
  final bool compact;
  final bool light;
  final bool showName;

  const SchoolBrand({
    super.key,
    this.compact = false,
    this.light = false,
    this.showName = true,
  });

  /// Resolves the school logo, always falling back to the bundled asset and
  /// finally to an icon so the brand is never invisible.
  Widget _buildLogo(String? logoUrl) {
    final size = compact ? 32.0 : 44.0;

    Widget fallbackAsset() => Image.asset(
      AssetPaths.logo,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.school, color: Colors.white, size: compact ? 19 : 26),
    );

    final Widget child = (logoUrl == null || logoUrl.isEmpty)
        ? fallbackAsset()
        : Image.network(
            logoUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallbackAsset(),
            loadingBuilder: (context, widget, progress) =>
                progress == null ? widget : fallbackAsset(),
          );

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: light ? Colors.white24 : AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final foreground = light ? Colors.white : AppColors.primaryDark;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.colSchoolInfo)
          .doc('main')
          .snapshots(),
      builder: (context, snapshot) {
        final logoUrl = snapshot.data?.data()?['logoUrl'] as String?;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLogo(logoUrl),
            if (showName) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  AppConstants.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: compact ? 13 : 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
