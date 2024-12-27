import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

part 'animated_app_bar.dart';

part 'expanding_sliver.dart';

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
  /// Defaults to [SheetSnapBehavior.midpoint]. See [SheetSnapBehavior] for
  /// documentation.
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
    this.snapBehavior = SheetSnapBehavior.midpoint,
    required this.appBarBuilder,
    required this.child,
  })  : assert(minimumChildSize <= initialChildSize),
        assert(headerHeight > 0);

  @override
  State<ExpandingDraggableSheet> createState() =>
      _ExpandingDraggableSheetState();
}

class _ExpandingDraggableSheetState extends State<ExpandingDraggableSheet> {
  late final ScrollController _controller;
  final _headerAnimationPositionNotifier = ValueNotifier(0.0);

  // Only accounts for bottom overscroll, since top overscroll immediately
  // dismisses the sheet.
  final _overscrollNotifier = ValueNotifier(0.0);
  final _appBarKey = GlobalKey<_AnimatedAppBarState>();
  final _appBarOverlayController = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    _controller = ScrollController(
      onAttach: (position) {
        position.addListener(_handleTopOverscroll);
        position.addListener(_handleBottomOverscroll);
      },
      onDetach: (position) {
        position.removeListener(_handleTopOverscroll);
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
    _headerAnimationPositionNotifier.removeListener(_onShowAppBar);
    _controller.dispose();
    super.dispose();
  }

  // Handles swipe-to-dismiss on platforms where overscroll is allowed, like
  // iOS.
  void _handleTopOverscroll() {
    if (_controller.position.pixels < _controller.position.minScrollExtent) {
      _onSwipeDismiss();
    }
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

  // Handles swipe-to-dismiss on platforms where overscroll is not
  // allowed, like Android.
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final scrollDelta = notification.scrollDelta ?? 0.0;
      if (notification.metrics.pixels == 0 && scrollDelta < 0) {
        _onSwipeDismiss();
      }
    }

    // Always allow notifications to bubble up.
    return false;
  }

  void _onShowAppBar() {
    final animationPosition = _headerAnimationPositionNotifier.value;
    if (animationPosition > 0 && !_appBarOverlayController.isShowing) {
      _appBarOverlayController.show();
    } else if (animationPosition == 0 && _appBarOverlayController.isShowing) {
      _appBarOverlayController.hide();
    }
  }

  void _onSwipeDismiss() {
    Navigator.of(context).pop();
    // If the listener is not removed, it will continue to fire as the sheet
    // continues to be over scrolled, popping the Navigator more than once.
    _controller.position.removeListener(_handleTopOverscroll);
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
          _appBarKey.currentState?.fadeOut();
        }
      },
      child: MediaQuery(
        data: viewMediaQuery,
        child: Stack(
          children: [
            // Use an OverlayPortal to show the app bar so that features that
            // depend on the app bar's context, like automaticallyImplyLeading,
            // still work. Target the root Overlay in case there are any closer
            // Overlays that are smaller than the size of the screen.
            OverlayPortal.targetsRootOverlay(
              controller: _appBarOverlayController,
              overlayChildBuilder: (context) => Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _AnimatedAppBar(
                  key: _appBarKey,
                  animationNotifier: _headerAnimationPositionNotifier,
                  builder: widget.appBarBuilder,
                ),
              ),
            ),
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
            NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: CustomScrollView(
                controller: _controller,
                slivers: [
                  SliverToBoxAdapter(
                    child: Semantics(
                      label: MaterialLocalizations.of(context)
                          .modalBarrierDismissLabel,
                      container: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        // Ignore drag-based scrolling gestures.
                        onVerticalDragUpdate: (_) {},
                        onVerticalDragStart: (_) {},
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
            ),
          ],
        ),
      ),
    );
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
