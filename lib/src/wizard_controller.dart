import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:rxdart/rxdart.dart';
import '../flutter_wizard.dart';

/// Coordinates the wizard steps and its input control states.
abstract class WizardController {
  /// Controller to control the page view.
  PageController get pageController;

  /// Streams the events that happen on this [WizardController]. The events have
  /// a base type of [WizardEvent] and can be casted to the specific event type.
  /// The events are:
  /// - [WizardEnableGoBackEvent]: Triggered when `enableGoBack` is called.
  /// - [WizardEnableGoNextEvent]: Triggered when `enableGoNext` is called.
  /// - [WizardDisableGoBackEvent]: Triggered when `disableGoBack` is called.
  /// - [WizardDisableGoNextEvent]: Triggered when `disableGoNext` is called.
  /// - [WizardGoNextEvent]: Triggered when `goNext` is called.
  /// - [WizardGoBackEvent]: Triggered when `goBack` is called.
  /// - [WizardGoToEvent]: Triggered when `goTo` is called.
  /// - [WizardForcedGoBackToEvent]: Triggered when `disableGoNext` is called with an
  /// index lower as the current index.
  Stream<WizardEvent> get eventStream;

  /// The step controllers.
  List<WizardStepController> get stepControllers;

  /// The step count.
  int get stepCount;

  /// Indicates whether the step index matches the first step.
  bool isFirstStep(int index);

  /// Indicates whether the step index matches the last step.
  bool isLastStep(int index);

  /// Streams the wizard step index.
  Stream<int> get indexStream;

  /// The current wizard step index.
  int get index;

  /// Gets the index for the provided step.
  int getStepIndex(
    WizardStep step,
  );

  /// Streams whether the back button is enabled for current index.
  Stream<bool> getIsGoBackEnabledStream();

  /// Indicates whether the back button currently is enabled for current index.
  bool getIsGoBackEnabled();

  /// Enable the back button for specified index.
  void enableGoBack(
    int index,
  );

  /// Disable the back button for specified index.
  void disableGoBack(
    int index,
  );

  /// Stream whether the next button is enabled for current index.
  Stream<bool> getIsGoNextEnabledStream();

  /// Indicates whether the next button currently is enabled for current index.
  bool getIsGoNextEnabled();

  /// Stream whether its allowed to go to specified index.
  Stream<bool> getIsGoToEnabledStream(
    int index,
  );

  /// Indicates whether its allowed to go to specified index.
  bool getIsGoToEnabled(
    int index,
  );

  /// Enable the next button for specified index.
  void enableGoNext(
    int index,
  );

  /// Disable the next button for specified index.  When disabling an index that
  /// is lower then the current index the `Wizard` will automatically animate
  /// back to the provided index.
  Future<void> disableGoNext(
    int index, {
    Duration duration,
    Curve curve,
  });

  /// Show the next step. If the current step equals the last step nothing will
  /// happen.
  Future<void> goNext({
    Duration delay,
    Duration duration,
    Curve curve,
  });

  /// Animate to the step index. If the current step index equals the provided
  /// step index nothing will happen.
  Future<void> goTo({
    required int index,
    Duration delay,
    Duration duration,
    Curve curve,
  });

  /// Show the previous step. If current step equals the first step nothing
  /// will happen.
  Future<void> goBack({
    Duration duration,
    Curve curve,
  });

  /// Dispose the controller
  void dispose();

  /// The closest instance of this class that encloses the given context.
  ///
  /// {@tool snippet}
  /// Typical usage is as follows:
  ///
  /// ```dart
  /// WizardController controller = DefaultWizardController.of(context);
  /// ```
  /// {@end-tool}
  static WizardController of(
    BuildContext context,
  ) {
    final _WizardControllerScope? scope =
        context.dependOnInheritedWidgetOfExactType<_WizardControllerScope>();
    final controller = scope?.controller;
    if (controller == null) {
      // TODO: improve
      throw Exception(
        "No wizard controller can be found within the widget tree. Please make sure your widget is wrapped with a DefaultWizardController widget.",
      );
    }
    return controller;
  }
}

/// Coordinates the wizard steps and its input control states.
///
/// The default implementation of [WizardController].
class WizardControllerImpl implements WizardController {
  /// Creates a [WizardControllerImpl] implementation of the [WizardController]
  /// contract.
  ///
  /// This class coordinates the wizard steps and its input control states.
  ///
  /// stepControllers: A list of [WizardStepController]s which contain the
  /// step's state and initial input control states.
  ///
  /// Example:
  /// ```dart
  /// stepControllers: [
  ///   WizardStepController(
  ///     step: provider.stepOneProvider,
  ///   ),
  ///   WizardStepController(
  ///     step: provider.stepTwoProvider,
  ///     isBackEnabled: false,
  ///     isNextEnabled: false,
  ///   ),
  ///   WizardStepController(
  ///     step: provider.stepThreeProvider,
  ///   ),
  /// ],
  /// ```
  ///
  /// initialIndex: Indicates the initial index of the wizard.
  ///
  /// onStepChanged: Callback that gets triggered when the step changes.
  WizardControllerImpl({
    required List<WizardStepController> stepControllers,
    int initialIndex = 0,
    StepCallback? onStepChanged,
  })  : stepControllers = List.unmodifiable(stepControllers),
        pageController = PageController(
          initialPage: initialIndex,
        ),
        _index = BehaviorSubject<int>.seeded(
          initialIndex,
        ),
        _events = BehaviorSubject<WizardEvent>(),
        _onStepChanged = onStepChanged {
    _setWizardControllerInSteps();
  }

  WizardControllerImpl.formController(
    WizardController controller, {
    List<WizardStepController>? stepControllers,
    StepCallback? onStepChanged,
  })  : stepControllers =
            List.unmodifiable(stepControllers ?? controller.stepControllers),
        pageController = controller.pageController,
        _index = BehaviorSubject<int>.seeded(controller.index),
        _events = BehaviorSubject<WizardEvent>(),
        _onStepChanged = onStepChanged {
    _setWizardControllerInSteps();
  }

  void _setWizardControllerInSteps() {
    for (final controller in stepControllers) {
      controller.step.wizardController = this;
    }
  }

  final BehaviorSubject<int> _index;

  final BehaviorSubject<WizardEvent> _events;

  final StepCallback? _onStepChanged;

  @override
  final List<WizardStepController> stepControllers;

  @override
  final PageController pageController;

  @override
  Stream<WizardEvent> get eventStream => _events.stream.asBroadcastStream();

  @override
  Stream<int> get indexStream => _index.stream.asBroadcastStream();

  @override
  int get index => _index.value;

  @override
  int get stepCount => stepControllers.length;

  @override
  bool isFirstStep(int index) => index == 0;

  @override
  bool isLastStep(int index) => index == stepCount - 1;

  @override
  Future<void> goNext({
    Duration? delay,
    Duration duration = const Duration(milliseconds: 150),
    Curve curve = Curves.easeIn,
  }) async {
    if (isLastStep(index) || !getIsGoNextEnabled()) {
      return;
    }
    _events.add(WizardGoNextEvent(
      fromIndex: index,
      toIndex: index + 1,
    ));
    final delayUntil = DateTime.now().add(duration);
    final oldIndex = index;
    final newIndex = oldIndex + 1;
    if (_onStepChanged != null) {
      await _onStepChanged!(
        oldIndex,
        index,
      );
    }
    final now = DateTime.now();
    if (delay != null && delayUntil.isAfter(now)) {
      final realDelay = Duration(
        milliseconds:
            delayUntil.millisecondsSinceEpoch - now.millisecondsSinceEpoch,
      );
      await Future.delayed(realDelay);
    }
    _index.add(newIndex);
    await Future.wait([
      stepControllers[newIndex].step.onShowing(),
      stepControllers[oldIndex].step.onHiding(),
      pageController.nextPage(
        duration: duration,
        curve: curve,
      ),
    ]);
    await Future.wait([
      stepControllers[newIndex].step.onShowingCompleted(),
      stepControllers[oldIndex].step.onHidingCompleted(),
    ]);
  }

  @override
  Future<void> goBack({
    Duration duration = const Duration(milliseconds: 150),
    Curve curve = Curves.easeIn,
  }) async {
    if (isFirstStep(index) || !getIsGoBackEnabled()) {
      return;
    }
    _events.add(WizardGoBackEvent(
      fromIndex: index,
      toIndex: index - 1,
    ));
    final oldIndex = index;
    final newIndex = oldIndex - 1;
    if (_onStepChanged != null) {
      await _onStepChanged!(
        oldIndex,
        index,
      );
    }
    _index.add(newIndex);
    await Future.wait([
      stepControllers[newIndex].step.onShowing(),
      stepControllers[oldIndex].step.onHiding(),
      pageController.previousPage(
        duration: duration,
        curve: curve,
      ),
    ]);
    await Future.wait([
      stepControllers[newIndex].step.onShowingCompleted(),
      stepControllers[oldIndex].step.onHidingCompleted(),
    ]);
  }

  @override
  Future<void> goTo({
    required int index,
    Duration? delay,
    Duration duration = const Duration(milliseconds: 150),
    Curve curve = Curves.easeIn,
  }) async {
    if (this.index == index || !getIsGoToEnabled(index)) {
      return;
    }
    _events.add(WizardGoToEvent(
      fromIndex: this.index,
      toIndex: index,
    ));
    final delayUntil = DateTime.now().add(duration);
    final oldIndex = this.index;
    final newIndex = index;
    if (_onStepChanged != null) {
      await _onStepChanged!(
        oldIndex,
        index,
      );
    }
    final now = DateTime.now();
    if (delay != null && delayUntil.isAfter(now)) {
      final realDelay = Duration(
        milliseconds:
            delayUntil.millisecondsSinceEpoch - now.millisecondsSinceEpoch,
      );
      await Future.delayed(realDelay);
    }
    _index.add(newIndex);
    await Future.wait([
      stepControllers[newIndex].step.onShowing(),
      stepControllers[oldIndex].step.onHiding(),
      pageController.animateToPage(
        newIndex,
        duration: duration,
        curve: curve,
      ),
    ]);
    await Future.wait([
      stepControllers[newIndex].step.onShowingCompleted(),
      stepControllers[oldIndex].step.onHidingCompleted(),
    ]);
  }

  @override
  void dispose() {
    pageController.dispose();
    _index.close();
    _events.close();
  }

  @override
  void disableGoBack(
    int index,
  ) {
    _events.add(WizardDisableGoBackEvent(
      index: index,
    ));
    stepControllers[index].disableGoBack();
  }

  @override
  Future<void> disableGoNext(
    int index, {
    Duration duration = const Duration(milliseconds: 150),
    Curve curve = Curves.easeIn,
  }) async {
    _events.add(WizardDisableGoNextEvent(
      index: index,
    ));
    stepControllers[index].disableGoNext();

    final currentIndex = this.index;
    if (index >= currentIndex) {
      return;
    }

    _events.add(WizardForcedGoBackToEvent(
      fromIndex: currentIndex,
      toIndex: index,
    ));

    await goTo(
      index: index,
      duration: duration,
      curve: curve,
    );
  }

  @override
  void enableGoBack(
    int index,
  ) {
    _events.add(WizardEnableGoBackEvent(
      index: index,
    ));
    stepControllers[index].enableGoBack();
  }

  @override
  void enableGoNext(
    int index,
  ) {
    _events.add(WizardEnableGoNextEvent(
      index: index,
    ));
    stepControllers[index].enableGoNext();
  }

  @override
  bool getIsGoBackEnabled() {
    return stepControllers[index].isGoBackEnabled;
  }

  @override
  Stream<bool> getIsGoBackEnabledStream() {
    return indexStream.switchMap((index) {
      return stepControllers[index].isGoBackEnabledStream;
    });
  }

  @override
  bool getIsGoNextEnabled() {
    return stepControllers[index].isGoNextEnabled;
  }

  @override
  Stream<bool> getIsGoNextEnabledStream([
    int? index,
  ]) {
    return indexStream.switchMap((index) {
      return stepControllers[index].isGoNextEnabledStream;
    });
  }

  @override
  bool getIsGoToEnabled(
    int index,
  ) {
    final indexes = _generateIndexList(index - 1);
    for (final index in indexes) {
      if (!stepControllers[index].isGoNextEnabled) {
        return false;
      }
    }
    return true;
  }

  @override
  Stream<bool> getIsGoToEnabledStream(
    int index,
  ) {
    final indexes = _generateIndexList(index - 1);
    return Rx.combineLatestList(
      indexes.map((index) => stepControllers[index].isGoNextEnabledStream),
    ).map((isGoNextEnabledList) {
      return isGoNextEnabledList.every((isGoNextEnabled) => isGoNextEnabled);
    });
  }

  List<int> _generateIndexList(
    int index,
  ) {
    return List.generate(index + 1, (index) => index);
  }

  @override
  int getStepIndex(
    WizardStep step,
  ) {
    return stepControllers.indexWhere(
      (controller) => controller.step == step,
    );
  }
}

class _WizardControllerScope extends InheritedWidget {
  const _WizardControllerScope({
    Key? key,
    required this.controller,
    required this.enabled,
    required Widget child,
  }) : super(
          key: key,
          child: child,
        );

  final WizardController controller;
  final bool enabled;

  @override
  bool updateShouldNotify(_WizardControllerScope old) {
    return enabled != enabled || controller != old.controller;
  }
}

/// The [WizardController] for descendant widgets.
///
/// [DefaultWizardController] is an inherited widget that is used to share a
/// [WizardController] with a [Wizard], [WizardEventListener] and/or any custom
/// input controls.
///
/// ```dart
/// return DefaultWizardController(
///   stepControllers: [
///     ...
///   ],
///   child: WizardEventListener(
///     listener: (context, event) {
///       ...
///     },
///     child: Column(
///       children: [
///         _ProgressIndicator(
///           context,
///         ),
///         Expanded(
///           child: Wizard(
///             stepBuilder: (context, state) {
///               ...
///             },
///           ),
///         ),
///         const _ActionBar(),
///       ],
///     ),
///   ),
/// );
/// ```
class DefaultWizardController extends StatefulWidget {
  /// Creates the [DefaultWizardController] containing the [WizardController] for
  /// descendant widgets.
  ///
  /// stepControllers: A list of [WizardStepController]s which contain the
  /// step's state and initial input control states.
  ///
  /// Example:
  /// ```dart
  /// stepControllers: [
  ///   WizardStepController(
  ///     step: provider.stepOneProvider,
  ///   ),
  ///   WizardStepController(
  ///     step: provider.stepTwoProvider,
  ///     isBackEnabled: false,
  ///     isNextEnabled: false,
  ///   ),
  ///   WizardStepController(
  ///     step: provider.stepThreeProvider,
  ///   ),
  /// ],
  /// ```
  ///
  /// initialIndex: Indicates the initial index of the wizard.
  ///
  /// onStepChanged: Callback that gets triggered when the step changes.
  ///
  /// onControllerCreated: Callback that gets triggered when the controller is
  /// created.
  ///
  /// child: The child [Widget].
  ///
  /// Example:
  /// ```dart
  /// return DefaultWizardController(
  ///   stepControllers: [
  ///     ...
  ///   ],
  ///   child: WizardEventListener(
  ///     listener: (context, event) {
  ///       ...
  ///     },
  ///     child: Column(
  ///       children: [
  ///         _ProgressIndicator(
  ///           context,
  ///         ),
  ///         Expanded(
  ///           child: Wizard(
  ///             stepBuilder: (context, state) {
  ///               ...
  ///             },
  ///           ),
  ///         ),
  ///         const _ActionBar(),
  ///       ],
  ///     ),
  ///   ),
  /// );
  /// ```
  const DefaultWizardController({
    required this.stepControllers,
    this.initialIndex = 0,
    this.onStepChanged,
    this.onControllerCreated,
    required this.child,
    Key? key,
  }) : super(key: key);

  /// The step controllers. This property determines the order of the steps.
  final List<WizardStepController> stepControllers;

  /// Indicates the initial index of the wizard.
  final int initialIndex;

  /// Callback that gets triggered when the step changes.
  final StepCallback? onStepChanged;

  /// The child widget
  final Widget child;

  /// Callback that gets triggered when the [WizardController] is created.
  final FutureOr<void> Function(WizardController controller)?
      onControllerCreated;

  @override
  _DefaultWizardControllerState createState() =>
      _DefaultWizardControllerState();
}

class _DefaultWizardControllerState extends State<DefaultWizardController> {
  /// The controller to control the wizard
  late WizardController controller;

  @override
  void initState() {
    _createController();
    super.initState();
  }

  @override
  void didUpdateWidget(
    covariant DefaultWizardController oldWidget,
  ) {
    if (oldWidget.onStepChanged != widget.onStepChanged ||
        oldWidget.stepControllers != widget.stepControllers) {
      _copyController();
    }
    super.didUpdateWidget(oldWidget);
  }

  void _copyController() {
    final controller = this.controller;
    if (controller is WizardControllerImpl) {
      controller._events.close();
      controller._index.close();
    }
    this.controller = WizardControllerImpl.formController(
      controller,
      onStepChanged: widget.onStepChanged,
      stepControllers: widget.stepControllers,
    );
  }

  void _createController() {
    controller = WizardControllerImpl(
      stepControllers: widget.stepControllers,
      initialIndex: widget.initialIndex,
      onStepChanged: widget.onStepChanged,
    );
    if (widget.onControllerCreated != null) {
      widget.onControllerCreated!(controller);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return _WizardControllerScope(
      controller: controller,
      enabled: TickerMode.of(context),
      child: widget.child,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
