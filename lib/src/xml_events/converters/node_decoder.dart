import 'dart:convert' show ChunkedConversionSink;

import '../../xml/nodes/attribute.dart';
import '../../xml/nodes/cdata.dart';
import '../../xml/nodes/comment.dart';
import '../../xml/nodes/declaration.dart';
import '../../xml/nodes/doctype.dart';
import '../../xml/nodes/element.dart';
import '../../xml/nodes/node.dart';
import '../../xml/nodes/processing.dart';
import '../../xml/nodes/text.dart';
import '../../xml/utils/exceptions.dart';
import '../../xml/utils/name.dart';
import '../event.dart';
import '../events/cdata.dart';
import '../events/comment.dart';
import '../events/declaration.dart';
import '../events/doctype.dart';
import '../events/end_element.dart';
import '../events/processing.dart';
import '../events/start_element.dart';
import '../events/text.dart';
import '../utils/event_attribute.dart';
import '../visitor.dart';
import 'list_converter.dart';

extension XmlNodeDecoderExtension on Stream<List<XmlEvent>> {
  /// Converts a sequence of [XmlEvent] objects to [XmlNode] objects.
  Stream<List<XmlNode>> toXmlNodes() => transform(const XmlNodeDecoder());
}

/// A converter that decodes a sequence of [XmlEvent] objects to a forest of
/// [XmlNode] objects.
class XmlNodeDecoder extends XmlListConverter<XmlEvent, XmlNode> {
  const XmlNodeDecoder();

  @override
  ChunkedConversionSink<List<XmlEvent>> startChunkedConversion(
          Sink<List<XmlNode>> sink) =>
      _XmlNodeDecoderSink(sink);
}

class _XmlNodeDecoderSink extends ChunkedConversionSink<List<XmlEvent>>
    with XmlEventVisitor {
  _XmlNodeDecoderSink(this.sink);

  final Sink<List<XmlNode>> sink;
  XmlElement parent;

  @override
  void add(List<XmlEvent> chunk) => chunk.forEach(visit);

  @override
  void visitCDATAEvent(XmlCDATAEvent event) => commit(XmlCDATA(event.text));

  @override
  void visitCommentEvent(XmlCommentEvent event) =>
      commit(XmlComment(event.text));

  @override
  void visitDeclarationEvent(XmlDeclarationEvent event) =>
      commit(XmlDeclaration(convertAttributes(event.attributes)));

  @override
  void visitDoctypeEvent(XmlDoctypeEvent event) =>
      commit(XmlDoctype(event.text));

  @override
  void visitEndElementEvent(XmlEndElementEvent event) {
    if (parent == null) {
      throw XmlTagException.closingTag(null, event.name);
    }
    XmlTagException.checkClosingTag(parent.name.qualified, event.name);
    if (!parent.hasParent) {
      sink.add([parent]);
    }
    parent = parent.parent;
  }

  @override
  void visitProcessingEvent(XmlProcessingEvent event) =>
      commit(XmlProcessing(event.target, event.text));

  @override
  void visitStartElementEvent(XmlStartElementEvent event) {
    final element = XmlElement(
      XmlName.fromString(event.name),
      convertAttributes(event.attributes),
      [],
      event.isSelfClosing,
    );
    if (event.isSelfClosing) {
      commit(element);
    } else {
      if (parent != null) {
        parent.children.add(element);
      }
      parent = element;
    }
  }

  @override
  void visitTextEvent(XmlTextEvent event) => commit(XmlText(event.text));

  @override
  void close() {
    if (parent != null) {
      throw XmlTagException.closingTag(parent.name.qualified, null);
    }
    sink.close();
  }

  void commit(XmlNode node) {
    if (parent == null) {
      sink.add(<XmlNode>[node]);
    } else {
      parent.children.add(node);
    }
  }

  Iterable<XmlAttribute> convertAttributes(
          Iterable<XmlEventAttribute> attributes) =>
      attributes.map((attribute) => XmlAttribute(
          XmlName.fromString(attribute.name),
          attribute.value,
          attribute.attributeType));
}
