import 'dart:convert';
import 'dart:math';

import 'package:chewie/chewie.dart';
import 'package:chewie_audio/chewie_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_html/html_parser.dart';
import 'package:flutter_html/src/html_elements.dart';
import 'package:flutter_html/style.dart';
import 'package:html/dom.dart' as dom;

/// A [ReplacedElement] is a type of [StyledElement] that does not require its [children] to be rendered.
///
/// A [ReplacedElement] may use its children nodes to determine relevant information
/// (e.g. <video>'s <source> tags), but the children nodes will not be saved as [children].
abstract class ReplacedElement extends StyledElement {
  PlaceholderAlignment alignment;

  ReplacedElement(
      {String name,
      Style style,
      dom.Element node,
      this.alignment = PlaceholderAlignment.aboveBaseline})
      : super(name: name, children: null, style: style, node: node);

  static List<String> parseMediaSources(List<dom.Element> elements) {
    return elements
        .where((element) => element.localName == 'source')
        .map((element) {
      return element.attributes['src'];
    }).toList();
  }

  Widget toWidget(RenderContext context);
}

/// [TextContentElement] is a [ContentElement] with plaintext as its content.
class TextContentElement extends ReplacedElement {
  String text;

  TextContentElement({
    Style style,
    this.text,
  }) : super(name: "[text]", style: style);

  @override
  String toString() {
    return "\"${text.replaceAll("\n", "\\n")}\"";
  }

  @override
  Widget toWidget(_) => null;
}

/// [ImageContentElement] is a [ReplacedElement] with an image as its content.
/// https://developer.mozilla.org/en-US/docs/Web/HTML/Element/img
class ImageContentElement extends ReplacedElement {
  final String src;
  final String alt;

  ImageContentElement({
    String name,
    Style style,
    this.src,
    this.alt,
    dom.Element node,
  }) : super(name: name, style: style, node: node);

  @override
  Widget toWidget(RenderContext context) {
    if (src == null) {
      return Text(alt ?? "", style: context.style.generateTextStyle());
    } else if (src.startsWith("data:image") && src.contains("base64,")) {
      return Image.memory(base64.decode(src.split("base64,")[1].trim()));
    } else if(src.startsWith("asset:")) {
      final assetPath = src.replaceFirst('asset:', '');
      //TODO precache image
      return Image.asset(
        assetPath,
        frameBuilder: (ctx, child, frame, _) {
          if(frame == null) {
            return Text(alt ?? "", style: context.style.generateTextStyle());
          }
          return child;
        },
      );
    } else {
      //TODO precache image
      return Image.network(
        src,
        frameBuilder: (ctx, child, frame, _) {
          if (frame == null) {
            return Text(alt ?? "", style: context.style.generateTextStyle());
          }
          return child;
        },
      );
    }
  }
}

/// [IframeContentElement is a [ReplacedElement] with web content.
class IframeContentElement extends ReplacedElement {
  final String src;
  final double width;
  final double height;

  IframeContentElement({
    String name,
    Style style,
    this.src,
    this.width,
    this.height,
    dom.Element node,
  }) : super(name: name, style: style, node: node);

  @override
  Widget toWidget(RenderContext context) {
    return Container(
      width: width ?? (height ?? 150) * 2,
      height: height ?? (width ?? 300) / 2,
      child: WebView(
        initialUrl: src,
        javascriptMode: JavascriptMode.unrestricted,
        gestureRecognizers: {
          Factory(() => PlatformViewVerticalGestureRecognizer())
        },
      ),
    );
  }
}

/// [AudioContentElement] is a [ContentElement] with an audio file as its content.
class AudioContentElement extends ReplacedElement {
  final List<String> src;
  final bool showControls;
  final bool autoplay;
  final bool loop;
  final bool muted;

  AudioContentElement({
    String name,
    Style style,
    this.src,
    this.showControls,
    this.autoplay,
    this.loop,
    this.muted,
    dom.Element node,
  }) : super(name: name, style: style, node: node);

  @override
  Widget toWidget(RenderContext context) {
    return Container(
      width: context.style.width ?? 300,
      child: ChewieAudio(
        controller: ChewieAudioController(
          videoPlayerController: VideoPlayerController.network(
            src.first ?? "",
          ),
          autoPlay: autoplay,
          looping: loop,
          showControls: showControls,
          autoInitialize: true,
        ),
      ),
    );
  }
}

/// [VideoContentElement] is a [ContentElement] with a video file as its content.
class VideoContentElement extends ReplacedElement {
  final List<String> src;
  final String poster;
  final bool showControls;
  final bool autoplay;
  final bool loop;
  final bool muted;
  final double width;
  final double height;

  VideoContentElement({
    String name,
    Style style,
    this.src,
    this.poster,
    this.showControls,
    this.autoplay,
    this.loop,
    this.muted,
    this.width,
    this.height,
    dom.Element node,
  }) : super(name: name, style: style, node: node);

  @override
  Widget toWidget(RenderContext context) {
    return Container(
      width: width ?? (height ?? 150) * 2,
      height: height ?? (width ?? 300) / 2,
      child: Chewie(
        controller: ChewieController(
          videoPlayerController: VideoPlayerController.network(
            src.first ?? "",
          ),
          placeholder: poster != null
              ? Image.network(poster)
              : Container(color: Colors.black),
          autoPlay: autoplay,
          looping: loop,
          showControls: showControls,
          autoInitialize: true,
        ),
      ),
    );
  }
}

/// [SvgContentElement] is a [ReplacedElement] with an SVG as its contents.
class SvgContentElement extends ReplacedElement {
  final String data;
  final double width;
  final double height;

  SvgContentElement({
    this.data,
    this.width,
    this.height,
  });

  @override
  Widget toWidget(RenderContext context) {
    return SvgPicture.string(
      data,
      width: width,
      height: height,
    );
  }
}

class EmptyContentElement extends ReplacedElement {
  EmptyContentElement({String name = "empty"}) : super(name: name);

  @override
  Widget toWidget(_) => null;
}

//TODO(Sub6Resources): <ruby> formatting should adhere to
// the most recent CSS WD specification: https://drafts.csswg.org/css-ruby/
class RubyElement extends ReplacedElement {
  dom.Element element;

  RubyElement({@required this.element, String name = "ruby"})
      : super(name: name, alignment: PlaceholderAlignment.middle);

  static RubyElementInfo parseRuby(dom.Node root) {
    final RubyElementInfo info = RubyElementInfo();
    if(root.parent.localName != 'ruby') {
      dom.Node currentParent = root;
      int index = 0;
      int startIndex;
      int savedStartIndex;
      int lookaheadIndex;

      BaseTextSegment currentBaseText;

      //Start mode
      if(index >= currentParent.children.length) {
        //Jump to end mode

      }

      if(currentParent.children[index].localName == 'rt' || currentParent.children[index].localName == 'rp') {
        //Jump to annotation mode

      }

      startIndex = index;

      //Base mode
      if(currentParent.children[index].localName == 'ruby' && currentParent == root) {
        currentParent = currentParent.children[index];
        index = 0;
        savedStartIndex = startIndex;
        startIndex = null;
        //Jump to start mode

      }

      if(currentParent.children[index].localName == 'rt' || currentParent.children[index].localName == 'rp') {
        BaseTextSegment newBaseTextSegment = BaseTextSegment();
        newBaseTextSegment.baseText = List<dom.Node>();
        for(int i = startIndex; i < index; i++) {
          newBaseTextSegment.baseText.add(currentParent.children[i]);
        }
        currentBaseText = newBaseTextSegment;
        info.baseTextSegments.add(newBaseTextSegment);
        //Jump to annotation mode
      }

      index++;

      //Base mode post-increment
      if(index >= currentParent.children.length) {
        //Jump to end mode
      }

      // Jump back to base mode

      //Annotation mode
      if(currentParent.children[index].localName == 'rt') {
        final rt = currentParent.children[index];
        AnnotationSegment annotationSegment = AnnotationSegment();
        annotationSegment.annotation = [rt];
        if(currentBaseText != null) {
          annotationSegment.segment = currentBaseText;
        }
        info.annotationSegments.add(annotationSegment);
        //Jump to annotation mode increment
      }

      if(currentParent.children[index].localName == 'rp') {
        //Jump to annotation mode increment
      }

      if(currentParent.children[index] is! dom.Text || (currentParent.children[index] is dom.Text && currentParent.children[index].text.trim().isNotEmpty)) {
        //Jump to base mode
      }

      //Annotation mode increment
      lookaheadIndex = index + 1;

      //Annotation mode white-space skipper
      if(lookaheadIndex == currentParent.children.length) {
        //Jump to end mode
      }

      if(currentParent.children[lookaheadIndex].localName == 'rt' || currentParent.children[lookaheadIndex].localName == 'rp') {
        index = lookaheadIndex;
        //Jump to annotation mode
      }

      if(currentParent.children[lookaheadIndex] is! dom.Text || (currentParent.children[lookaheadIndex] is dom.Text && currentParent.children[lookaheadIndex].text.trim().isNotEmpty)) {
        //Jump to base mode (without incrementing index)
      }
      lookaheadIndex++;

      //Jump to annotation mode white space skipper

      //End mode
      if(currentParent != root) {
        index = root.children.indexOf(currentParent);
        currentParent = root;
        index++;
        startIndex = savedStartIndex;
        savedStartIndex = null;
        //Jump to base mode post increment.
      }

    }

    //End
    return info;
  }

  @override
  Widget toWidget(RenderContext context) {
    dom.Node textNode;
    List<Widget> widgets = List<Widget>();
    //TODO calculate based off of parent font size.
    final rubySize = context.style.fontSize.size / 2;
    final rubyYPos = rubySize + 4;
    element.nodes.forEach((c) {
      if (c.nodeType == dom.Node.TEXT_NODE) {
        textNode = c;
      }
      if (c is dom.Element) {
        if (c.localName == "rt" && textNode != null) {
          final widget = Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                  alignment: Alignment.bottomCenter,
                  child: Center(
                      child: Transform(
                          transform:
                              Matrix4.translationValues(0, -(rubyYPos), 0),
                          child: Text(c.innerHtml,
                              style: context.style
                                  .generateTextStyle()
                                  .copyWith(fontSize: rubySize))))),
              Container(
                  child: Text(textNode.text.trim(),
                      style: context.style.generateTextStyle())),
            ],
          );
          widgets.add(widget);
        }
      }
    });
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }
}

class RubyElementInfo {
  List<BaseTextSegment> baseTextSegments;
  List<AnnotationSegment> annotationSegments;

  RubyElementInfo() {
    baseTextSegments = List<BaseTextSegment>();
    annotationSegments = List<AnnotationSegment>();
  }
}

class BaseTextSegment {
  List<BaseTextSegment> subSegments;
  List<dom.Node> baseText;
}

class AnnotationSegment {
  List<dom.Node> annotation;
  BaseTextSegment segment;
}

ReplacedElement parseReplacedElement(dom.Element element) {
  switch (element.localName) {
    case "audio":
      final sources = <String>[
        if (element.attributes['src'] != null) element.attributes['src'],
        ...ReplacedElement.parseMediaSources(element.children),
      ];
      return AudioContentElement(
        name: "audio",
        src: sources,
        showControls: element.attributes['controls'] != null,
        loop: element.attributes['loop'] != null,
        autoplay: element.attributes['autoplay'] != null,
        muted: element.attributes['muted'] != null,
        node: element,
      );
    case "br":
      return TextContentElement(
        text: "\n",
        style: Style(whiteSpace: WhiteSpace.PRE),
      );
    case "iframe":
      return IframeContentElement(
        name: "iframe",
        src: element.attributes['src'],
        width: double.tryParse(element.attributes['width'] ?? ""),
        height: double.tryParse(element.attributes['height'] ?? ""),
      );
    case "img":
      return ImageContentElement(
        name: "img",
        src: element.attributes['src'],
        alt: element.attributes['alt'],
        node: element,
      );
    case "video":
      final sources = <String>[
        if (element.attributes['src'] != null) element.attributes['src'],
        ...ReplacedElement.parseMediaSources(element.children),
      ];
      return VideoContentElement(
        name: "video",
        src: sources,
        poster: element.attributes['poster'],
        showControls: element.attributes['controls'] != null,
        loop: element.attributes['loop'] != null,
        autoplay: element.attributes['autoplay'] != null,
        muted: element.attributes['muted'] != null,
        width: double.tryParse(element.attributes['width'] ?? ""),
        height: double.tryParse(element.attributes['height'] ?? ""),
        node: element,
      );
    case "svg":
      return SvgContentElement(
        data: element.outerHtml,
        width: double.tryParse(element.attributes['width'] ?? ""),
        height: double.tryParse(element.attributes['height'] ?? ""),
      );
    case "ruby":
      return RubyElement(
        element: element,
      );
    default:
      return EmptyContentElement(name: element.localName);
  }
}

// TODO(Sub6Resources): Remove when https://github.com/flutter/flutter/issues/36304 is resolved
class PlatformViewVerticalGestureRecognizer extends VerticalDragGestureRecognizer {
  PlatformViewVerticalGestureRecognizer({PointerDeviceKind kind}) : super(kind: kind);

  Offset _dragDistance = Offset.zero;

  @override
  void addPointer(PointerEvent event) {
    startTrackingPointer(event.pointer);
  }

  @override
  void handleEvent(PointerEvent event) {
    _dragDistance = _dragDistance + event.delta;
    if (event is PointerMoveEvent) {
      final double dy = _dragDistance.dy.abs();
      final double dx = _dragDistance.dx.abs();

      if (dy > dx && dy > kTouchSlop) {
        // vertical drag - accept
        resolve(GestureDisposition.accepted);
        _dragDistance = Offset.zero;
      } else if (dx > kTouchSlop && dx > dy) {
        // horizontal drag - stop tracking
        stopTrackingPointer(event.pointer);
        _dragDistance = Offset.zero;
      }
    }
  }

  @override
  String get debugDescription => 'horizontal drag (platform view)';

  @override
  void didStopTrackingLastPointer(int pointer) {}
}
