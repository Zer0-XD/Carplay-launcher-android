import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/media_provider.dart';
import '../../../data/services/media_service.dart';
import 'base_card.dart';

class MediaCard extends StatelessWidget {
  const MediaCard({
    super.key,
    this.isEditing = false,
    this.onLongPress,
    this.isLarge = false,
  });

  final bool isEditing;
  final VoidCallback? onLongPress;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaProvider>();
    final accent = Theme.of(context).colorScheme.primary;

    if (!media.permissionGranted) {
      return _PermissionPrompt(
        isEditing: isEditing,
        onLongPress: onLongPress,
        accent: accent,
        onGrant: media.requestPermission,
      );
    }

    return BaseCard(
      isEditing: isEditing,
      onLongPress: onLongPress,
      padding: EdgeInsets.zero,
      accentColor: accent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final s = (constraints.smallest.shortestSide / 200.0).clamp(0.5, 2.0);
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final wide = w > h * 1.3;
          // Use tiny layout whenever height can't fit a full media layout
          final tiny = h < 220 || w < 160;
          if (tiny) {
            return _TinyMedia(info: media.info, accent: accent, media: media, s: s);
          }
          return wide
              ? _WideMedia(info: media.info, accent: accent, media: media, s: s)
              : _CompactMedia(info: media.info, accent: accent, media: media, s: s);
        },
      ),
    );
  }
}

// ── Permission prompt ─────────────────────────────────────────────────────────

class _PermissionPrompt extends StatelessWidget {
  const _PermissionPrompt({
    required this.isEditing, required this.onLongPress,
    required this.accent, required this.onGrant,
  });
  final bool isEditing;
  final VoidCallback? onLongPress;
  final Color accent;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BaseCard(
      isEditing: isEditing,
      onLongPress: onLongPress,
      accentColor: accent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_off_rounded, color: scheme.onSurfaceVariant, size: 28),
          const SizedBox(height: 10),
          Text(
            'Notification access needed',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onGrant,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Grant Access',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tiny media (small slot: art + title + play button only) ──────────────────

class _TinyMedia extends StatelessWidget {
  const _TinyMedia({required this.info, required this.accent, required this.media, required this.s});
  final MediaInfo info;
  final Color accent;
  final MediaProvider media;
  final double s;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Blurred art background
        if (info.albumArt != null)
          Positioned.fill(
            child: Image.memory(
              info.albumArt!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              cacheWidth: 200,
            ),
          ),
        // Dark scrim
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(120),
                  Colors.black.withAlpha(210),
                ],
              ),
            ),
          ),
        ),
        // Content: art thumb on left, title + play on right
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // Square art thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: info.albumArt != null
                      ? Image.memory(info.albumArt!, fit: BoxFit.cover, gaplessPlayback: true)
                      : ColoredBox(
                          color: Colors.black26,
                          child: Icon(Icons.music_note_rounded, size: 20, color: accent.withAlpha(160)),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              // Title
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.hasContent ? info.title : 'Nothing playing',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (info.artist.isNotEmpty)
                      Text(
                        info.artist,
                        style: TextStyle(fontSize: 10, color: Colors.white.withAlpha(130)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Controls: prev + play/pause + next — all 48px minimum touch targets
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TinyBtn(
                    onTap: () => context.read<MediaProvider>().previous(),
                    child: Icon(Icons.skip_previous_rounded, color: Colors.white.withAlpha(200), size: 28),
                  ),
                  GestureDetector(
                    onTap: () => context.read<MediaProvider>().playPause(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                      child: Icon(
                        info.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  _TinyBtn(
                    onTap: () => context.read<MediaProvider>().next(),
                    child: Icon(Icons.skip_next_rounded, color: Colors.white.withAlpha(200), size: 28),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Wide media (album art background + controls) ──────────────────────────────

class _WideMedia extends StatelessWidget {
  const _WideMedia({required this.info, required this.accent, required this.media, required this.s});
  final MediaInfo info;
  final Color accent;
  final MediaProvider media;
  final double s;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Album art full bleed
        if (info.albumArt != null)
          Image.memory(
            info.albumArt!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: 400,
          ),

        // Dark scrim — stronger at bottom so text is always readable
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.3, 0.65, 1.0],
                colors: [
                  Colors.black.withAlpha(40),
                  Colors.black.withAlpha(100),
                  Colors.black.withAlpha(200),
                  Colors.black.withAlpha(240),
                ],
              ),
            ),
          ),
        ),

        // Content pinned to bottom
        Padding(
          padding: EdgeInsets.all(16 * s),
          child: Column(
            children: [
              // Top row — badge + source icon
              Row(
                children: [
                  if (info.hasContent)
                    _NowPlayingBadge(accent: accent, s: s),
                  const Spacer(),
                  Icon(Icons.music_note_rounded,
                      size: 14 * s, color: Colors.white.withAlpha(70)),
                ],
              ),
              const Spacer(),
              // Centered art thumb
              _ArtCircle(info: info, accent: accent, size: 96 * s),
              SizedBox(height: 14 * s),
              // Title + artist
              _MarqueeText(
                text: info.hasContent ? info.title : 'Nothing playing',
                style: TextStyle(
                  fontSize: 20 * s, fontWeight: FontWeight.w700,
                  color: Colors.white, height: 1.1,
                ),
              ),
              SizedBox(height: 4 * s),
              Text(
                info.artist.isNotEmpty ? info.artist : '—',
                style: TextStyle(
                  fontSize: 12 * s, color: Colors.white.withAlpha(130),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 12 * s),
              // Scrub bar
              _ScrubBar(info: info, accent: accent, s: s),
              SizedBox(height: 18 * s),
              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Btn(icon: Icons.skip_previous_rounded, size: 30 * s,
                      onTap: () => context.read<MediaProvider>().previous()),
                  SizedBox(width: 20 * s),
                  _PlayBtn(isPlaying: info.isPlaying, accent: accent, s: s,
                      onTap: () => context.read<MediaProvider>().playPause()),
                  SizedBox(width: 20 * s),
                  _Btn(icon: Icons.skip_next_rounded, size: 30 * s,
                      onTap: () => context.read<MediaProvider>().next()),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Compact media (side-by-side thumb + info) ─────────────────────────────────

class _CompactMedia extends StatelessWidget {
  const _CompactMedia({required this.info, required this.accent, required this.media, required this.s});
  final MediaInfo info;
  final Color accent;
  final MediaProvider media;
  final double s;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Blurred album art hint behind left scrim
        if (info.albumArt != null)
          Positioned.fill(
            child: Image.memory(
              info.albumArt!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              cacheWidth: 320,
            ),
          ),

        // Left-to-right dark gradient so right side is usable
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0.0, 0.45, 0.75, 1.0],
                colors: [
                  Colors.black.withAlpha(180),
                  Colors.black.withAlpha(200),
                  Colors.black.withAlpha(210),
                  Colors.black.withAlpha(220),
                ],
              ),
            ),
          ),
        ),

        // Content
        Padding(
          padding: EdgeInsets.fromLTRB(14 * s, 12 * s, 14 * s, 12 * s),
          child: Row(
            children: [
              // Thumbnail
              _ArtSquare(info: info, accent: accent, size: 68 * s),
              SizedBox(width: 12 * s),
              // Info + controls
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (info.hasContent && info.artist.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: 4 * s),
                        child: _NowPlayingBadge(accent: accent, s: s),
                      ),
                    _MarqueeText(
                      text: info.hasContent ? info.title : 'Nothing playing',
                      style: TextStyle(
                        fontSize: 15 * s, fontWeight: FontWeight.w700,
                        color: Colors.white, height: 1.1,
                      ),
                    ),
                    SizedBox(height: 3 * s),
                    Text(
                      info.artist.isNotEmpty ? info.artist : '—',
                      style: TextStyle(
                        fontSize: 11 * s, color: Colors.white.withAlpha(130),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 10 * s),
                    _MiniProgress(info: info, accent: accent),
                    SizedBox(height: 10 * s),
                    Row(
                      children: [
                        _Btn(icon: Icons.skip_previous_rounded, size: 26 * s,
                            onTap: () => context.read<MediaProvider>().previous()),
                        SizedBox(width: 12 * s),
                        _PlayBtn(isPlaying: info.isPlaying, accent: accent, s: s,
                            onTap: () => context.read<MediaProvider>().playPause()),
                        SizedBox(width: 12 * s),
                        _Btn(icon: Icons.skip_next_rounded, size: 26 * s,
                            onTap: () => context.read<MediaProvider>().next()),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Art circle (large view) ───────────────────────────────────────────────────

class _ArtCircle extends StatelessWidget {
  const _ArtCircle({required this.info, required this.accent, required this.size});
  final MediaInfo info;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasArt = info.albumArt != null;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(150), blurRadius: 24, offset: const Offset(0, 8)),
          BoxShadow(color: accent.withAlpha(hasArt ? 35 : 60), blurRadius: 20, spreadRadius: 1),
        ],
      ),
      child: ClipOval(
        child: hasArt
            ? Image.memory(info.albumArt!, fit: BoxFit.cover, gaplessPlayback: true)
            : ColoredBox(
                color: Colors.black26,
                child: Center(child: Icon(Icons.music_note_rounded, size: size * 0.4, color: accent.withAlpha(160))),
              ),
      ),
    );
  }
}

// ── Art square (compact thumb) ────────────────────────────────────────────────

class _ArtSquare extends StatelessWidget {
  const _ArtSquare({required this.info, required this.accent, required this.size});
  final MediaInfo info;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasArt = info.albumArt != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size, height: size,
        child: hasArt
            ? Image.memory(info.albumArt!, fit: BoxFit.cover, gaplessPlayback: true)
            : ColoredBox(
                color: Colors.black26,
                child: Center(child: Icon(Icons.music_note_rounded,
                    size: size * 0.44, color: accent.withAlpha(160))),
              ),
      ),
    );
  }
}

// ── Now-playing badge ─────────────────────────────────────────────────────────

class _NowPlayingBadge extends StatelessWidget {
  const _NowPlayingBadge({required this.accent, required this.s});
  final Color accent;
  final double s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7 * s, vertical: 3 * s),
      decoration: BoxDecoration(
        color: accent.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withAlpha(60), width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4 * s, height: 4 * s,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          SizedBox(width: 4 * s),
          Text(
            'NOW PLAYING',
            style: TextStyle(
              fontSize: 7 * s, fontWeight: FontWeight.w700,
              letterSpacing: 1.2, color: Colors.white.withAlpha(160),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Full scrub bar ────────────────────────────────────────────────────────────

class _ScrubBar extends StatefulWidget {
  const _ScrubBar({required this.info, required this.accent, required this.s});
  final MediaInfo info;
  final Color accent;
  final double s;

  @override
  State<_ScrubBar> createState() => _ScrubBarState();
}

class _ScrubBarState extends State<_ScrubBar> {
  double? _drag;
  bool _dragging = false;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _seek(double f) {
    final ms = (f * widget.info.duration.inMilliseconds).round();
    context.read<MediaProvider>().seekTo(Duration(milliseconds: ms));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final total = widget.info.duration.inMilliseconds;
    final pos = widget.info.position.inMilliseconds;
    final committed = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;
    final displayed = _drag ?? committed;
    final dispPos = _dragging
        ? Duration(milliseconds: (displayed * total).round())
        : widget.info.position;

    return Column(
      children: [
        LayoutBuilder(builder: (_, c) {
          final w = c.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => setState(() => _dragging = true),
            onHorizontalDragUpdate: (d) =>
                setState(() => _drag = (d.localPosition.dx / w).clamp(0.0, 1.0)),
            onHorizontalDragEnd: (_) {
              if (_drag != null) _seek(_drag!);
              setState(() { _dragging = false; _drag = null; });
            },
            onTapUp: (d) => _seek((d.localPosition.dx / w).clamp(0.0, 1.0)),
            child: SizedBox(
              height: 24,
              child: Stack(alignment: Alignment.centerLeft, children: [
                // Track
                Positioned.fill(
                  top: 10, bottom: 10,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Container(color: Colors.white.withAlpha(40)),
                  ),
                ),
                // Fill
                Positioned(
                  left: 0, top: 10, bottom: 10,
                  child: AnimatedContainer(
                    duration: _dragging ? Duration.zero : const Duration(milliseconds: 300),
                    width: (w * displayed).clamp(0.0, w),
                    decoration: BoxDecoration(
                      color: widget.accent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                // Thumb
                Positioned(
                  left: (w * displayed).clamp(0, w) - (_dragging ? 9 : 6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: _dragging ? 18 : 12,
                    height: _dragging ? 18 : 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: widget.accent.withAlpha(180), blurRadius: 8)],
                    ),
                  ),
                ),
              ]),
            ),
          );
        }),
        SizedBox(height: 3 * s),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmt(dispPos),
              style: TextStyle(fontSize: 9 * s, color: Colors.white.withAlpha(90))),
            Text(_fmt(widget.info.duration),
              style: TextStyle(fontSize: 9 * s, color: Colors.white.withAlpha(55))),
          ],
        ),
      ],
    );
  }
}

// ── Mini progress bar (compact card) ─────────────────────────────────────────

class _MiniProgress extends StatelessWidget {
  const _MiniProgress({required this.info, required this.accent});
  final MediaInfo info;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final total = info.duration.inMilliseconds;
    final pos = info.position.inMilliseconds;
    final progress = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;

    return LayoutBuilder(builder: (_, c) => ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 3,
        child: Stack(children: [
          Container(color: Colors.white.withAlpha(40)),
          AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            curve: Curves.linear,
            width: c.maxWidth * progress,
            color: accent,
          ),
        ]),
      ),
    ));
  }
}

// ── Marquee text ──────────────────────────────────────────────────────────────

class _MarqueeText extends StatefulWidget {
  const _MarqueeText({required this.text, required this.style});
  final String text;
  final TextStyle style;

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _textW = 0, _containerW = 0;
  bool _needsScroll = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 6));
    _anim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.linear));
  }

  @override
  void didUpdateWidget(_MarqueeText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _textW = 0;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _measure(double cw) {
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    _textW = tp.width;
    _containerW = cw;
    _needsScroll = _textW > cw;
    if (_needsScroll) {
      _ctrl.repeat(
        period: Duration(
          milliseconds: ((_textW / 40) * 1000).toInt().clamp(3000, 10000),
        ),
      );
    } else {
      _ctrl.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      if (_textW == 0 || _containerW != c.maxWidth) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) { if (mounted) setState(() => _measure(c.maxWidth)); });
      }
      if (!_needsScroll) {
        return Text(widget.text, style: widget.style, maxLines: 1,
            overflow: TextOverflow.ellipsis);
      }
      return ClipRect(
        child: AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => Transform.translate(
            offset: Offset(-_anim.value * (_textW - _containerW + 20), 0),
            child: Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
          ),
        ),
      );
    });
  }
}

// ── Minimum-48px hit area for icon buttons ────────────────────────────────────

class _TinyBtn extends StatelessWidget {
  const _TinyBtn({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: SizedBox(width: 48, height: 48, child: Center(child: child)),
  );
}

// ── Control button ────────────────────────────────────────────────────────────

class _Btn extends StatelessWidget {
  const _Btn({required this.icon, required this.size, required this.onTap});
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: SizedBox(
      width: size.clamp(48.0, 72.0),
      height: size.clamp(48.0, 72.0),
      child: Center(child: Icon(icon, size: size, color: Colors.white.withAlpha(200))),
    ),
  );
}

// ── Play/pause button ─────────────────────────────────────────────────────────

class _PlayBtn extends StatelessWidget {
  const _PlayBtn({
    required this.isPlaying, required this.accent,
    required this.s, required this.onTap,
  });
  final bool isPlaying;
  final Color accent;
  final double s;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: (48 * s).clamp(48.0, 72.0),
      height: (48 * s).clamp(48.0, 72.0),
      decoration: BoxDecoration(
        color: accent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: accent.withAlpha(140), blurRadius: 16, spreadRadius: 1),
        ],
      ),
      child: Icon(
        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        color: Colors.white,
        size: 26 * s,
      ),
    ),
  );
}
