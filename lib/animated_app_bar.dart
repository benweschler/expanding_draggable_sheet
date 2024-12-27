part of 'expanding_draggable_sheet.dart';

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
