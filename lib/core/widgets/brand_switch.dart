import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// 品牌开关：绿色仅作选中态，平台可识别形态。
class BrandSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const BrandSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Switch(
      value: value,
      onChanged: onChanged,
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return null;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return c.brand;
        return null;
      }),
    );
  }
}
