import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:merkle_kv_core/merkle_kv_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(const MerkleKVApp());
}

class MerkleKVApp extends StatelessWidget {
  const MerkleKVApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MerkleKV Mobile Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MerkleKVDemo(),
    );
  }
}

class MerkleKVDemo extends StatefulWidget {
  const MerkleKVDemo({super.key});

  @override
  State<MerkleKVDemo> createState() => _MerkleKVDemoState();
}

class _MerkleKVDemoState extends State<MerkleKVDemo> {
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _brokerController = TextEditingController(text: 'test.mosquitto.org');
  final TextEditingController _portController = TextEditingController(text: '1883');
  
  String _connectionStatus = 'Disconnected';
  String _lastOperation = '';
  String _lastResult = '';
  List<MapEntry<String, dynamic>> _allData = [];
  
  MerkleKVConfig? _config;
  late String _clientId;
  late String _nodeId;
  
  // Core components
  InMemoryStorage? _storage;
  MqttClientImpl? _mqttClient;
  CommandProcessor? _commandProcessor;
  CommandCorrelator? _commandCorrelator;
  ReplicationEventPublisherImpl? _replicationPublisher;
  
  @override
  void initState() {
    super.initState();
    _generateIds();
    _loadSettings();
  }

  void _generateIds() {
    final uuid = const Uuid();
    _clientId = 'flutter-${uuid.v4().substring(0, 8)}';
    _nodeId = 'node-${uuid.v4().substring(0, 8)}';
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _brokerController.text = prefs.getString('mqtt_host') ?? 'test.mosquitto.org';
      _portController.text = prefs.getInt('mqtt_port')?.toString() ?? '1883';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mqtt_host', _brokerController.text);
    await prefs.setInt('mqtt_port', int.parse(_portController.text));
  }

  Future<void> _connect() async {
    try {
      await _saveSettings();
      
      _config = MerkleKVConfig.create(
        mqttHost: _brokerController.text,
        mqttPort: int.parse(_portController.text),
        mqttUseTls: false,
        clientId: _clientId,
        nodeId: _nodeId,
        topicPrefix: 'merkle_demo',
        persistenceEnabled: false,
      );

      // Initialize storage
      _storage = InMemoryStorage(_config!);
      await _storage!.initialize();

      // Initialize MQTT client
      _mqttClient = MqttClientImpl(_config!);
      
      // Setup connection state listener
      _mqttClient!.connectionState.listen((state) {
        setState(() {
          _connectionStatus = state.toString().split('.').last;
        });
      });

      // Initialize command processor
      _commandProcessor = CommandProcessorImpl(
        _config!,
        _storage!,
      );

      // Initialize replication publisher (after MQTT client)
      final topicScheme = TopicScheme.create(_config!.topicPrefix, _config!.clientId);
      _replicationPublisher = ReplicationEventPublisherImpl(
        config: _config!,
        mqttClient: _mqttClient!,
        topicScheme: topicScheme,
        metrics: InMemoryReplicationMetrics(),
      );

      // Initialize command correlator
      _commandCorrelator = CommandCorrelator(
        publishCommand: (jsonPayload) async {
          final topic = TopicScheme.create(_config!.topicPrefix, _config!.clientId).commandTopic;
          await _mqttClient!.publish(topic, jsonPayload);
        },
        logger: (entry) {
          if (kDebugMode) {
            print('Command log: $entry');
          }
        },
      );

      // Connect to MQTT broker
      await _mqttClient!.connect();
      
      // Setup command topic subscription
      await _mqttClient!.subscribe(topicScheme.commandTopic, (topic, payload) async {
        try {
          final command = Command.fromJson(jsonDecode(payload));
          final response = await _commandProcessor!.processCommand(command);
          await _mqttClient!.publish(topicScheme.responseTopic, jsonEncode(response.toJson()));
        } catch (e) {
          if (kDebugMode) {
            print('Error processing command: $e');
          }
        }
      });

      // Subscribe to response topic
      await _mqttClient!.subscribe(topicScheme.responseTopic, (topic, payload) {
        _commandCorrelator!.onResponse(payload);
      });

      // Initialize replication publisher
      await _replicationPublisher!.initialize();

      setState(() {
        _lastOperation = 'Connected successfully';
        _lastResult = 'Client ID: $_clientId\nNode ID: $_nodeId';
      });

      await _refreshData();
      
    } catch (e) {
      setState(() {
        _connectionStatus = 'Error';
        _lastOperation = 'Connection failed';
        _lastResult = e.toString();
      });
    }
  }

  Future<void> _disconnect() async {
    try {
      await _replicationPublisher?.dispose();
      await _mqttClient?.disconnect();
      await _storage?.dispose();
      _commandCorrelator?.dispose();
      
      setState(() {
        _connectionStatus = 'Disconnected';
        _lastOperation = 'Disconnected';
        _lastResult = '';
        _allData.clear();
      });
    } catch (e) {
      setState(() {
        _lastOperation = 'Disconnect error';
        _lastResult = e.toString();
      });
    }
  }

  Future<void> _performGet() async {
    if (_commandCorrelator == null) return;
    
    try {
      final command = Command(
        id: const Uuid().v4(),
        op: 'GET',
        key: _keyController.text,
      );

      final response = await _commandCorrelator!.send(command);
      
      setState(() {
        _lastOperation = 'GET ${_keyController.text}';
        _lastResult = response.value ?? '(null)';
      });
      
      await _refreshData();
    } catch (e) {
      setState(() {
        _lastOperation = 'GET Error';
        _lastResult = e.toString();
      });
    }
  }

  Future<void> _performSet() async {
    if (_commandCorrelator == null) return;
    
    try {
      final command = Command(
        id: const Uuid().v4(),
        op: 'SET',
        key: _keyController.text,
        value: _valueController.text,
      );

      final response = await _commandCorrelator!.send(command);
      
      setState(() {
        _lastOperation = 'SET ${_keyController.text} = ${_valueController.text}';
        _lastResult = response.status.toString();
      });
      
      await _refreshData();
    } catch (e) {
      setState(() {
        _lastOperation = 'SET Error';
        _lastResult = e.toString();
      });
    }
  }

  Future<void> _performDelete() async {
    if (_commandCorrelator == null) return;
    
    try {
      final command = Command(
        id: const Uuid().v4(),
        op: 'DEL',
        key: _keyController.text,
      );

      final response = await _commandCorrelator!.send(command);
      
      setState(() {
        _lastOperation = 'DEL ${_keyController.text}';
        _lastResult = response.status.toString();
      });
      
      await _refreshData();
    } catch (e) {
      setState(() {
        _lastOperation = 'DEL Error';
        _lastResult = e.toString();
      });
    }
  }

  Future<void> _performKeys() async {
    if (_commandCorrelator == null) return;
    
    try {
      final command = Command(
        id: const Uuid().v4(),
        op: 'KEYS',
        key: '*',
      );

      final response = await _commandCorrelator!.send(command);
      
      setState(() {
        _lastOperation = 'KEYS *';
        _lastResult = (response.value as List<dynamic>?)?.join(', ') ?? '(empty)';
      });
      
      await _refreshData();
    } catch (e) {
      setState(() {
        _lastOperation = 'KEYS Error';
        _lastResult = e.toString();
      });
    }
  }

  Future<void> _refreshData() async {
    if (_storage == null) return;
    
    try {
      final allEntries = await _storage!.getAllEntries();
      setState(() {
        _allData = allEntries
            .where((entry) => entry.value != null && !entry.isTombstone)
            .map((entry) => MapEntry(entry.key, {
                  'value': entry.value,
                  'seq': entry.seq,
                  'timestampMs': entry.timestampMs,
                }))
            .toList();
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing data: $e');
      }
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    _brokerController.dispose();
    _portController.dispose();
    _disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MerkleKV Mobile Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Connection', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _brokerController,
                            decoration: const InputDecoration(
                              labelText: 'MQTT Broker',
                              hintText: 'test.mosquitto.org',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _portController,
                            decoration: const InputDecoration(
                              labelText: 'Port',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _connectionStatus == 'Disconnected' ? _connect : null,
                          child: const Text('Connect'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _connectionStatus != 'Disconnected' ? _disconnect : null,
                          child: const Text('Disconnect'),
                        ),
                        const SizedBox(width: 16),
                        Text('Status: $_connectionStatus'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Operations section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Operations', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _keyController,
                            decoration: const InputDecoration(
                              labelText: 'Key',
                              hintText: 'Enter key',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _valueController,
                            decoration: const InputDecoration(
                              labelText: 'Value',
                              hintText: 'Enter value',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: _connectionStatus == 'connected' ? _performGet : null,
                          child: const Text('GET'),
                        ),
                        ElevatedButton(
                          onPressed: _connectionStatus == 'connected' ? _performSet : null,
                          child: const Text('SET'),
                        ),
                        ElevatedButton(
                          onPressed: _connectionStatus == 'connected' ? _performDelete : null,
                          child: const Text('DELETE'),
                        ),
                        ElevatedButton(
                          onPressed: _connectionStatus == 'connected' ? _performKeys : null,
                          child: const Text('KEYS'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Results section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Last Operation', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Operation: $_lastOperation'),
                    Text('Result: $_lastResult'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Data section
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Stored Data', style: Theme.of(context).textTheme.titleMedium),
                          const Spacer(),
                          TextButton(
                            onPressed: _refreshData,
                            child: const Text('Refresh'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _allData.isEmpty
                            ? const Center(child: Text('No data stored'))
                            : ListView.builder(
                                itemCount: _allData.length,
                                itemBuilder: (context, index) {
                                  final entry = _allData[index];
                                  final metadata = entry.value as Map<String, dynamic>;
                                  return ListTile(
                                    title: Text(entry.key),
                                    subtitle: Text(
                                      'Value: ${metadata['value']}\n'
                                      'Seq: ${metadata['seq']}, Time: ${metadata['timestampMs']}',
                                    ),
                                    dense: true,
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
