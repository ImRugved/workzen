import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../utils/logger.dart';

/// Read-only view of formatted text saved from the rich text editor (a Quill
/// Delta as JSON): bold, italic, sizes, headings, lists and links show as they
/// were written. It sizes itself to the text, so it sits inside a card or a
/// scrolling page.
class RichTextView extends StatefulWidget {
  final String contentJson;

  const RichTextView({super.key, required this.contentJson});

  @override
  State<RichTextView> createState() => _RichTextViewState();
}

class _RichTextViewState extends State<RichTextView> {
  // Owns the controller and the focus node (lifecycle objects)
  late QuillController _controller;
  final FocusNode _focusNode = FocusNode(canRequestFocus: false);

  @override
  void initState() {
    super.initState();
    _controller = _controllerFor(widget.contentJson);
  }

  // Shows new content when the saved rules change while the page is open
  @override
  void didUpdateWidget(RichTextView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contentJson != widget.contentJson) {
      _controller.dispose();
      _controller = _controllerFor(widget.contentJson);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  QuillController _controllerFor(String contentJson) {
    Document document;
    try {
      document = Document.fromJson(jsonDecode(contentJson) as List);
    } catch (e) {
      logDebug('Could not read the formatted text: $e');
      document = Document()..insert(0, 'The text could not be shown.');
    }
    return QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return QuillEditor(
      controller: _controller,
      focusNode: _focusNode,
      scrollController: ScrollController(),
      config: const QuillEditorConfig(
        // Grows with the text instead of scrolling by itself
        scrollable: false,
        expands: false,
        autoFocus: false,
        showCursor: false,
      ),
    );
  }
}
