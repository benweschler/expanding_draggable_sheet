import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

class ExpandingDraggableSheet extends StatefulWidget {
  /// The initial fractional value of the screen's height to use when displaying
  /// the modal sheet.
  ///
  /// The default value is `0.5`.
  final double initialChildSize;

  /// The minimum fractional value of the screen's height to use when displaying
  /// the modal sheet.
  ///
  /// The default value is `0.25`.
  final double minimumChildSize;

  /// The unexpanded height of the expanding header at the top of the sheet.
  final double headerHeight;

  /// An optional child to display in the expanding header. The child is faded
  /// out when the header expands.
  final Widget? headerChild;

  /// The [BorderRadius] of the top corners of the sheet. Only top left and top
  /// right radii will be used.
  ///
  /// The maximum allowed radius is equal to the [headerHeight]. Larger
  /// radii will fall back on this value.
  ///
  /// The default is a circular radius of `28`, which is the default radius for
  /// a Material Design modal sheet.
  final BorderRadius? sheetBorderRadius;

  /// The background color of the modal sheet.
  ///
  /// Defaults to null and falls back to the default Material Design modal
  /// bottom sheet background color.
  final Color? backgroundColor;

  /// How the sheet should snap to its expanded position.
  ///
  /// See [SheetSnapBehavior] for documentation.
  final SheetSnapBehavior snapBehavior;

  /// A callback to build the app bar. The app bar will not be interactive until
  /// it is completely faded in. Calling [Navigator.pop(context)] using the
  /// passed [BuildContext] will pop the modal sheet.
  final PreferredSizeWidget Function(BuildContext) appBarBuilder;

  /// The content of the sheet. This can not be a [Widget] that expands to fill
  /// available space, such as a [Scrollable] like [ListView]. Instead, use a
  /// [Column].
  final Widget child;

  const ExpandingDraggableSheet({
    super.key,
    this.initialChildSize = 0.5,
    this.minimumChildSize = 0.25,
    required this.headerHeight,
    this.headerChild,
    this.sheetBorderRadius,
    this.backgroundColor,
    this.snapBehavior = SheetSnapBehavior.start,
    required this.appBarBuilder,
    required this.child,
  }) : assert(minimumChildSize <= initialChildSize);

  @override
  State<ExpandingDraggableSheet> createState() =>
      _ExpandingDraggableSheetState();
}

class _ExpandingDraggableSheetState extends State<ExpandingDraggableSheet> {
  late final ScrollController _controller;
  final _headerAnimationPositionNotifier = ValueNotifier(0.0);
  final _overscrollNotifier = ValueNotifier(0.0);
  GlobalKey<_AnimatedAppBarState>? _appBarKey;
  OverlayEntry? _appBarOverlay;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController(
      onAttach: (position) {
        position.addListener(_onSwipeDismiss);
        position.addListener(_handleBottomOverscroll);
      },
      onDetach: (position) {
        position.removeListener(_onSwipeDismiss);
        position.removeListener(_handleBottomOverscroll);
      },
    );
    _headerAnimationPositionNotifier.addListener(_onShowAppBar);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // dependOnInheritedWidgetOfExactType can't be called in initState.
    final minimumToInitialOffset = MediaQuery.of(context).size.height *
        (widget.initialChildSize - widget.minimumChildSize);
    // Use a post-frame callback to ensure that the controller has been attached
    // to the scrollable.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _controller.jumpTo(minimumToInitialOffset);
    });
  }

  @override
  void dispose() {
    _appBarOverlay?.remove();
    _appBarOverlay = null;
    _appBarKey = null;
    _headerAnimationPositionNotifier.removeListener(_onShowAppBar);
    _controller.dispose();
    super.dispose();
  }

  void _handleBottomOverscroll() {
    final overscroll =
        _controller.offset - _controller.position.maxScrollExtent;
    if (overscroll > 0) {
      _overscrollNotifier.value = overscroll;
    } else if (_overscrollNotifier.value > 0) {
      _overscrollNotifier.value = 0;
    }
  }

  void _onShowAppBar() {
    final animationPosition = _headerAnimationPositionNotifier.value;
    if (animationPosition > 0 && _appBarOverlay == null) {
      _appBarKey = GlobalKey();
      _appBarOverlay = OverlayEntry(
        builder: (_) => Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _AnimatedAppBar(
            key: _appBarKey,
            animationNotifier: _headerAnimationPositionNotifier,
            builder: widget.appBarBuilder,
          ),
        ),
      );
      Overlay.of(context).insert(_appBarOverlay!);
    } else if (animationPosition == 0 && _appBarOverlay != null) {
      _appBarOverlay!.remove();
      _appBarKey = null;
      _appBarOverlay = null;
    }
  }

  void _onSwipeDismiss() {
    if (_controller.position.pixels < _controller.position.minScrollExtent) {
      Navigator.of(context).pop();
      // If the listener is not removed, it will continue to fire as the sheet
      // continues to be over scrolled, popping the Navigator more than once.
      _controller.position.removeListener(_onSwipeDismiss);
    }
  }

  void _updateHeaderAnimationPosition(position) {
    // Use a post-frame callback to avoid scheduling a rebuild during layout,
    // which throws an error.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_headerAnimationPositionNotifier.value == position) return;
      _headerAnimationPositionNotifier.value = position;
    });
  }

  @override
  Widget build(BuildContext context) {
    // showModalBottomSheet removes the MediaQuery top padding, which includes
    // the padding to account for system UI like notches or curved screen
    // corners. Restore the top padding by getting the MediaQuery for the root
    // View.
    final viewMediaQuery = MediaQueryData.fromView(View.of(context));
    final double paddingHeight = widget.headerHeight;
    final appBar = widget.appBarBuilder(context);
    final double appBarHeight =
        AppBar.preferredHeightFor(context, appBar.preferredSize) +
            viewMediaQuery.padding.top;

    final BottomSheetThemeData sheetTheme = Theme.of(context).bottomSheetTheme;
    // This is the way to get the default modal sheet color in Material Design,
    // including the default for DraggableScrollableSheet.
    final backgroundColor = widget.backgroundColor ??
        sheetTheme.modalBackgroundColor ??
        sheetTheme.backgroundColor ??
        Theme.of(context).colorScheme.surfaceContainerLow;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _appBarKey?.currentState?.fadeOut();
        }
      },
      child: MediaQuery(
        data: viewMediaQuery,
        child: Stack(
          children: [
            // If the scrollable is overscrolled past its max scroll extent,
            // the overscrolled portion will be a transparent hole with no
            // background color. Fill in this hole with a container that resizes
            // to the amount overscrolled.
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder(
                valueListenable: _overscrollNotifier,
                builder: (context, overscroll, _) => Container(
                  height: overscroll,
                  color: backgroundColor,
                ),
              ),
            ),
            CustomScrollView(
              controller: _controller,
              slivers: [
                SliverToBoxAdapter(
                  child: Semantics(
                    label: MaterialLocalizations.of(context)
                        .modalBarrierDismissLabel,
                    container: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: Navigator.of(this.context).pop,
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height *
                            (1 - widget.minimumChildSize),
                      ),
                    ),
                  ),
                ),
                ListenableBuilder(
                  listenable: _controller,
                  builder: (context, child) => _ExpandingSliver(
                    baseHeight: paddingHeight,
                    targetHeight: appBarHeight,
                    color: backgroundColor,
                    borderRadius: widget.sheetBorderRadius,
                    snapBehavior: widget.snapBehavior,
                    parentScrollController: _controller,
                    scrollableScrollOffset: _controller.offset,
                    updateHeaderAnimationPosition:
                    _updateHeaderAnimationPosition,
                    child: ValueListenableBuilder(
                      valueListenable: _headerAnimationPositionNotifier,
                      builder: (context, position, _) => Opacity(
                        opacity: 1 - position,
                        child: widget.headerChild,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ColoredBox(
                    color: backgroundColor,
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedAppBar extends StatefulWidget {
  final ValueNotifier<double> animationNotifier;
  final PreferredSizeWidget Function(BuildContext) builder;

  const _AnimatedAppBar({
    super.key,
    required this.animationNotifier,
    required this.builder,
  });

  @override
  State<_AnimatedAppBar> createState() => _AnimatedAppBarState();
}

class _AnimatedAppBarState extends State<_AnimatedAppBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    widget.animationNotifier.addListener(_onNotifierUpdate);
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    widget.animationNotifier.removeListener(_onNotifierUpdate);
    _controller.dispose();
    super.dispose();
  }

  TickerFuture fadeOut() {
    return _controller.animateBack(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.ease,
    );
  }

  void _onNotifierUpdate() {
    _controller.value = widget.animationNotifier.value;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => IgnorePointer(
        ignoring: _controller.value != 1,
        child: Opacity(
          opacity: _controller.value,
          child: widget.builder(context),
        ),
      ),
    );
  }
}

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

/// Defines the point at which the modal sheet starts snapping to the app bar.
enum SheetSnapBehavior {
  /// Snap to the app bar if the modal sheet has crossed the bottom edge of the
  /// app bar.
  start,

  /// Snap to the app bar if the modal sheet has crossed the midpoint of the app
  /// bar's height.
  ///
  /// This excludes any [MediaQuery] padding encompassed by the app bar,
  /// including as any padding that would be added by a [SafeArea].
  midpoint,

  /// Snap to the app bar if the modal sheet has crossed the top edge of the app bar.
  ///
  /// This excludes any [MediaQuery] padding encompassed by the app bar,
  /// including as any padding that would be added by a [SafeArea].
  end,

  /// Disable snapping behavior.
  none,
}
