part of 'expanding_draggable_sheet.dart';

class _ExpandingSliver extends SingleChildRenderObjectWidget {
  final double baseHeight;
  final double targetHeight;
  final Color color;
  final BorderRadius? borderRadius;
  final SheetSnapBehavior snapBehavior;
  final ScrollController parentScrollController;
  final double scrollableScrollOffset;
  final ValueChanged<double> updateHeaderAnimationPosition;

  const _ExpandingSliver({
    required this.baseHeight,
    required this.targetHeight,
    this.color = Colors.transparent,
    this.borderRadius,
    required this.snapBehavior,
    required this.parentScrollController,
    required this.scrollableScrollOffset,
    required this.updateHeaderAnimationPosition,
    super.child,
  });

  @override
  _RenderExpandingSliver createRenderObject(BuildContext context) {
    return _RenderExpandingSliver(
      baseHeight: baseHeight,
      targetHeight: targetHeight,
      color: color,
      borderRadius: borderRadius,
      snapBehavior: snapBehavior,
      scrollableScrollOffset: scrollableScrollOffset,
      parentScrollController: parentScrollController,
      updateHeaderAnimationPosition: updateHeaderAnimationPosition,
      mediaQueryTopPadding: MediaQuery.paddingOf(context).top,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context,
      _RenderExpandingSliver renderObject,
      ) {
    renderObject.scrollableScrollOffset = scrollableScrollOffset;
  }
}

class _RenderExpandingSliver extends RenderSliverSingleBoxAdapter {
  final double baseHeight;
  final double targetHeight;
  final Color color;
  final BorderRadius? borderRadius;
  final SheetSnapBehavior snapBehavior;
  final ScrollController parentScrollController;
  final ValueChanged<double> updateHeaderAnimationPosition;
  final double mediaQueryTopPadding;

  _RenderExpandingSliver({
    required this.baseHeight,
    required this.targetHeight,
    this.color = Colors.transparent,
    this.borderRadius,
    required this.snapBehavior,
    required double scrollableScrollOffset,
    required this.parentScrollController,
    required this.updateHeaderAnimationPosition,
    required this.mediaQueryTopPadding,
  }) : _scrollableScrollOffset = scrollableScrollOffset;

  double _animationPosition = 0;

  // Whether _snapTransform has been registered as a listener for the parent
  // scrollable's isScrollingNotifier.
  bool _listeningForSnap = false;

  // Whether the parent scrollable is currently snapping.
  bool _snapping = false;

  double get _expandedHeight => targetHeight; //+ baseHeight;

  // Distance until sliver hits area to start transforming.
  double get _extentToTransform =>
      constraints.precedingScrollExtent -
          _scrollableScrollOffset -
          _expandedHeight;

  late double _previousHeight = baseHeight;
  double? _heightAdjustment;

  double _scrollableScrollOffset;

  set scrollableScrollOffset(double value) {
    if (_scrollableScrollOffset == value) return;
    _scrollableScrollOffset = value;
    // No change to size so no rebuild necessary.
    if (_extentToTransform > 0 && _previousHeight == baseHeight) return;
    markNeedsLayout();
  }

  void _snapTransform() {
    final double snapStartOffset;
    switch (snapBehavior) {
      case SheetSnapBehavior.start:
        snapStartOffset = 0;
      case SheetSnapBehavior.midpoint:
        snapStartOffset = (_expandedHeight - mediaQueryTopPadding) / 2;
      case SheetSnapBehavior.end:
        snapStartOffset = _expandedHeight - mediaQueryTopPadding;
      case SheetSnapBehavior.none:
        return;
    }

    // Don't snap if the sheet is scrolling or currently snapping.
    if (parentScrollController.position.isScrollingNotifier.value ||
        _snapping) {
      return;
    }
    // Don't snap if the user has started scrolling the sheet content.
    if (_scrollableScrollOffset > constraints.precedingScrollExtent) return;

    final bool snapForward = _extentToTransform.abs() > snapStartOffset;
    final snapTargetOffset =
        constraints.precedingScrollExtent - (snapForward ? 0 : _expandedHeight);

    _snapping = true;
    parentScrollController
        .animateTo(
      snapTargetOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutQuad,
    )
        .then((_) {
      _snapping = false;
      // This is not true of the user interrupts the snap animation.
      if (parentScrollController.offset == snapTargetOffset) {
        // Explicitly update the animation position to the appropriate bound.
        // Because the sliver introduces scroll offset corrections, it's
        // possible that the animation position will be slightly different than
        // the relevant bound of zero or one, which will causes errors in the
        // management of the app bar overlay ability to accept gestures.
        updateHeaderAnimationPosition(snapForward ? 1 : 0);
      }
    });
  }

  @override
  void performLayout() {
    _animationPosition =
        (-1 * _extentToTransform / _expandedHeight).clamp(0, 1);
    updateHeaderAnimationPosition(_animationPosition);
    final scrollNotifier = parentScrollController.position.isScrollingNotifier;

    if (_animationPosition > 0 && !_listeningForSnap) {
      scrollNotifier.addListener(_snapTransform);
      _listeningForSnap = true;
    } else if (_animationPosition <= 0 && _listeningForSnap) {
      scrollNotifier.removeListener(_snapTransform);
      _listeningForSnap = false;
    }

    double interpolatedHeight =
    lerpDouble(baseHeight, _expandedHeight, _animationPosition)!;
    interpolatedHeight =
        min(interpolatedHeight, constraints.viewportMainAxisExtent);

    double layoutExtent = interpolatedHeight - constraints.scrollOffset;
    layoutExtent =
        clampDouble(layoutExtent, 0, constraints.remainingPaintExtent);

    // The space between the top of this sliver and the top of the viewport.
    final remainingSpace =
        constraints.precedingScrollExtent - _scrollableScrollOffset;
    _heightAdjustment = interpolatedHeight - _previousHeight;
    _heightAdjustment = min(_heightAdjustment!, max(remainingSpace, 0));
    _previousHeight = interpolatedHeight;

    geometry = SliverGeometry(
      scrollExtent: interpolatedHeight,
      paintExtent: interpolatedHeight,
      maxPaintExtent: interpolatedHeight,
      layoutExtent: layoutExtent,
      scrollOffsetCorrection: _heightAdjustment == 0 ? null : _heightAdjustment,
    );

    child?.layout(constraints.asBoxConstraints(maxExtent: baseHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Rect bounds =
    offset & Size(constraints.crossAxisExtent, geometry!.paintExtent);

    // Make the header transparent when covered by the app bar. If the sheet is
    // popped without being scrolled down, the header won't block sheet content.
    final color = _animationPosition == 1 ? Colors.transparent : this.color;
    final Paint paint = Paint()..color = color;

    final topLeftRadius = borderRadius?.topLeft ?? const Radius.circular(28);
    final topRightRadius = borderRadius?.topRight ?? const Radius.circular(28);
    final RRect rrect = RRect.fromRectAndCorners(
      bounds,
      topLeft: Radius.lerp(topLeftRadius, Radius.zero, _animationPosition)!,
      topRight: Radius.lerp(topRightRadius, Radius.zero, _animationPosition)!,
    );

    context.canvas.drawRRect(rrect, paint);
    if (child != null) {
      context.paintChild(
        child!,
        Offset(0, offset.dy),
      );
    }
  }
}
