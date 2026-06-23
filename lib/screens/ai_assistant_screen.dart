import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/ai_service.dart';
import '../services/file_service.dart';
import '../services/vector_db_service.dart';
import '../providers/deck_provider.dart';
import '../utils/custom_snackbar.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/neumorphic_widgets.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final _textController = TextEditingController();
  final _deckNameController = TextEditingController();
  final _ragQueryController = TextEditingController();
  final _aiService = AIService();
  final _fileService = FileService();
  final _vectorDb = VectorDbService.instance;

  bool _isLoading = false;
  List<Map<String, String>> _generatedCards = [];

  // RAG Fields
  bool _isRAGMode = false;
  String? _indexedDocId;
  String? _indexedDocName;
  int _totalChunks = 0;
  int _indexedChunksCount = 0;

  @override
  void dispose() {
    _textController.dispose();
    _deckNameController.dispose();
    _ragQueryController.dispose();
    super.dispose();
  }

  List<String> _chunkText(String text, {int chunkSize = 600, int overlap = 150}) {
    List<String> chunks = [];
    if (text.length <= chunkSize) {
      return [text];
    }
    int start = 0;
    while (start < text.length) {
      int end = start + chunkSize;
      if (end > text.length) {
        end = text.length;
      }
      chunks.add(text.substring(start, end));
      if (end == text.length) {
        break;
      }
      start += chunkSize - overlap;
    }
    return chunks;
  }

  Future<void> _indexDocument(String text, String docName) async {
    setState(() {
      _isLoading = true;
      _isRAGMode = true;
      _indexedDocId = DateTime.now().millisecondsSinceEpoch.toString();
      _indexedDocName = docName;
      _indexedChunksCount = 0;
      _totalChunks = 0;
      _generatedCards = [];
    });

    try {
      final chunks = _chunkText(text);
      setState(() {
        _totalChunks = chunks.length;
      });

      // Clear DB for this ID
      await _vectorDb.deleteDocumentChunks(_indexedDocId!);

      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        final embedding = await _aiService.getEmbedding(chunk);
        
        await _vectorDb.saveChunk(
          id: '${_indexedDocId!}_$i',
          documentId: _indexedDocId!,
          documentName: _indexedDocName!,
          chunkText: chunk,
          embedding: embedding,
        );

        if (mounted) {
          setState(() {
            _indexedChunksCount = i + 1;
          });
        }
      }

      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Successfully indexed "$docName" into $_totalChunks blocks!',
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Error building index: $e',
          type: SnackBarType.error,
        );
      }
      setState(() {
        _isRAGMode = false;
        _indexedDocId = null;
        _indexedDocName = null;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleExtractedText(String text, String sourceName) async {
    if (text.length < 800) {
      // Too short to justify RAG, directly paste to input
      setState(() {
        _textController.text = text;
        _isRAGMode = false;
        _indexedDocId = null;
      });
      return;
    }

    final bool? useRAG = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Smart PDF Indexing (RAG)'),
        content: const Text(
          'This is a long document. Would you like to build a local vector index of it?\n\n'
          'Indexing splits the file and stores embeddings in a local vector database. This prevents hallucinations and context token overflows by fetching only relevant sections when you query.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Paste full text'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Index document'),
          ),
        ],
      ),
    );

    if (useRAG == true) {
      await _indexDocument(text, sourceName);
    } else {
      setState(() {
        _textController.text = text;
        _isRAGMode = false;
        _indexedDocId = null;
      });
    }
  }

  Future<void> _extractFromFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final name = result.files.single.name;
        final file = File(path);
        final extension = result.files.single.extension?.toLowerCase() ?? '';

        setState(() => _isLoading = true);
        String text;
        if (extension == 'pdf') {
          text = _fileService.extractTextFromPdf(file);
        } else {
          text = await file.readAsString();
        }

        setState(() => _isLoading = false);
        if (mounted) {
          await _handleExtractedText(text, name);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Error: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  Future<void> _extractFromCamera() async {
    await _extractFromImage(ImageSource.camera);
  }

  Future<void> _extractFromGallery() async {
    await _extractFromImage(ImageSource.gallery);
  }

  Future<void> _extractFromImage(ImageSource source) async {
    setState(() => _isLoading = true);
    try {
      final text = await _fileService.extractTextFromImage(source);
      if (text != null && text.isNotEmpty) {
        await _handleExtractedText(text, 'Image OCR');
      } else if (text != null && text.isEmpty && mounted) {
        CustomSnackBar.show(
          context,
          message: 'No text found in the image. Please try a clearer image.',
          type: SnackBarType.info,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Error processing image: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _extractFromUrl() async {
    String url = '';
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Extract from URL'),
          content: TextField(
            onChanged: (value) => url = value,
            decoration: const InputDecoration(hintText: 'https://example.com'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Extract'),
            ),
          ],
        );
      },
    );

    if (url.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final text = await _fileService.extractTextFromUrl(url);
        if (text != null && text.isNotEmpty) {
          final uri = Uri.parse(url);
          final docName = uri.host.isNotEmpty ? uri.host : 'URL Source';
          await _handleExtractedText(text, docName);
        }
      } catch (e) {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: 'Error: $e',
            type: SnackBarType.error,
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _generateFlashcards() async {
    if (_textController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _generatedCards = [];
    });
    try {
      final cards = await _aiService.generateFlashcards(_textController.text);
      setState(() {
        _generatedCards = cards;
      });
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Error: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double _cosineSimilarity(List<double> v1, List<double> v2) {
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < v1.length; i++) {
      dotProduct += v1[i] * v2[i];
      normA += v1[i] * v1[i];
      normB += v2[i] * v2[i];
    }
    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (math.sqrt(normA) * math.sqrt(normB));
  }

  Future<void> _generateFlashcardsRAG() async {
    final query = _ragQueryController.text.trim();
    if (query.isEmpty || _indexedDocId == null) return;

    setState(() {
      _isLoading = true;
      _generatedCards = [];
    });

    try {
      final queryEmbedding = await _aiService.getEmbedding(query);
      final dbChunks = await _vectorDb.getChunksForDocument(_indexedDocId!);

      if (dbChunks.isEmpty) {
        throw Exception("No indexed chunks found in database. Please re-index your file.");
      }

      final List<Map<String, dynamic>> ratedChunks = [];
      for (var row in dbChunks) {
        final text = row['chunk_text'] as String;
        final rawEmb = row['embedding'] as String;
        final List<dynamic> jsonList = jsonDecode(rawEmb);
        final embedding = jsonList.map<double>((e) => (e as num).toDouble()).toList();

        final score = _cosineSimilarity(queryEmbedding, embedding);
        ratedChunks.add({
          'text': text,
          'score': score,
        });
      }

      ratedChunks.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
      final topChunks = ratedChunks.take(3).map<String>((e) => e['text'] as String).toList();

      final cards = await _aiService.generateFlashcardsFromRAG(topChunks, query);
      setState(() {
        _generatedCards = cards;
      });
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Error: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveToDeck() async {
    if (_generatedCards.isEmpty) return;

    final deckProvider = context.read<DeckProvider>();
    String deckName = _deckNameController.text.isEmpty
        ? "AI Study - ${DateTime.now().toLocal().toString().split(' ')[0]}"
        : _deckNameController.text;

    await deckProvider.addDeck(deckName, "Smart cards from AI Study Buddy");
    await deckProvider.loadDecks();
    final newDeck = deckProvider.decks.first;

    await deckProvider.addMultipleFlashcards(newDeck.id, _generatedCards);

    if (mounted) {
      CustomSnackBar.show(
        context,
        message: 'New deck ready!',
        type: SnackBarType.success,
      );
      setState(() {
        _generatedCards = [];
        _textController.clear();
        _deckNameController.clear();
        _ragQueryController.clear();
        _isRAGMode = false;
        _indexedDocId = null;
        _indexedDocName = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Assistant'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.indigo,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          if (isWide) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child:
                            SingleChildScrollView(child: _buildInputSection()),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        flex: 4,
                        child: _buildResultsSection(isWide: true),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInputSection(),
                if (_isLoading || _generatedCards.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  _buildResultsSection(isWide: false),
                ],
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildResultsSection({required bool isWide}) {
    final theme = Theme.of(context);
    final isIndexing = _isLoading && _isRAGMode && _indexedChunksCount < _totalChunks;

    if (_isLoading && !isIndexing) {
      return NeumorphicContainer(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: const Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text('AI is crafting your study gems...',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_generatedCards.isEmpty) {
      if (!isWide) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: NeumorphicEmptyState(
          icon: Icons.library_add_outlined,
          title: 'Ready to turn notes into cards',
          subtitle:
              'Use the AI assistant above to generate a polished deck in seconds.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.colorScheme.outline),
            boxShadow: [
              BoxShadow(
                  color: theme.brightness == Brightness.dark
                      ? Colors.black.withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Draft Results',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_generatedCards.length} cards ready for review',
                      style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ) ??
                          TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _generatedCards = []),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                tooltip: 'Clear Results',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _deckNameController,
          decoration: InputDecoration(
            labelText: 'Deck Title',
            prefixIcon: const Icon(Icons.label_outlined),
            hintText: 'e.g., Biology Chapter 1',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            filled: true,
            fillColor: theme.colorScheme.surface,
          ),
        ),
        const SizedBox(height: 16),
        if (isWide)
          Expanded(
            child: ListView.builder(
              itemCount: _generatedCards.length,
              itemBuilder: (context, index) =>
                  _buildCardItem(_generatedCards[index]),
            ),
          )
        else
          Column(
              children:
                  _generatedCards.map((card) => _buildCardItem(card)).toList()),
        const SizedBox(height: 24),
        SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _saveToDeck,
            icon: const Icon(Icons.save_alt_rounded),
            label:
                const Text('Save to My Decks', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildInputSection() {
    final theme = Theme.of(context);

    if (_isRAGMode) {
      final isIndexing = _isLoading && _indexedChunksCount < _totalChunks;
      final progressValue = _totalChunks > 0 ? _indexedChunksCount / _totalChunks : 0.0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.indigo.shade700,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'RAG Study Assistant',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Ask questions or request topics from your indexed file to generate highly focused flashcards.',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          
          NeumorphicContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isIndexing ? Icons.hourglass_top_rounded : Icons.task_alt_rounded,
                      color: isIndexing ? Colors.orange : Colors.green,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _indexedDocName ?? 'Document Source',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isIndexing
                                ? 'Vector Indexing: $_indexedChunksCount / $_totalChunks chunks'
                                : 'Successfully Indexed: $_totalChunks chunks in local vector DB',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (!isIndexing)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isRAGMode = false;
                            _indexedDocId = null;
                            _indexedDocName = null;
                            _ragQueryController.clear();
                            _textController.clear();
                          });
                        },
                        icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                        tooltip: 'Unbind Source',
                      ),
                  ],
                ),
                if (isIndexing) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      minHeight: 6,
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          if (!isIndexing) ...[
            TextField(
              controller: _ragQueryController,
              decoration: InputDecoration(
                labelText: 'Target Topic / Question',
                hintText: 'e.g., Explain cellular division or mitosis...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
              onSubmitted: (_) => _generateFlashcardsRAG(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _generateFlashcardsRAG,
                icon: const Icon(Icons.auto_stories_rounded),
                label: const Text('Generate via Smart RAG', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.indigo.shade700,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white24,
                child: Icon(Icons.auto_awesome, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'AI Flashcard Maker',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Paste notes or upload a source to create study-ready flashcards in seconds.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        NeumorphicContainer(
          padding: const EdgeInsets.all(0),
          borderRadius: BorderRadius.circular(24),
          child: TextField(
            controller: _textController,
            maxLines: 10,
            decoration: InputDecoration(
              hintText:
                  'Paste your study material here, describe a topic, or upload a document below...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.upload_file, color: Colors.indigo),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Upload or paste a source',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tap the menu to index a PDF, paste a URL, or import an image.',
                      style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ) ??
                          TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 13),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_outlined,
                        color: Colors.indigo),
                    onSelected: (value) {
                      if (value == 'pdf') {
                        _extractFromFile();
                      } else if (value == 'url') {
                        _extractFromUrl();
                      } else if (value == 'camera') {
                        _extractFromCamera();
                      } else if (value == 'image') {
                        _extractFromGallery();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'pdf',
                        child: Row(
                          children: [
                            Icon(Icons.picture_as_pdf_outlined,
                                color: Colors.orange.shade700),
                            const SizedBox(width: 10),
                            const Text('Attach PDF'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'url',
                        child: Row(
                          children: [
                            Icon(Icons.link, color: Colors.blue.shade700),
                            const SizedBox(width: 10),
                            const Text('Paste URL'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'camera',
                        child: Row(
                          children: [
                            Icon(Icons.camera_alt_outlined,
                                color: Colors.green.shade700),
                            const SizedBox(width: 10),
                            const Text('Scan Camera'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'image',
                        child: Row(
                          children: [
                            Icon(Icons.image_outlined,
                                color: Colors.purple.shade700),
                            const SizedBox(width: 10),
                            const Text('Pick Image'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 60,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _generateFlashcards,
            icon: const Icon(Icons.bolt_rounded, size: 28),
            label: const Text('Generate Flashcard',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildCardItem(Map<String, String> card) {
    final theme = Theme.of(context);
    return NeumorphicContainer(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.help_outline, size: 16, color: Colors.indigo),
                const SizedBox(width: 8),
                Text('QUESTION',
                    style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.withValues(alpha: 0.65),
                          letterSpacing: 1.2,
                        ) ??
                        TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.withValues(alpha: 0.65),
                          letterSpacing: 1.2,
                        )),
              ],
            ),
            const SizedBox(height: 4),
            Text(card['question'] ?? '',
                style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w500) ??
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Text('ANSWER',
                    style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.withValues(alpha: 0.65),
                          letterSpacing: 1.2,
                        ) ??
                        TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.withValues(alpha: 0.65),
                          letterSpacing: 1.2,
                        )),
              ],
            ),
            const SizedBox(height: 4),
            Text(card['answer'] ?? '',
                style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14) ??
                    TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
