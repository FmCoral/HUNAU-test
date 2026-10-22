import 'package:flutter/material.dart';
import '../../../core/utils/l10n_extension.dart';

class CampusBusMapScreen extends StatelessWidget {
  const CampusBusMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.funcCampusBusRoute),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return InteractiveViewer(
            minScale: 0.8,
            maxScale: 6.0,
            // 严格限制最大平移范围，防止地图被拖出屏幕视野
            boundaryMargin: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 32,
            ),
            child: Center(
              child: Image.asset(
                'assets/images/campus_bus_map.webp',
                width: constraints.maxWidth,
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
