import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart'; 
import '../../core/theme/app_theme.dart';
import '../../core/widgets/scam_shield_app_bar.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/ai_checker_provider.dart';

class AskAiScreen extends ConsumerStatefulWidget {
  const AskAiScreen({super.key});

  @override
  ConsumerState<AskAiScreen> createState() => _AskAiScreenState();
}

class _AskAiScreenState extends ConsumerState<AskAiScreen> {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  bool _isOcrProcessing = false;
  String? _extractedText;
  String? _ocrError; // Local error for image scanning

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // Calls the FastAPI backend via Riverpod
  void _analyzeText(String text) {
    FocusScope.of(context).unfocus();
    setState(() => _ocrError = null); // Clear OCR errors
    ref.read(aiCheckerProvider.notifier).checkMessage(text);
  }

  Future<void> _pickAndAnalyzeImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    FocusScope.of(context).unfocus();
    ref.read(aiCheckerProvider.notifier).reset(); // Clear previous AI results

    setState(() {
      _isOcrProcessing = true;
      _extractedText = null;
      _ocrError = null;
    });

    try {
      final currentLocale = ref.read(localeProvider);
      final script = (currentLocale.languageCode == 'hi' || currentLocale.languageCode == 'mr')
          ? TextRecognitionScript.devanagiri
          : TextRecognitionScript.latin;

      final textRecognizer = TextRecognizer(script: script);
      final inputImage = InputImage.fromFilePath(image.path);
      
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();
      
      setState(() {
        _extractedText = recognizedText.text.trim();
        if (_extractedText != null && _extractedText!.isNotEmpty) {
          _textController.text = _extractedText!;
        }
        _isOcrProcessing = false;
      });

      if (_extractedText != null && _extractedText!.isNotEmpty) {
        _analyzeText(_extractedText!); // Send extracted text to FastAPI
      } else {
        setState(() {
          _ocrError = 'Could not read any text from the image. Please try a clearer screenshot.';
        });
      }
    } catch (e) {
      setState(() {
        _isOcrProcessing = false;
        _ocrError = 'Error processing image: $e';
      });
    }
  }

  // Helpers to map the AI JSON strings to UI colors and icons
  Color _getColor(String? colorStr) {
    switch (colorStr) {
      case 'red': return AppTheme.red;
      case 'amber': return Colors.orange;
      case 'green': return Colors.green;
      default: return Colors.grey;
    }
  }
  
  IconData _getIcon(String? colorStr) {
    switch (colorStr) {
      case 'red': return Icons.warning;
      case 'amber': return Icons.info_outline;
      case 'green': return Icons.check_circle;
      default: return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the API Provider state
    final checkerState = ref.watch(aiCheckerProvider);
    final isBusy = _isOcrProcessing || checkerState.isLoading;

    return Scaffold(
      appBar: const ScamShieldAppBar(title: 'Ask AI Scam Checker'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Paste a suspicious message or upload a screenshot to check if it is a scam.',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            
            TextField(
              controller: _textController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Paste message here...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isBusy ? null : () {
                      if (_textController.text.trim().isNotEmpty) {
                        _analyzeText(_textController.text);
                      }
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('Check Text'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : _pickAndAnalyzeImage,
                    icon: const Icon(Icons.image),
                    label: const Text('Screenshot'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: AppTheme.deepTeal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Loading Indicator
            if (isBusy)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
              
            // OCR Error Display
            else if (_ocrError != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_ocrError!, style: const TextStyle(color: Colors.black87)),
              )
              
            // Backend API Error Display
            else if (checkerState.error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(checkerState.error!, style: const TextStyle(color: Colors.red)),
              )
              
            // AI Verdict Results Card
            else if (checkerState.verdict != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _getColor(checkerState.color).withValues(alpha: 0.1),
                  border: Border.all(color: _getColor(checkerState.color), width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      _getIcon(checkerState.color),
                      color: _getColor(checkerState.color),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      checkerState.verdict!,
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold, 
                        color: _getColor(checkerState.color),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_extractedText != null && _extractedText!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const Text(
                        'Text found in image:', 
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _extractedText!, 
                        style: const TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    ]
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
