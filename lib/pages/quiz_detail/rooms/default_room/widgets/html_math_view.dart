import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum DefaultRoomHtmlViewMode { autoHeight, fill }

class DefaultRoomHtmlView extends StatefulWidget {
  const DefaultRoomHtmlView({
    super.key,
    required this.html,
    this.mode = DefaultRoomHtmlViewMode.autoHeight,
    this.fontSize = 15,
    this.minHeight = 28,
    this.maxAutoHeight = 1200,
  });

  final String html;
  final DefaultRoomHtmlViewMode mode;
  final double fontSize;
  final double minHeight;
  final double maxAutoHeight;

  @override
  State<DefaultRoomHtmlView> createState() => _DefaultRoomHtmlViewState();
}

class _DefaultRoomHtmlViewState extends State<DefaultRoomHtmlView> {
  late final WebViewController _controller;
  double _height = 56;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _height = widget.minHeight.clamp(20, widget.maxAutoHeight).toDouble();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.startsWith('about:blank') ||
                url.startsWith('data:text/html')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
          onPageFinished: (_) {
            _loaded = true;
            _requestHeightUpdate();
          },
        ),
      )
      ..addJavaScriptChannel(
        'HeightChannel',
        onMessageReceived: (message) {
          final next = double.tryParse(message.message);
          if (next == null || !mounted) {
            return;
          }
          final safe = next
              .clamp(widget.minHeight, widget.maxAutoHeight)
              .toDouble();
          if ((safe - _height).abs() < 0.8) {
            return;
          }
          setState(() {
            _height = safe;
          });
        },
      );
    _loadHtml();
  }

  @override
  void didUpdateWidget(covariant DefaultRoomHtmlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html ||
        oldWidget.fontSize != widget.fontSize) {
      _loadHtml();
    }
  }

  Future<void> _loadHtml() async {
    _loaded = false;
    await _controller.loadHtmlString(
      _buildWrappedHtml(widget.html, widget.fontSize),
    );
  }

  void _requestHeightUpdate() {
    if (!_loaded || widget.mode == DefaultRoomHtmlViewMode.fill) {
      return;
    }
    _controller.runJavaScript('''
      (function () {
        const h = Math.max(
          document.body ? document.body.scrollHeight : 0,
          document.documentElement ? document.documentElement.scrollHeight : 0
        );
        if (window.HeightChannel && typeof window.HeightChannel.postMessage === 'function') {
          window.HeightChannel.postMessage(String(h));
        }
      })();
      ''');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == DefaultRoomHtmlViewMode.fill) {
      return ClipRect(child: WebViewWidget(controller: _controller));
    }

    return SizedBox(
      height: _height,
      child: ClipRect(child: WebViewWidget(controller: _controller)),
    );
  }

  String _buildWrappedHtml(String rawHtml, double fontSize) {
    final bodyHtml = rawHtml.trim().isNotEmpty ? rawHtml : '<p></p>';
    final hasMath = rawHtml.contains('<math') || rawHtml.contains('<mrow');
    final mathJaxScript = hasMath
        ? '<script async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/mml-chtml.js"></script>'
        : '';
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta
    name="viewport"
    content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover"
  />
  <style>
    :root {
      color-scheme: light;
    }

    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      max-width: 100%;
      overflow-x: hidden;
      overflow-y: auto;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      font-size: ${fontSize.toStringAsFixed(2)}px;
      line-height: 1.5;
      color: #1f2937;
      background: transparent;
      -webkit-text-size-adjust: 100%;
    }

    * {
      box-sizing: border-box;
    }

    body > * {
      max-width: 100%;
    }

    p, div, li, td, th {
      overflow-wrap: anywhere;
      word-break: normal;
      white-space: normal;
    }

    span {
      word-break: normal;
      overflow-wrap: normal;
    }

    img, svg, video, canvas {
      max-width: 100%;
      height: auto;
    }

    table {
      width: 100%;
      border-collapse: collapse;
      display: block;
      overflow-x: auto;
    }

    math, mrow, mi, mn, mo, msup, msub, msubsup, mfrac, msqrt, mroot, mtable, mtr, mtd, mtext {
      white-space: nowrap !important;
      writing-mode: horizontal-tb !important;
      text-orientation: mixed !important;
      direction: ltr !important;
      unicode-bidi: isolate !important;
    }

    math[display="block"] {
      display: block;
      width: 100%;
      overflow-x: auto;
      overflow-y: hidden;
      padding: 2px 0;
    }

    mjx-container, mjx-container * {
      writing-mode: horizontal-tb !important;
      text-orientation: mixed !important;
      white-space: nowrap !important;
      word-break: normal !important;
      overflow-wrap: normal !important;
      direction: ltr !important;
      unicode-bidi: isolate !important;
      max-width: 100%;
    }

    mjx-container[display="true"] {
      display: block;
      overflow-x: auto;
      overflow-y: hidden;
    }
  </style>
  <script>
    (function () {
      try {
        const storageProbe = window.localStorage;
        void storageProbe;
      } catch (_) {
        const memoryStorage = {
          getItem: function () { return null; },
          setItem: function () {},
          removeItem: function () {},
          clear: function () {},
          key: function () { return null; },
          length: 0
        };

        Object.defineProperty(window, 'localStorage', {
          value: memoryStorage,
          configurable: true,
        });

        Object.defineProperty(window, 'sessionStorage', {
          value: memoryStorage,
          configurable: true,
        });
      }
    })();

    window.MathJax = {
      options: {
        enableMenu: false,
        renderActions: { addMenu: [] }
      },
      chtml: { scale: 1 }
    };
  </script>
  $mathJaxScript
</head>
<body>
  $bodyHtml
  <script>
    (function () {
      function reportHeight() {
        var h = Math.max(
          document.body ? document.body.scrollHeight : 0,
          document.documentElement ? document.documentElement.scrollHeight : 0
        );
        if (window.HeightChannel && typeof window.HeightChannel.postMessage === 'function') {
          window.HeightChannel.postMessage(String(h));
        }
      }

      window.addEventListener('load', function () {
        reportHeight();
        setTimeout(reportHeight, 80);
        setTimeout(reportHeight, 240);
        setTimeout(reportHeight, 500);
      });

      var observer = new MutationObserver(function () {
        reportHeight();
      });

      observer.observe(document.body, {
        subtree: true,
        childList: true,
        characterData: true,
        attributes: true
      });
    })();
  </script>
</body>
</html>
''';
  }
}
