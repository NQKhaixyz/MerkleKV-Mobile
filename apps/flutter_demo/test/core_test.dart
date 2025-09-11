import 'package:flutter_test/flutter_test.dart';
import 'package:merkle_kv_core/merkle_kv_core.dart';

void main() {
  group('MerkleKV Core Unit Tests', () {
    test('MerkleKVConfig can be created', () {
      final config = MerkleKVConfig.create(
        mqttHost: 'test.mosquitto.org',
        mqttPort: 1883,
        mqttUseTls: false,
        clientId: 'test-client',
        nodeId: 'test-node',
        topicPrefix: 'test',
        persistenceEnabled: false,
      );

      expect(config.mqttHost, equals('test.mosquitto.org'));
      expect(config.mqttPort, equals(1883));
      expect(config.clientId, equals('test-client'));
      expect(config.nodeId, equals('test-node'));
    });

    test('InMemoryStorage can be initialized', () async {
      final config = MerkleKVConfig.create(
        mqttHost: 'test.mosquitto.org',
        clientId: 'test-client',
        nodeId: 'test-node',
        persistenceEnabled: false,
      );

      final storage = InMemoryStorage(config);
      await storage.initialize();

      expect(storage, isNotNull);
      
      await storage.dispose();
    });

    test('Storage can store and retrieve values', () async {
      final config = MerkleKVConfig.create(
        mqttHost: 'test.mosquitto.org',
        clientId: 'test-client',
        nodeId: 'test-node',
        persistenceEnabled: false,
      );

      final storage = InMemoryStorage(config);
      await storage.initialize();

      // Create a storage entry with all required parameters
      final entry = StorageEntry.value(
        key: 'test-key',
        value: 'test-value',
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        nodeId: 'test-node',
        seq: 1,
      );

      // Store the entry
      await storage.put('test-key', entry);

      // Retrieve the entry
      final retrieved = await storage.get('test-key');
      
      expect(retrieved, isNotNull);
      expect(retrieved!.value, equals('test-value'));
      expect(retrieved.seq, equals(1));
      
      await storage.dispose();
    });

    test('Command can be created and serialized', () {
      const command = Command(
        id: 'test-id',
        op: 'SET',
        key: 'test-key',
        value: 'test-value',
      );

      expect(command.id, equals('test-id'));
      expect(command.op, equals('SET'));
      expect(command.key, equals('test-key'));
      expect(command.value, equals('test-value'));

      // Test JSON serialization
      final json = command.toJson();
      expect(json['id'], equals('test-id'));
      expect(json['op'], equals('SET'));
      expect(json['key'], equals('test-key'));
      expect(json['value'], equals('test-value'));
    });

    test('Response can be created', () {
      const response = Response(
        id: 'test-id',
        status: ResponseStatus.ok,
        value: 'test-value',
      );

      expect(response.id, equals('test-id'));
      expect(response.status, equals(ResponseStatus.ok));
      expect(response.value, equals('test-value'));
    });

    test('CommandProcessor can process commands', () async {
      final config = MerkleKVConfig.create(
        mqttHost: 'test.mosquitto.org',
        clientId: 'test-client',
        nodeId: 'test-node',
        persistenceEnabled: false,
      );

      final storage = InMemoryStorage(config);
      await storage.initialize();

      final processor = CommandProcessorImpl(
        config,
        storage,
      );

      // Test SET command
      const setCommand = Command(
        id: 'set-test',
        op: 'SET',
        key: 'test-key',
        value: 'test-value',
      );

      final setResponse = await processor.processCommand(setCommand);
      expect(setResponse.status, equals(ResponseStatus.ok));

      // Test GET command
      const getCommand = Command(
        id: 'get-test',
        op: 'GET',
        key: 'test-key',
      );

      final getResponse = await processor.processCommand(getCommand);
      expect(getResponse.status, equals(ResponseStatus.ok));
      expect(getResponse.value, equals('test-value'));

      await storage.dispose();
    });
  });
}
