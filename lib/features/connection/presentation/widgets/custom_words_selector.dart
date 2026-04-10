import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:p2p_codenames/features/game_board/providers/custom_words_provider.dart';

const _surfaceContainerLowest = Color(0xFF000F20);
const _primary = Color(0xFFFFB77A);
const _outline = Color(0xFFA38D7C);
const _outlineVariant = Color(0xFF554336);
const _onSurface = Color(0xFFD1E4FF);
const _onSurfaceVariant = Color(0xFFDBC2B0);
const _secondary = Color(0xFF95CEEF);

class CustomWordsSelector extends ConsumerStatefulWidget {
  const CustomWordsSelector({super.key});

  @override
  ConsumerState<CustomWordsSelector> createState() => _CustomWordsSelectorState();
}

class _CustomWordsSelectorState extends ConsumerState<CustomWordsSelector> {
  final TextEditingController _controller = TextEditingController();
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateWordCount);
    // sync from provider if navigating back
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final existing = ref.read(customWordsProvider);
      if (existing != null && existing.isNotEmpty) {
        _controller.text = existing.join(', ');
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_updateWordCount);
    _controller.dispose();
    super.dispose();
  }

  void _updateWordCount() {
    final text = _controller.text;
    final words = text.split(RegExp(r'[ \n,]+'))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();
    
    // Update provider so parent screens can grab the words
    ref.read(customWordsProvider.notifier).state = words.isEmpty ? null : words;
        
    if (mounted && _wordCount != words.length) {
      setState(() => _wordCount = words.length);
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String contents = await file.readAsString();
        _controller.text = contents;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تم استيراد الكلمات بنجاح', style: GoogleFonts.notoSansArabic()),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('فشل قراءة الملف: $e', style: GoogleFonts.notoSansArabic()),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceContainerLowest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _outlineVariant.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'كلمات مخصصة للعب (اختياري)',
                style: GoogleFonts.notoSansArabic(
                  color: _primary, 
                  fontSize: 12, 
                  fontWeight: FontWeight.bold,
                ),
              ),
              InkWell(
                onTap: _pickFile,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _secondary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _secondary.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.upload_file, color: _secondary, size: 14),
                      const SizedBox(width: 4),
                      Text('ملف TXT', style: GoogleFonts.notoSansArabic(color: _secondary, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _controller,
            maxLines: 4,
            style: GoogleFonts.notoSansArabic(color: _onSurface, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'اكتب الكلمات هنا، افصل بينها بمسافة، فاصلة أو سطر جديد...',
              hintStyle: GoogleFonts.notoSansArabic(color: _onSurfaceVariant.withOpacity(0.5), fontSize: 12),
              filled: true,
              fillColor: Colors.black.withOpacity(0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _outlineVariant.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _outlineVariant.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _primary),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _wordCount >= 25 ? Icons.check_circle : Icons.info_outline, 
                color: _wordCount >= 25 ? Colors.green : _outlineVariant, 
                size: 14
              ),
              const SizedBox(width: 6),
              Text(
                'عدد الكلمات المكتشفة: $_wordCount / 25',
                style: GoogleFonts.notoSansArabic(
                  color: _wordCount >= 25 ? Colors.green : _onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          if (_wordCount > 0 && _wordCount < 25)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                '* سيتم إكمال النقص من القاموس الافتراضي لتكوين الطاولة.',
                style: GoogleFonts.notoSansArabic(color: _outline, fontSize: 9),
              ),
            ),
        ],
      ),
    );
  }
}
