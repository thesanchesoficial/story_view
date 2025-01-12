import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

import '../utils.dart';
import '../controller/story_controller.dart';
class VideoLoader {
  final String url;
  final Map<String, dynamic>? requestHeaders;
  LoadState state = LoadState.loading;

  File? videoFile;

  VideoLoader(this.url, {this.requestHeaders});

  void loadVideo(VoidCallback onComplete) {
    if (!kIsWeb) {
      if (videoFile != null) {
        state = LoadState.success;
        onComplete();
        return;
      }

      final fileStream = DefaultCacheManager().getFileStream(
        url,
        headers: requestHeaders as Map<String, String>?,
      );

      fileStream.listen((fileResponse) {
        if (fileResponse is FileInfo) {
          if (videoFile == null) {
            state = LoadState.success;
            videoFile = fileResponse.file;
            onComplete();
          }
        }
      }, onError: (error) {
        state = LoadState.failure;
        onComplete();
      });
    } else {
      state = LoadState.success;
      onComplete();
    }
  }
}

class StoryVideo extends StatefulWidget {
  final StoryController? storyController;
  final VideoLoader videoLoader;
  final Widget? loadingWidget;
  final Widget? errorWidget;

  const StoryVideo(
    this.videoLoader, {
    Key? key,
    this.storyController,
    this.loadingWidget,
    this.errorWidget,
  }) : super(key: key);

  /// Construtor de conveniência
  static StoryVideo url(
    String url, {
    StoryController? controller,
    Map<String, dynamic>? requestHeaders,
    Key? key,
    Widget? loadingWidget,
    Widget? errorWidget,
  }) {
    return StoryVideo(
      VideoLoader(url, requestHeaders: requestHeaders),
      storyController: controller,
      key: key,
      loadingWidget: loadingWidget,
      errorWidget: errorWidget,
    );
  }

  @override
  State<StatefulWidget> createState() => _StoryVideoState();
}

class _StoryVideoState extends State<StoryVideo> {
  StreamSubscription? _streamSubscription;
  VideoPlayerController? playerController;

  @override
  void initState() {
    super.initState();

    widget.storyController?.pause();

    widget.videoLoader.loadVideo(() {
      if (widget.videoLoader.state == LoadState.success) {
        if (!kIsWeb && widget.videoLoader.videoFile != null) {
          playerController = VideoPlayerController.file(
            widget.videoLoader.videoFile!,
          );
        } else {
          playerController = VideoPlayerController.networkUrl(
            Uri.parse(widget.videoLoader.url),
            httpHeaders: (widget.videoLoader.requestHeaders ?? {}).cast<String, String>(),
          );
        }

        playerController!.initialize().then((_) {
          setState(() {});
          widget.storyController?.play();
        });

        _streamSubscription = widget.storyController?.playbackNotifier.listen((playbackState) {
          if (playbackState == PlaybackState.pause) {
            playerController?.pause();
          } else {
            playerController?.play();
          }
        });
      } else {
        setState(() {});
      }
    });
  }

  Widget getContentView() {
    if (widget.videoLoader.state == LoadState.success &&
        (playerController?.value.isInitialized ?? false)) {
      return Center(
        child: AspectRatio(
          aspectRatio: playerController!.value.aspectRatio,
          child: VideoPlayer(playerController!),
        ),
      );
    }

    if (widget.videoLoader.state == LoadState.loading) {
      return Center(
        child: widget.loadingWidget ??
            const SizedBox(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
      );
    }

    return Center(
      child: widget.errorWidget ??
          const Text(
            "Media failed to load.",
            style: TextStyle(color: Colors.white),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: getContentView(),
    );
  }

  @override
  void dispose() {
    playerController?.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }
}
