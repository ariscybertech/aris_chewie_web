import 'dart:async';

import 'package:custom_chewie/src/custom_chewie_progress_colors.dart';
import 'package:custom_chewie/src/player_with_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

typedef Widget ChewieRoutePageBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    _ChewieControllerProvider controllerProvider);

/// A Video Player with Material and Cupertino skins.
///
/// `video_player` is pretty low level. Chewie wraps it in a friendly skin to
/// make it easy to use!
class Chewie extends StatefulWidget {
  /// The Controller for the Video you want to play
  VideoPlayerController controller;

  /// Function to execute before going into FullScreen
  final Function beforeFullScreen;

  /// Function to execute after exiting FullScreen
  final Function afterFullScreen;

  /// Initialize the Video on Startup. This will prep the video for playback.
  final bool autoInitialize;

  /// Play the video as soon as it's displayed
  final bool autoPlay;

  /// Start video at a certain position
  final Duration startAt;

  /// Whether or not the video should loop
  final bool looping;

  /// Whether or not to show the controls
  final bool showControls;

  /// The Aspect Ratio of the Video. Important to get the correct size of the
  /// video!
  ///
  /// Will fallback to fitting within the space allowed.
  final double aspectRatio;

  /// The colors to use for controls on iOS. By default, the iOS player uses
  /// colors sampled from the original iOS 11 designs.
  final ChewieProgressColors cupertinoProgressColors;

  /// The colors to use for the Material Progress Bar. By default, the Material
  /// player uses the colors from your Theme.
  final ChewieProgressColors materialProgressColors;

  /// The placeholder is displayed underneath the Video before it is initialized
  /// or played.
  final Widget placeholder;

  static VideoPlayerController of(BuildContext context) {
    final chewieControllerProvider =
        context.inheritFromWidgetOfExactType(_ChewieControllerProvider)
            as _ChewieControllerProvider;

    return chewieControllerProvider.controller;
  }

  Chewie(
    this.controller, {
    Key key,
    this.beforeFullScreen,
    this.afterFullScreen,
    this.aspectRatio,
    this.autoInitialize = false,
    this.autoPlay = false,
    this.startAt,
    this.looping = false,
    this.cupertinoProgressColors,
    this.materialProgressColors,
    this.placeholder,
    this.showControls = true,
  })  : assert(controller != null,
            'You must provide a controller to play a video'),
        super(key: key);

  @override
  State<StatefulWidget> createState() {
    return new _ChewiePlayerState();
  }
}

class _ChewiePlayerState extends State<Chewie> {
  // Whether it was on landscape before to not trigger it twice
  bool wasLandscape = false;
  double playerHeight;
  // Fullscreen button pressed
  bool leaveFullscreen = false;

  BuildContext videoContext;

  @override
  Widget build(BuildContext context) {
    // Start fullscreen on landscape
    final Orientation orientation = MediaQuery.of(context).orientation;
    final bool _isLandscape = false;
    // Lock orientation if exit fullscreen button was pressed
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    if (isAndroid && leaveFullscreen) {
      setState(() {
        playerHeight = null;
        wasLandscape = false;
      });
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    // Check whether we are in fullscreen already
    if (_isLandscape && !wasLandscape && !leaveFullscreen) {
      // Start fullscreen mode
      setState(() {
        playerHeight = 0.0;
      });
      _pushFullScreenWidget(context);
      wasLandscape = true;
    } else if (!_isLandscape && wasLandscape && !leaveFullscreen) {
      // End fullscreen mode
      setState(() {
        playerHeight = null;
        wasLandscape = false;
      });
      Navigator.of(context).pop();
    }
    return new Container(
      height: playerHeight,
      child: new PlayerWithControls(
        controller: widget.controller,
        onExpandCollapse: () => _pushFullScreenWidget(context),
        aspectRatio: widget.aspectRatio ?? _calculateAspectRatio(context),
        cupertinoProgressColors: widget.cupertinoProgressColors,
        materialProgressColors: widget.materialProgressColors,
        placeholder: widget.placeholder,
        autoPlay: widget.autoPlay,
        showControls: widget.showControls,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Widget _buildFullScreenVideo(
      BuildContext context,
      Animation<double> animation,
      _ChewieControllerProvider controllerProvider) {
    videoContext = context;
    return new Scaffold(
      resizeToAvoidBottomPadding: false,
      body: new Container(
          alignment: Alignment.center,
          color: Colors.black,
          child: controllerProvider),
    );
  }

  AnimatedWidget _defaultRoutePageBuilder(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      _ChewieControllerProvider controllerProvider) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget child) {
        return _buildFullScreenVideo(context, animation, controllerProvider);
      },
    );
  }

  Widget _fullScreenRoutePageBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    var controllerProvider = _ChewieControllerProvider(
      controller: widget.controller,
      child: new PlayerWithControls(
        controller: widget.controller,
        onExpandCollapse: () {
          Navigator.of(context).pop();
          leaveFullscreen = true;
        },
        aspectRatio: widget.aspectRatio ?? _calculateAspectRatio(context),
        fullScreen: true,
        cupertinoProgressColors: widget.cupertinoProgressColors,
        materialProgressColors: widget.materialProgressColors,
      ),
    );

    return _defaultRoutePageBuilder(
        context, animation, secondaryAnimation, controllerProvider);
  }

  Future _initialize() async {
    await widget.controller.setLooping(widget.looping);

    if (widget.autoInitialize || widget.autoPlay) {
      await widget.controller.initialize();
    }

    if (widget.autoPlay) {
      await widget.controller.play();
    }

    if (widget.startAt != null) {
      await widget.controller.seekTo(widget.startAt);
    }
  }

  @override
  void didUpdateWidget(Chewie oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller.dataSource != widget.controller.dataSource) {
      widget.controller.dispose();
      widget.controller = widget.controller;
      _initialize();
    }
  }

  @override
  dispose() {
    if (widget.controller?.value.initialized) widget.controller?.pause();
    super.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  Future<dynamic> _pushFullScreenWidget(BuildContext context) async {
    leaveFullscreen = false;
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final TransitionRoute<Null> route = new PageRouteBuilder<Null>(
      settings: new RouteSettings(),
      pageBuilder: _fullScreenRoutePageBuilder,
    );

    SystemChrome.setEnabledSystemUIOverlays([]);
    if (isAndroid) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    widget.beforeFullScreen();

    await Navigator.of(context, rootNavigator: true).push(route);

    widget.afterFullScreen();

    SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  double _calculateAspectRatio(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    return width > height ? width / height : height / width;
  }
}

class _ChewieControllerProvider extends InheritedWidget {
  const _ChewieControllerProvider({
    Key key,
    @required this.controller,
    @required Widget child,
  })  : assert(controller != null),
        assert(child != null),
        super(key: key, child: child);

  final VideoPlayerController controller;

  @override
  bool updateShouldNotify(_ChewieControllerProvider old) =>
      controller != old.controller;
}
