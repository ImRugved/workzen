import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_button.dart';
import '../../constants/constant_colors.dart';
import '../../constants/constant_date_time_picker.dart';
import '../../constants/constant_snackbar.dart';
import '../../models/company_rules_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_info_provider.dart';
import '../../providers/value_provider.dart';
import '../../utils/validators.dart';

/// Where an admin (or a sub admin with the company info permission) writes a
/// newsletter post: a title, the date it happened, an optional picture and the
/// text, written in the same rich text editor as the company rules (paste from
/// ChatGPT keeps the formatting).
class NewsletterEditorScreen extends StatefulWidget {
  const NewsletterEditorScreen({super.key});

  @override
  State<NewsletterEditorScreen> createState() => _NewsletterEditorScreenState();
}

class _NewsletterEditorScreenState extends State<NewsletterEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();

  // The editor's objects (lifecycle objects, no setState)
  final QuillController _body = QuillController.basic();
  final FocusNode _bodyFocus = FocusNode();
  final ScrollController _bodyScroll = ScrollController();
  final ImagePicker _picker = ImagePicker();

  // Choices made so far (scoped state, no setState)
  final ValueProvider<DateTime?> _date = ValueProvider<DateTime?>(null);
  final ValueProvider<Uint8List?> _image = ValueProvider<Uint8List?>(null);

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _bodyFocus.dispose();
    _bodyScroll.dispose();
    _date.dispose();
    _image.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (picked == null) return;
      _image.value = await picked.readAsBytes();
    } catch (e) {
      ConstantSnackbar.showError(title: 'Could not open the picture: $e');
    }
  }

  Future<void> _post() async {
    if (!_formKey.currentState!.validate()) return;

    final bodyJson = jsonEncode(_body.document.toDelta().toJson());
    if (!CompanyRulesModel.hasContent(bodyJson)) {
      ConstantSnackbar.showError(title: 'Write the details of the post');
      return;
    }

    final admin = context.read<AuthProvider>().userModel;
    final saved = await context.read<CompanyInfoProvider>().addNewsletter(
      title: _title.text.trim(),
      bodyJson: bodyJson,
      postedBy: admin?.name ?? 'Admin',
      posterId: admin?.id ?? '',
      eventDate: _date.value,
      imageBytes: _image.value,
    );
    if (!mounted) return;
    if (saved) {
      Get.back<void>();
      ConstantSnackbar.showSuccess(title: 'Posted to the newsletter');
    } else {
      ConstantSnackbar.showError(
        title: 'Failed to post. Check the internet and the pictures bucket.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'New Newsletter Post',
          style: getTextTheme().titleLarge?.copyWith(
            color: ConstColors.textColor,
          ),
        ),
      ),
      backgroundColor: ConstColors.backgroundColor,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: AppSpacing.screen,
            children: [
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                validator: Validators.required('a title'),
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              SizedBox(height: 12.h),
              ChangeNotifierProvider.value(
                value: _date,
                child: Consumer<ValueProvider<DateTime?>>(
                  builder: (context, date, _) => ConstantDatePicker(
                    label: 'Date it happened (optional)',
                    value: date.value,
                    format: 'dd MMM yyyy',
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    onChanged: (picked) => date.value = picked,
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              ChangeNotifierProvider.value(
                value: _image,
                child: Consumer<ValueProvider<Uint8List?>>(
                  builder: (context, image, _) {
                    final bytes = image.value;
                    if (bytes == null) {
                      return ConstantButton(
                        text: 'Add a picture (optional)',
                        isOutlined: true,
                        icon: Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 20.r,
                          color: ConstColors.primaryDeep,
                        ),
                        onPressed: _pickImage,
                      );
                    }
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12.r),
                          child: Image.memory(
                            bytes,
                            width: double.infinity,
                            height: 170.h,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 6.r,
                          right: 6.r,
                          child: CircleAvatar(
                            radius: 16.r,
                            backgroundColor: ConstColors.white,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: Icon(Icons.close, size: 18.r),
                              onPressed: () => image.value = null,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Details',
                style: getTextTheme().titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6.h),
              // Formatting buttons, then the text; pasting keeps the formatting
              Container(
                color: ConstColors.white,
                child: QuillSimpleToolbar(
                  controller: _body,
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
                    multiRowsDisplay: false,
                  ),
                ),
              ),
              SizedBox(
                height: 300.h,
                child: NeuCard(
                  child: Padding(
                    padding: EdgeInsets.all(12.r),
                    child: QuillEditor(
                      controller: _body,
                      focusNode: _bodyFocus,
                      scrollController: _bodyScroll,
                      config: const QuillEditorConfig(
                        placeholder:
                            'Write or paste the news here: a visit, a milestone, '
                            'an achievement, anything worth sharing.',
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Consumer<CompanyInfoProvider>(
                builder: (context, info, _) => ConstantButton(
                  text: 'Post to Newsletter',
                  isLoading: info.isSaving,
                  onPressed: info.isSaving ? null : _post,
                  backgroundColor: ConstColors.primary,
                  textColor: ConstColors.textColor,
                ),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }
}
