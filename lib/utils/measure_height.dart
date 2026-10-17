import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Reports its child's height whenever layout changes it
class MeasureHeight extends SingleChildRenderObjectWidget {
  const MeasureHeight(
      {super.key, required this.onChange, required super.child});

  final ValueChanged<double> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderMeasureHeight(onChange);

  @override
  void updateRenderObject(
          BuildContext context, RenderMeasureHeight renderObject) =>
      renderObject.onChange = onChange;
}

class RenderMeasureHeight extends RenderProxyBox {
  RenderMeasureHeight(this.onChange);

  ValueChanged<double> onChange;
  double? _last;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _last) return;
    _last = height;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(height));
  }
}
