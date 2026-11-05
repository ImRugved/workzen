import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../constants/apploading_indicator.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_button.dart';
import '../../constants/constant_colors.dart';
import '../../constants/constant_snackbar.dart';
import '../../providers/company_info_provider.dart';
import '../../utils/logger.dart';

/// Where the admin (or a sub admin with the company info permission) writes the
/// company rules: a rich text editor. Text copied from ChatGPT or a web page
/// can be pasted as it is and keeps its formatting (bold, italic, headings,
/// lists, links); the toolbar changes the formatting by hand, including the
/// text size. Save stores it, and every Info page shows it as written.
class CompanyRulesScreen extends StatefulWidget {
  const CompanyRulesScreen({super.key});

  @override
  State<CompanyRulesScreen> createState() => _CompanyRulesScreenState();
}

class _CompanyRulesScreenState extends State<CompanyRulesScreen> {
  // The editor's objects (lifecycle objects, no setState). Pasting is handled
  // by the editor itself: rich text copied from other apps and websites keeps
  // its formatting, and Markdown (what the ChatGPT app copies) becomes
  // formatting too.
  final QuillController _controller = QuillController.basic();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  CompanyInfoProvider? _info;
  // The saved rules are put in the editor once, when they arrive
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _info = context.read<CompanyInfoProvider>()
        ..start()
        ..addListener(_loadSaved);
      _loadSaved();
    });
  }

  @override
  void dispose() {
    _info?.removeListener(_loadSaved);
    _ready.dispose();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadSaved() {
    final info = _info;
    if (_loaded || info == null || !info.rulesLoaded) return;
    _loaded = true;

    final content = info.rules.contentJson;
    if (content != null) {
      try {
        _controller.document = Document.fromJson(jsonDecode(content) as List);
      } catch (e) {
        logDebug('Could not open the saved rules: $e');
      }
    }
    // The first build was a spinner: let the page show the editor
    _ready.value = true;
  }

  // True once the saved rules are in the editor
  final ValueNotifier<bool> _ready = ValueNotifier<bool>(false);

  Future<void> _save() async {
    final info = context.read<CompanyInfoProvider>();
    final json = jsonEncode(_controller.document.toDelta().toJson());

    final saved = await info.saveRules(json);
    if (!mounted) return;
    if (saved) {
      Get.back<void>();
      ConstantSnackbar.showSuccess(title: 'Company rules saved');
    } else {
      ConstantSnackbar.showError(title: 'Failed to save the company rules');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Company Rules',
          style: getTextTheme().titleLarge?.copyWith(
            color: ConstColors.textColor,
          ),
        ),
      ),
      backgroundColor: ConstColors.backgroundColor,
      body: ValueListenableBuilder<bool>(
        valueListenable: _ready,
        builder: (context, ready, _) {
          if (!ready) return const Center(child: AppLoadingIndicator(size: 40));

          return Column(
            children: [
              // Formatting buttons: bold, italic, underline, strike, text size,
              // headings, colours, lists, quote, link, undo / redo and a
              // paste button
              Container(
                color: ConstColors.white,
                child: QuillSimpleToolbar(
                  controller: _controller,
                  config: const QuillSimpleToolbarConfig(
                    showFontFamily: false,
                    showSmallButton: false,
                    showInlineCode: false,
                    showCodeBlock: false,
                    showSubscript: false,
                    showSuperscript: false,
                    showSearchButton: false,
                    showListCheck: false,
                    showDirection: false,
                    // ignore: experimental_member_use
                    showClipboardPaste: true,
                    multiRowsDisplay: false,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Padding(
                  padding: AppSpacing.screen,
                  child: NeuCard(
                    child: Padding(
                      padding: EdgeInsets.all(12.r),
                      child: QuillEditor(
                        controller: _controller,
                        focusNode: _focusNode,
                        scrollController: _scrollController,
                        config: const QuillEditorConfig(
                          placeholder:
                              'Paste the company rules here (for example '
                              'copied from ChatGPT) or type them. The '
                              'formatting is kept.',
                          autoFocus: false,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
                  child: Consumer<CompanyInfoProvider>(
                    builder: (context, info, _) => ConstantButton(
                      text: 'Save Company Rules',
                      isLoading: info.isSaving,
                      onPressed: info.isSaving ? null : _save,
                      backgroundColor: ConstColors.primary,
                      textColor: ConstColors.textColor,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
