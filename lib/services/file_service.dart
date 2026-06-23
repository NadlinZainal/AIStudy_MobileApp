import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class FileService {
  Future<String?> pickAndExtractText() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      String extension = result.files.single.extension?.toLowerCase() ?? '';

      if (extension == 'pdf') {
        return extractTextFromPdf(file);
      } else {
        return await file.readAsString();
      }
    }
    return null;
  }

  String extractTextFromPdf(File file) {
    try {
      final PdfDocument document = PdfDocument(inputBytes: file.readAsBytesSync());
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      final String text = extractor.extractText();
      document.dispose();
      return text;
    } catch (e) {
      throw Exception('Failed to extract text from PDF: $e');
    }
  }

  Future<String?> extractTextFromUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        String html = response.body;
        // Basic HTML stripping
        String text = html.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), ' ');
        text = text.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), ' ');
        text = text.replaceAll(RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true), ' ');
        // Remove extra spaces
        text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
        return text;
      } else {
        throw Exception('Failed to load url: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to extract text from URL: $e');
    }
  }

  Future<String?> extractTextFromImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      if (image == null) return null;

      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      final String text = recognizedText.text;
      await textRecognizer.close();
      return text;
    } catch (e) {
      throw Exception('Failed to recognize text from image: $e');
    }
  }
}
