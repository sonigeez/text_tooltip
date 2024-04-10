import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

typedef TooltipTriggeredCallback = void Function();

class _ExclusiveMouseRegion extends MouseRegion {
  const _ExclusiveMouseRegion({
    super.onEnter,
    super.onExit,
    super.child,
  });

  @override
  _RenderExclusiveMouseRegion createRenderObject(BuildContext context) {
    return _RenderExclusiveMouseRegion(
      onEnter: onEnter,
      onExit: onExit,
    );
  }
}

class _RenderExclusiveMouseRegion extends RenderMouseRegion {
  _RenderExclusiveMouseRegion({
    super.onEnter,
    super.onExit,
  });

  static bool isOutermostMouseRegion = true;
  static bool foundInnermostMouseRegion = false;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    bool isHit = false;
    final bool outermost = isOutermostMouseRegion;
    isOutermostMouseRegion = false;
    if (size.contains(position)) {
      isHit =
          hitTestChildren(result, position: position) || hitTestSelf(position);
      if ((isHit || behavior == HitTestBehavior.translucent) &&
          !foundInnermostMouseRegion) {
        foundInnermostMouseRegion = true;
        result.add(BoxHitTestEntry(this, position));
      }
    }

    if (outermost) {
      // The outermost region resets the global states.
      isOutermostMouseRegion = true;
      foundInnermostMouseRegion = false;
    }
    return isHit;
  }
}

class TextToolTip extends StatefulWidget {
  const TextToolTip({
    super.key,
    this.message,
    this.richMessage,
    this.height,
    this.padding,
    this.margin,
    this.verticalOffset,
    this.preferBelow,
    this.excludeFromSemantics,
    this.decoration,
    this.textStyle,
    this.textAlign,
    this.waitDuration,
    this.showDuration,
    this.exitDuration,
    this.enableTapToDismiss = true,
    this.triggerMode,
    this.enableFeedback,
    this.onTriggered,
    this.isCircle = false,
    this.showDisable = false,
    this.tooltipPosition = TooltipPosition.up,
    this.child,
  })  : assert((message == null) != (richMessage == null),
            'Either `message` or `richMessage` must be specified'),
        assert(
          richMessage == null || textStyle == null,
          'If `richMessage` is specified, `textStyle` will have no effect. '
          'If you wish to provide a `textStyle` for a rich tooltip, add the '
          '`textStyle` directly to the `richMessage` InlineSpan.',
        );
  final String? message;
  final bool showDisable;
  final bool isCircle;
  final TooltipPosition tooltipPosition;

  final InlineSpan? richMessage;

  final double? height;

  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? verticalOffset;

  final bool? preferBelow;

  final bool? excludeFromSemantics;

  final Widget? child;

  final Decoration? decoration;
  final TextStyle? textStyle;

  final TextAlign? textAlign;
  final Duration? waitDuration;
  final Duration? showDuration;

  final Duration? exitDuration;

  final bool enableTapToDismiss;
  final TooltipTriggerMode? triggerMode;
  final bool? enableFeedback;

  final TooltipTriggeredCallback? onTriggered;

  static final List<TextToolTipState> _openedTooltips = <TextToolTipState>[];

  static bool dismissAllToolTips() {
    if (_openedTooltips.isNotEmpty) {
      // Avoid concurrent modification.
      final List<TextToolTipState> openedTooltips = _openedTooltips.toList();
      for (final TextToolTipState state in openedTooltips) {
        assert(state.mounted);
        state._scheduleDismissTooltip(withDelay: Duration.zero);
      }
      return true;
    }
    return false;
  }

  @override
  State<TextToolTip> createState() => TextToolTipState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty(
      'message',
      message,
      showName: message == null,
      defaultValue: message == null ? null : kNoDefaultValue,
    ));
    properties.add(StringProperty(
      'richMessage',
      richMessage?.toPlainText(),
      showName: richMessage == null,
      defaultValue: richMessage == null ? null : kNoDefaultValue,
    ));
    properties.add(DoubleProperty('height', height, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding,
        defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('margin', margin,
        defaultValue: null));
    properties.add(
        DoubleProperty('vertical offset', verticalOffset, defaultValue: null));
    properties.add(FlagProperty('position',
        value: preferBelow, ifTrue: 'below', ifFalse: 'above', showName: true));
    properties.add(FlagProperty('semantics',
        value: excludeFromSemantics, ifTrue: 'excluded', showName: true));
    properties.add(DiagnosticsProperty<Duration>('wait duration', waitDuration,
        defaultValue: null));
    properties.add(DiagnosticsProperty<Duration>('show duration', showDuration,
        defaultValue: null));
    properties.add(DiagnosticsProperty<Duration>('exit duration', exitDuration,
        defaultValue: null));
    properties.add(DiagnosticsProperty<TooltipTriggerMode>(
        'triggerMode', triggerMode,
        defaultValue: null));
    properties.add(FlagProperty('enableFeedback',
        value: enableFeedback, ifTrue: 'true', showName: true));
    properties.add(DiagnosticsProperty<TextAlign>('textAlign', textAlign,
        defaultValue: null));
  }
}

/// Contains the state for a [TextToolTip].
///
/// This class can be used to programmatically show the Tooltip, see the
/// [ensureTooltipVisible] method.
class TextToolTipState extends State<TextToolTip>
    with SingleTickerProviderStateMixin {
  static const Duration _fadeInDuration = Duration(milliseconds: 150);
  static const Duration _fadeOutDuration = Duration(milliseconds: 150);
  static const Duration _defaultShowDuration = Duration(milliseconds: 1500);
  static const Duration _defaultHoverExitDuration = Duration(milliseconds: 100);
  static const Duration _defaultWaitDuration = Duration.zero;
  static const bool _defaultExcludeFromSemantics = false;
  static const TooltipTriggerMode _defaultTriggerMode =
      TooltipTriggerMode.longPress;
  static const bool _defaultEnableFeedback = true;

  final OverlayPortalController _overlayController = OverlayPortalController();
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // From InheritedWidgets
  late bool _visible;
  late TooltipThemeData _tooltipTheme;

  Duration get _showDuration =>
      widget.showDuration ?? _tooltipTheme.showDuration ?? _defaultShowDuration;
  Duration get _hoverExitDuration =>
      widget.exitDuration ??
      _tooltipTheme.exitDuration ??
      _defaultHoverExitDuration;
  Duration get _waitDuration =>
      widget.waitDuration ?? _tooltipTheme.waitDuration ?? _defaultWaitDuration;
  TooltipTriggerMode get _triggerMode =>
      widget.triggerMode ?? _tooltipTheme.triggerMode ?? _defaultTriggerMode;
  bool get _enableFeedback =>
      widget.enableFeedback ??
      _tooltipTheme.enableFeedback ??
      _defaultEnableFeedback;

  String get _tooltipMessage =>
      widget.message ?? widget.richMessage!.toPlainText();

  Timer? _timer;
  AnimationController? _backingController;
  AnimationController get _controller {
    return _backingController ??= AnimationController(
      duration: _fadeInDuration,
      reverseDuration: _fadeOutDuration,
      vsync: this,
    )..addStatusListener(_handleStatusChanged);
  }

  LongPressGestureRecognizer? _longPressRecognizer;
  TapGestureRecognizer? _tapRecognizer;

  final Set<int> _activeHoveringPointerDevices = <int>{};

  static bool _isTooltipVisible(AnimationStatus status) {
    return switch (status) {
      AnimationStatus.completed ||
      AnimationStatus.forward ||
      AnimationStatus.reverse =>
        true,
      AnimationStatus.dismissed => false,
    };
  }

  AnimationStatus _animationStatus = AnimationStatus.dismissed;
  void _handleStatusChanged(AnimationStatus status) {
    assert(mounted);
    switch ((_isTooltipVisible(_animationStatus), _isTooltipVisible(status))) {
      case (true, false):
        TextToolTip._openedTooltips.remove(this);
        _overlayController.hide();
      case (false, true):
        _overlayController.show();
        TextToolTip._openedTooltips.add(this);
        SemanticsService.tooltip(_tooltipMessage);
      case (true, true) || (false, false):
        break;
    }
    _animationStatus = status;
  }

  void _scheduleShowTooltip(
      {required Duration withDelay, Duration? showDuration}) {
    assert(mounted);
    void show() {
      assert(mounted);
      if (!_visible) {
        return;
      }
      _controller.forward();
      _timer?.cancel();
      _timer = showDuration == null
          ? null
          : Timer(showDuration, _controller.reverse);
    }

    assert(
      !(_timer?.isActive ?? false) ||
          _controller.status != AnimationStatus.reverse,
      'timer must not be active when the tooltip is fading out',
    );
    switch (_controller.status) {
      case AnimationStatus.dismissed when withDelay.inMicroseconds > 0:
        _timer ??= Timer(withDelay, show);
        break;
      case AnimationStatus.dismissed:
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
      case AnimationStatus.completed:
        show();
    }
  }

  void _scheduleDismissTooltip({required Duration withDelay}) {
    assert(mounted);
    assert(
      !(_timer?.isActive ?? false) ||
          _backingController?.status != AnimationStatus.reverse,
      'timer must not be active when the tooltip is fading out',
    );

    _timer?.cancel();
    _timer = null;
    switch (_backingController?.status) {
      case null:
      case AnimationStatus.reverse:
      case AnimationStatus.dismissed:
        break;
      // Dismiss when the tooltip is fading in: if there's a dismiss delay we'll
      // allow the fade in animation to continue until the delay timer fires.
      case AnimationStatus.forward:
      case AnimationStatus.completed:
        if (withDelay.inMicroseconds > 0) {
          _timer = Timer(withDelay, _controller.reverse);
        } else {
          _controller.reverse();
        }
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    assert(mounted);
    const Set<PointerDeviceKind> triggerModeDeviceKinds = <PointerDeviceKind>{
      PointerDeviceKind.invertedStylus,
      PointerDeviceKind.stylus,
      PointerDeviceKind.touch,
      PointerDeviceKind.unknown,
      PointerDeviceKind.trackpad,
    };
    switch (_triggerMode) {
      case TooltipTriggerMode.longPress:
        final LongPressGestureRecognizer recognizer =
            _longPressRecognizer ??= LongPressGestureRecognizer(
          debugOwner: this,
          supportedDevices: triggerModeDeviceKinds,
        );
        recognizer
          ..onLongPressCancel = _handleTapToDismiss
          ..onLongPress = _handleLongPress
          ..onLongPressUp = _handlePressUp
          ..addPointer(event);
        break;
      case TooltipTriggerMode.tap:
        final TapGestureRecognizer recognizer = _tapRecognizer ??=
            TapGestureRecognizer(
                debugOwner: this, supportedDevices: triggerModeDeviceKinds);
        recognizer
          ..onTapCancel = _handleTapToDismiss
          ..onTap = _handleTap
          ..addPointer(event);
        break;
      case TooltipTriggerMode.manual:
        break;
    }
  }

  // For PointerDownEvents, this method will be called after _handlePointerDown.
  void _handleGlobalPointerEvent(PointerEvent event) {
    assert(mounted);
    if (_tapRecognizer?.primaryPointer == event.pointer ||
        _longPressRecognizer?.primaryPointer == event.pointer) {
      return;
    }
    if ((_timer == null && _controller.status == AnimationStatus.dismissed) ||
        event is! PointerDownEvent) {
      return;
    }
    _handleTapToDismiss();
  }

  void _handleTapToDismiss() {
    if (!widget.enableTapToDismiss) {
      return;
    }
    _scheduleDismissTooltip(withDelay: Duration.zero);
    _activeHoveringPointerDevices.clear();
  }

  void _handleTap() {
    if (!_visible) {
      return;
    }
    final bool tooltipCreated = _controller.status == AnimationStatus.dismissed;
    if (tooltipCreated && _enableFeedback) {
      assert(_triggerMode == TooltipTriggerMode.tap);
      Feedback.forTap(context);
    }
    widget.onTriggered?.call();
    _scheduleShowTooltip(
      withDelay: Duration.zero,
      // _activeHoveringPointerDevices keep the tooltip visible.
      showDuration:
          _activeHoveringPointerDevices.isEmpty ? _showDuration : null,
    );
  }

  // When a "trigger" gesture is recognized and the pointer down even is a part
  // of it.
  void _handleLongPress() {
    if (!_visible) {
      return;
    }
    final bool tooltipCreated =
        _visible && _controller.status == AnimationStatus.dismissed;
    if (tooltipCreated && _enableFeedback) {
      assert(_triggerMode == TooltipTriggerMode.longPress);
      Feedback.forLongPress(context);
    }
    widget.onTriggered?.call();
    _scheduleShowTooltip(withDelay: Duration.zero);
  }

  void _handlePressUp() {
    if (_activeHoveringPointerDevices.isNotEmpty) {
      return;
    }
    _scheduleDismissTooltip(withDelay: _showDuration);
  }

  void _handleMouseEnter(PointerEnterEvent event) {
    _activeHoveringPointerDevices.add(event.device);
    final List<TextToolTipState> openedTooltips =
        TextToolTip._openedTooltips.toList();
    bool otherTooltipsDismissed = false;
    for (final TextToolTipState tooltip in openedTooltips) {
      assert(tooltip.mounted);
      final Set<int> hoveringDevices = tooltip._activeHoveringPointerDevices;
      final bool shouldDismiss = tooltip != this &&
          (hoveringDevices.length == 1 &&
              hoveringDevices.single == event.device);
      if (shouldDismiss) {
        otherTooltipsDismissed = true;
        tooltip._scheduleDismissTooltip(withDelay: Duration.zero);
      }
    }
    _scheduleShowTooltip(
        withDelay: otherTooltipsDismissed ? Duration.zero : _waitDuration);
  }

  void _handleMouseExit(PointerExitEvent event) {
    if (_activeHoveringPointerDevices.isEmpty) {
      return;
    }
    _activeHoveringPointerDevices.remove(event.device);
    if (_activeHoveringPointerDevices.isEmpty) {
      _scheduleDismissTooltip(withDelay: _hoverExitDuration);
    }
  }

  bool ensureTooltipVisible() {
    if (!_visible) {
      return false;
    }

    _timer?.cancel();
    _timer = null;
    switch (_controller.status) {
      case AnimationStatus.dismissed:
      case AnimationStatus.reverse:
        _scheduleShowTooltip(withDelay: Duration.zero);
        return true;
      case AnimationStatus.forward:
      case AnimationStatus.completed:
        return false;
    }
  }

  @override
  void initState() {
    _fadeAnimation = Tween(begin: -1.0, end: 1.0).animate(_controller);
    _scaleAnimation = Tween(begin: .6, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.bounceInOut,
    ));
    super.initState();
    GestureBinding.instance.pointerRouter
        .addGlobalRoute(_handleGlobalPointerEvent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TooltipVisibility.of(context);
    _tooltipTheme = TooltipTheme.of(context);
  }

  Widget _buildTooltip(BuildContext context) {
    final RenderBox box = this.context.findRenderObject()! as RenderBox;
    var childRect = box.localToGlobal(Offset.zero) & box.size;
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      child: Stack(
        children: [
          if (widget.showDisable)
            Positioned.fill(
              child: CustomPaint(
                  painter: widget.isCircle
                      ? CirclePainter(
                          rect: childRect,
                          color: Colors.black.withOpacity(0.66),
                        )
                      : RectPainter(
                          rect: childRect,
                          color: Colors.black.withOpacity(0.66),
                        )),
            ),
          Positioned.fill(
              child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: CustomPaint(
                  painter: TooltipArrowPainter(
                    targetRect: childRect,
                    color: Colors.white,
                    textStyle: widget.textStyle ?? const TextStyle(),
                    direction: widget.tooltipPosition,
                    text: widget.message ?? "",
                  ),
                ),
              ),
            ),
          ))
          // Positioned,
        ],
      ),
    );
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter
        .removeGlobalRoute(_handleGlobalPointerEvent);
    TextToolTip._openedTooltips.remove(this);
    _longPressRecognizer?.onLongPressCancel = null;
    _longPressRecognizer?.dispose();
    _tapRecognizer?.onTapCancel = null;
    _tapRecognizer?.dispose();
    _timer?.cancel();
    _backingController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tooltipMessage.isEmpty) {
      return widget.child ?? const SizedBox.shrink();
    }
    assert(debugCheckHasOverlay(context));
    final bool excludeFromSemantics = widget.excludeFromSemantics ??
        _tooltipTheme.excludeFromSemantics ??
        _defaultExcludeFromSemantics;
    Widget result = Semantics(
      tooltip: excludeFromSemantics ? null : _tooltipMessage,
      child: widget.child,
    );

    if (_visible) {
      result = _ExclusiveMouseRegion(
        onEnter: _handleMouseEnter,
        onExit: _handleMouseExit,
        child: Listener(
          onPointerDown: _handlePointerDown,
          behavior: HitTestBehavior.opaque,
          child: result,
        ),
      );
    }
    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: _buildTooltip,
      child: result,
    );
  }
}

class RectPainter extends CustomPainter {
  final Rect rect;
  final Color color;

  RectPainter({required this.rect, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final rectPath = Path()..addRect(rect);
    final combinedPath = Path.combine(
      PathOperation.difference,
      path,
      rectPath,
    );

    canvas.drawPath(
      combinedPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CirclePainter extends CustomPainter {
  final Rect rect;
  final Color color;

  CirclePainter({required this.rect, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Calculate circle diameter
    final circleDiameter = rect.width < rect.height ? rect.width : rect.height;
    // Define the circle's bounding box
    final Rect circleBounds = Rect.fromCenter(
      center: rect.center,
      width: circleDiameter + 10,
      height: circleDiameter + 10,
    );
    final circlePath = Path()..addOval(circleBounds);

    final combinedPath = Path.combine(
      PathOperation.difference,
      path,
      circlePath,
    );

    canvas.drawPath(
      combinedPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

enum TooltipPosition { up, down, left, right }

class TooltipArrowPainter extends CustomPainter {
  final Rect targetRect;
  final Color color;
  final TooltipPosition direction;
  final String text;
  final TextStyle textStyle;
  final double borderRadius = 8.0;

  final double horizontalPadding = 10.0;
  final double verticalPadding = 8.0;

  TooltipArrowPainter({
    required this.targetRect,
    required this.color,
    required this.text,
    required this.textStyle,
    this.direction = TooltipPosition.down,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();

    // Arrow calculation
    Offset arrowPoint;
    Offset arrowBase1, arrowBase2;
    switch (direction) {
      case TooltipPosition.up:
        arrowPoint = Offset(targetRect.center.dx, targetRect.top);
        arrowBase1 = Offset(targetRect.center.dx - 10, targetRect.top - 10);
        arrowBase2 = Offset(targetRect.center.dx + 10, targetRect.top - 10);
        break;
      case TooltipPosition.down:
        arrowPoint = Offset(targetRect.center.dx, targetRect.bottom);
        arrowBase1 = Offset(targetRect.center.dx - 10, targetRect.bottom + 10);
        arrowBase2 = Offset(targetRect.center.dx + 10, targetRect.bottom + 10);
        break;
      case TooltipPosition.left:
        arrowPoint = Offset(targetRect.left, targetRect.center.dy);
        arrowBase1 = Offset(targetRect.left - 10, targetRect.center.dy - 10);
        arrowBase2 = Offset(targetRect.left - 10, targetRect.center.dy + 10);
        break;
      case TooltipPosition.right:
        arrowPoint = Offset(targetRect.right, targetRect.center.dy);
        arrowBase1 = Offset(targetRect.right + 10, targetRect.center.dy - 10);
        arrowBase2 = Offset(targetRect.right + 10, targetRect.center.dy + 10);
        break;
    }

    // Draw arrow
    path.moveTo(arrowPoint.dx, arrowPoint.dy);
    path.lineTo(arrowBase1.dx, arrowBase1.dy);
    path.lineTo(arrowBase2.dx, arrowBase2.dy);
    path.close();
    canvas.drawPath(path, paint);

    // Text preparation
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Background rectangle calculation
    double bgRectTop, bgRectLeft;
    switch (direction) {
      case TooltipPosition.up:
      case TooltipPosition.down:
        bgRectTop = direction == TooltipPosition.up
            ? arrowPoint.dy - 10 - textPainter.height - verticalPadding * 2
            : arrowPoint.dy + 10;
        bgRectLeft = arrowPoint.dx - textPainter.width / 2 - horizontalPadding;
        break;
      case TooltipPosition.left:
      case TooltipPosition.right:
        bgRectTop = arrowPoint.dy - textPainter.height / 2 - verticalPadding;
        bgRectLeft = direction == TooltipPosition.left
            ? arrowPoint.dx - 8 - textPainter.width - horizontalPadding * 2
            : arrowPoint.dx + 10;
        break;
    }

    // Draw rounded background rectangle
    final bgRect = Rect.fromLTWH(
      bgRectLeft,
      bgRectTop,
      textPainter.width + horizontalPadding * 2,
      textPainter.height + verticalPadding * 2,
    );
    final bgRRect = RRect.fromRectAndRadius(
      bgRect,
      Radius.circular(borderRadius),
    );
    canvas.drawRRect(bgRRect, Paint()..color = Colors.white);

    // Draw text
    textPainter.paint(
      canvas,
      Offset(
        bgRect.left + horizontalPadding,
        bgRect.top + verticalPadding,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
