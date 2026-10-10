import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Lecteur vidéo (fichier local ou URL). Tape pour lecture / pause.
class VideoView extends StatefulWidget {
  final String? path, url;
  const VideoView({super.key, this.path, this.url});
  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {
  VideoPlayerController? c;
  bool ready = false, failed = false;

  @override
  void initState() {
    super.initState();
    try {
      final ctrl = widget.path != null ? VideoPlayerController.file(File(widget.path!)) : VideoPlayerController.networkUrl(Uri.parse(widget.url!));
      c = ctrl;
      ctrl.initialize().then((_) {
        if (!mounted) return;
        ctrl.setLooping(true);
        ctrl.play();
        setState(() => ready = true);
      }).catchError((_) {
        if (mounted) setState(() => failed = true);
      });
    } catch (_) {
      failed = true;
    }
  }

  @override
  void dispose() {
    c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (failed) return Center(child: Text('Vidéo indisponible', style: TextStyle(color: Colors.white70)));
    if (!ready || c == null) return Center(child: CircularProgressIndicator());
    final ctrl = c!;
    return GestureDetector(
      onTap: () => setState(() => ctrl.value.isPlaying ? ctrl.pause() : ctrl.play()),
      child: Stack(alignment: Alignment.center, children: [
        AspectRatio(aspectRatio: ctrl.value.aspectRatio, child: VideoPlayer(ctrl)),
        if (!ctrl.value.isPlaying) Icon(Icons.play_circle_fill, size: 72, color: Colors.white70),
        Positioned(left: 0, right: 0, bottom: 0, child: VideoProgressIndicator(ctrl, allowScrubbing: true)),
      ]),
    );
  }
}
