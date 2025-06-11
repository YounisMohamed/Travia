import 'package:flutter/material.dart';

import 'Services/ClassificationService.dart';

class ClassifierExample extends StatefulWidget {
  @override
  _ClassifierExampleState createState() => _ClassifierExampleState();
}

class _ClassifierExampleState extends State<ClassifierExample> {
  final _classifier = TravelClassifierService.instance;
  bool _isLoading = false;
  ClassificationResponse? _result;
  String? _error;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _addLog('ClassifierExample initialized');
    _addLog('Using base URL: ${_classifier.baseUrl}');
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toIso8601String().split('T')[1];
    final logMessage = '[$timestamp] $message';
    debugPrint(logMessage);
    setState(() {
      _logs.add(logMessage);
    });
  }

  Future<void> _classifyImage() async {
    _addLog('Starting classification process...');

    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });

    try {
      // First check if API is healthy
      _addLog('Checking API health...');
      final health = await _classifier.checkHealth();
      _addLog('Health check response: ${health.status}');
      _addLog('Models loaded: ${health.modelsLoaded}');
      _addLog('Memory optimized: ${health.memoryOptimized}');

      if (!health.isHealthy) {
        throw ClassifierException(message: 'API is not healthy. Status: ${health.status}');
      }
      _addLog('✅ API is healthy');

      // Classify image
      const imageUrl = 'https://fastly.4sqi.net/img/general/original/15110573_5mw4VrOJONfWEk3D3hn2LLsL-sAdde2DOi53qbJE2Qk.jpg';
      const caption = 'A nice restaurant';

      _addLog('Classifying image...');
      _addLog('Image URL: $imageUrl');
      _addLog('Caption: $caption');

      final result = await _classifier.classifyFromUrl(
        imageUrl: imageUrl,
        caption: caption,
        confidenceThreshold: 0.5,
      );

      _addLog('✅ Classification successful!');
      _addLog('Success: ${result.success}');

      // Log attributes
      _addLog('=== ATTRIBUTES ===');
      _addLog('Good for Kids: ${result.attributes.goodForKids}');
      _addLog('Romantic: ${result.attributes.ambienceRomantic}');
      _addLog('Trendy: ${result.attributes.ambienceTrendy}');
      _addLog('Casual: ${result.attributes.ambienceCasual}');
      _addLog('Classy: ${result.attributes.ambienceClassy}');
      _addLog('Bar/Night: ${result.attributes.barsNight}');
      _addLog('Cafe: ${result.attributes.cafes}');
      _addLog('Restaurant: ${result.attributes.restaurantsCuisines}');

      // Log metadata
      _addLog('=== METADATA ===');
      _addLog('BLIP Description: ${result.metadata.blipDescription}');
      _addLog('Combined Text: ${result.metadata.combinedText}');

      // Log derived info
      _addLog('=== DERIVED INFO ===');
      _addLog('Venue Type: ${result.attributes.getVenueType()}');
      _addLog('Active Attributes: ${result.attributes.getActiveAttributes().join(", ")}');

      setState(() {
        _result = result;
      });
    } on ClassifierException catch (e) {
      _addLog('❌ ClassifierException: ${e.message}');
      if (e.statusCode != null) {
        _addLog('Status code: ${e.statusCode}');
      }
      setState(() {
        _error = e.message;
      });
    } catch (e, stackTrace) {
      _addLog('❌ Unexpected error: $e');
      _addLog('Stack trace: $stackTrace');
      setState(() {
        _error = 'Unexpected error: $e';
      });
    } finally {
      _addLog('Classification process completed');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
      _result = null;
      _error = null;
    });
    _addLog('Logs cleared');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Travel Classifier Example'),
        actions: [
          IconButton(
            icon: Icon(Icons.clear_all),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Results Section
          Container(
            padding: EdgeInsets.all(16),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Classification Results',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 16),
                    if (_isLoading)
                      Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 8),
                            Text('Processing... (this may take a moment on first run)'),
                          ],
                        ),
                      )
                    else if (_error != null)
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Error: $_error',
                                style: TextStyle(color: Colors.red.shade800),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_result != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildResultRow(
                            'Venue Type',
                            _result!.attributes.getVenueType(),
                            Icons.store,
                          ),
                          SizedBox(height: 8),
                          _buildResultRow(
                            'Attributes',
                            _result!.attributes.getActiveAttributes().isEmpty ? 'None detected' : _result!.attributes.getActiveAttributes().join(', '),
                            Icons.category,
                          ),
                          SizedBox(height: 8),
                          _buildResultRow(
                            'AI Description',
                            _result!.metadata.blipDescription,
                            Icons.description,
                          ),
                        ],
                      )
                    else
                      Center(
                        child: Text(
                          'Press the button to classify an image',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Logs Section
          Expanded(
            child: Container(
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.terminal, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Debug Logs',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Spacer(),
                        Text(
                          '${_logs.length} entries',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.all(8),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        Color textColor = Colors.black87;
                        if (log.contains('✅')) {
                          textColor = Colors.green.shade700;
                        } else if (log.contains('❌')) {
                          textColor = Colors.red.shade700;
                        } else if (log.contains('===')) {
                          textColor = Colors.blue.shade700;
                        }

                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            log,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: textColor,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _classifyImage,
        icon: Icon(Icons.image_search),
        label: Text('Classify Image'),
        backgroundColor: _isLoading ? Colors.grey : Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildResultRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
