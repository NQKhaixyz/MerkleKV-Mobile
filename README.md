# MerkleKV Mobile

> **🚀 Ready to Start?** Check out our [**Complete Tutorial**](TUTORIAL.md) for step-by-step setup and testing!

A distributed key-value store optimized for mobile edge devices with MQTT-based communication and replication.

## 📋 Table of Contents

- [📱 Overview](#-overview)
- [🚀 Getting Started](#-getting-started)
- [📖 Documentation](#-documentation)
- [🏗️ Architecture](#️-architecture)
- [📚 API Reference](#-api-reference)
- [🔄 Replication System](#-replication-system)
- [💻 Implementation Details](#-implementation-details)
- [🧪 Testing Strategy](#-testing-strategy)
- [📊 Performance Considerations](#-performance-considerations)
- [📱 Platform Support](#-platform-support)
- [🔒 Security Considerations](#-security-considerations)
- [🤝 Contributing](#-contributing)

## 📱 Overview

MerkleKV Mobile is a lightweight, distributed key-value store designed specifically for mobile edge
devices. Unlike the original MerkleKV that uses a TCP server for client-server communication,
MerkleKV Mobile uses MQTT for all communications, making it ideal for mobile environments where
opening TCP ports is not feasible.

The system provides:

- In-memory key-value storage
- Real-time data synchronization between devices
- MQTT-based request-response communication pattern
- Efficient Merkle tree-based anti-entropy synchronization
- Device-specific message routing using client IDs

## What's New (Enhanced Replication System)

### Recent Updates (PR #58)

- **Enhanced Event Publisher** (Locked Spec §7): Complete replication event publishing system with reliable delivery, persistent outbox queue, and comprehensive observability
- **CBOR Serialization**: Efficient binary serialization for replication events using RFC 8949 standard
- **Persistent Outbox Queue**: Buffered event delivery with offline resilience and at-least-once guarantee  
- **Monotonic Sequence Numbers**: Ordered event delivery with automatic recovery and gap detection
- **Comprehensive Metrics**: Built-in observability for monitoring publish rates, queue status, and delivery health
- **Production-Ready CI**: Robust GitHub Actions workflow with MQTT broker testing and smoke tests

### Core Features (Phase 1)

- **MerkleKVConfig** (Locked Spec §11): Centralized, immutable configuration with strict validation, secure credential handling, JSON (sans secrets), `copyWith`, and defaults:
  - `keepAliveSeconds=60`, `sessionExpirySeconds=86400`, `skewMaxFutureMs=300000`, `tombstoneRetentionHours=24`.
- **MQTT Client Layer** (Locked Spec §6): Connection lifecycle, exponential backoff (1s→32s, jitter ±20%), session persistence (Clean Start=false, Session Expiry=24h), LWT, QoS=1 & retain=false enforcement, TLS when credentials present.
- **Command Correlation Layer** (Locked Spec §3.1-3.2): Request/response correlation with UUIDv4 generation, operation-specific timeouts (10s/20s/30s), deduplication cache (10min TTL, LRU eviction), payload size validation (512 KiB limit), structured logging, and async/await API over MQTT.
- **Command Processor** (Locked Spec §4.1-§4.4): Core command processing with GET/SET/DEL operations, UTF-8 size validation (keys ≤256B, values ≤256KiB), version vector generation with sequence numbers, idempotency cache with TTL and LRU eviction, comprehensive error handling with standardized error codes.
- **Storage Engine** (Locked Spec §5.1, §5.6, §8): In-memory key-value store with UTF-8 support, Last-Write-Wins conflict resolution using `(timestampMs, nodeId)` ordering, tombstone management with 24-hour retention and garbage collection, optional persistence with SHA-256 checksums and corruption recovery, size constraints (keys ≤256B, values ≤256KiB UTF-8).
- **Replication Event Publishing** (Locked Spec §7): At-least-once delivery with MQTT QoS=1, persistent outbox queue for offline buffering, monotonic sequence numbers with recovery, CBOR serialization, comprehensive observability metrics for monitoring publish rates and outbox status.

### Storage Engine Features

The core storage engine provides:

- **In-memory key-value operations** with concurrent-safe access
- **Last-Write-Wins conflict resolution** per Locked Spec §5.1:
  - Primary ordering by `timestampMs` (wall clock)
  - Tiebreaker by `nodeId` (lexicographic)
  - Duplicate detection for identical version vectors
- **Tombstone lifecycle management** per Locked Spec §5.6:
  - Delete operations create tombstones (24-hour retention)
  - Automatic garbage collection of expired tombstones
  - Read-your-writes consistency (tombstones return null)
- **Optional persistence** with integrity guarantees:
  - Append-only JSON Lines format with SHA-256 checksums
  - Corruption recovery (skip bad records, continue loading)
  - Atomic file operations prevent data loss
- **UTF-8 size validation** per Locked Spec §11:
  - Keys: ≤256 bytes UTF-8 encoded
  - Values: ≤256 KiB bytes UTF-8 encoded
  - Multi-byte character boundary handling

### Quick Storage Example

```dart
import 'package:merkle_kv_core/merkle_kv_core.dart';

// Configuration with persistence disabled (in-memory only)
final config = MerkleKVConfig(
  mqttHost: 'broker.example.com',
  clientId: 'mobile-device-1',
  nodeId: 'device-uuid-123',
  persistenceEnabled: false,
);

// Create storage instance
final storage = StorageFactory.create(config);
await storage.initialize();

// Store data with version vector
final entry = StorageEntry.value(
  key: 'user:123',
  value: 'John Doe',
  timestampMs: DateTime.now().millisecondsSinceEpoch,
  nodeId: config.nodeId,
  seq: 1,
);

await storage.put('user:123', entry);

// Retrieve data
final retrieved = await storage.get('user:123');
print(retrieved?.value); // "John Doe"

// Clean up
await storage.dispose();
```

For persistence-enabled storage:

```dart
// Configuration with persistence enabled
final persistentConfig = MerkleKVConfig(
  mqttHost: 'broker.example.com',
  clientId: 'mobile-device-1',
  nodeId: 'device-uuid-123',
  persistenceEnabled: true,
  storagePath: '/app/storage', // Platform-appropriate path
);

// Storage survives app restarts
final persistentStorage = StorageFactory.create(persistentConfig);
await persistentStorage.initialize(); // Loads existing data

// Data persists across sessions with integrity checks
```

## 🏗️ Architecture

### Communication Model

MerkleKV Mobile uses a pure MQTT communication model:

1. **Command Channel**: Each device subscribes to its own command topic based on its client ID:

   ```text
   merkle_kv_mobile/{client_id}/cmd
   ```

2. **Response Channel**: Responses are published to a client-specific response topic:

   ```text
   merkle_kv_mobile/{client_id}/res
   ```

3. **Replication Channel**: Data changes are published to a shared replication topic:

   ```text
   merkle_kv_mobile/replication/events
   ```

### Topic Scheme (Canonical)

The canonical topic scheme follows Locked Spec §2 with strict validation:

```dart
import 'package:merkle_kv_core/merkle_kv_core.dart';

final scheme = TopicScheme.create('prod/cluster-a', 'device-123');

print(scheme.commandTopic);    // prod/cluster-a/device-123/cmd
print(scheme.responseTopic);   // prod/cluster-a/device-123/res  
print(scheme.replicationTopic); // prod/cluster-a/replication/events

// Topic router manages subscribe/publish with auto re-subscribe
final router = TopicRouterImpl(config, mqttClient);
await router.subscribeToCommands((topic, payload) => handleCommand(payload));
```

### Data Flow

#### Command Execution Flow

```text
Mobile App                  MerkleKV Mobile Library               MQTT Broker
    |                               |                                  |
    |-- Command (SET user:1 value) ->|                                  |
    |                               |-- Publish to {client_id}/cmd --->|
    |                               |                                  |
    |                               |<- Subscribe to {client_id}/res --|
    |                               |                                  |
    |                               |-- Process command locally ------>|
    |                               |                                  |
    |                               |-- Publish result to {client_id}/res ->|
    |<- Response (OK) --------------|                                  |
    |                               |                                  |
```

#### Replication Flow

```text
Device 1                     MQTT Broker                    Device 2
   |                             |                             |
   |-- SET operation ----------->|                             |
   |                             |                             |
   |-- Publish change event ---->|                             |
   |                             |                             |
   |                             |-- Forward change event ---->|
   |                             |                             |
   |                             |<- Subscribe to replication -|
   |                             |                             |
   |                             |                             |-- Apply change locally
   |                             |                             |
```

## 📚 API Reference

### Command Format

Commands are sent as JSON objects to the command topic:

```json
{
  "id": "req-12345",        // Request ID for correlation
  "op": "SET",              // Operation: GET, SET, DEL, etc.
  "key": "user:123",        // Key to operate on
  "value": "john_doe",      // Value (for SET, APPEND, etc.)
  "amount": 5               // Amount (for INCR, DECR operations)
}
```

### Response Format

Responses are published as JSON objects to the response topic:

```json
{
  "id": "req-12345",        // Original request ID
  "status": "OK",           // Status: OK, NOT_FOUND, ERROR
  "value": "john_doe",      // Value (for GET operations)
  "error": "error message"  // Error description (if status is ERROR)
}
```

### Supported Operations

#### Basic Operations

- `GET`: Retrieve a value by key
- `SET`: Store a key-value pair
- `DEL`: Delete a key and its value

#### Numeric Operations

- `INCR`: Increment a numeric value (with optional amount)
- `DECR`: Decrement a numeric value (with optional amount)

#### String Operations

- `APPEND`: Append a value to an existing string
- `PREPEND`: Prepend a value to an existing string

#### Bulk Operations

- `MGET`: Get multiple keys in a single operation
- `MSET`: Set multiple key-value pairs in a single operation
- `KEYS`: List all keys matching a pattern (for debugging)

## 🔄 Replication System

### Replication Event Publishing (Issue #13 ✅)

The replication event publishing system ensures eventual consistency across distributed nodes by broadcasting all local changes via MQTT with at-least-once delivery guarantees.

#### Core Components

- **ReplicationEventPublisher**: Main interface for publishing replication events
  - At-least-once delivery using MQTT QoS=1
  - Automatic event generation from successful storage operations
  - Integration with CBOR serializer for efficient encoding

- **OutboxQueue**: Persistent FIFO queue for offline buffering
  - Events are queued during MQTT disconnection
  - Automatic flush on reconnection with order preservation
  - Bounded size with overflow policy (drops oldest events)

- **SequenceManager**: Monotonic sequence number management
  - Strictly increasing sequence numbers per node
  - Persistent storage with recovery after application restart
  - Prevents sequence number reuse across sessions

#### Delivery Guarantees

- **At-least-once delivery**: Events queued in persistent outbox if MQTT is offline
- **Idempotency support**: Events include `(node_id, seq)` for deduplication
- **Order preservation**: FIFO queue maintains local sequence order
- **Crash recovery**: Sequence state and outbox survive application restarts

#### Event Publishing Flow

```text
Storage Operation → ReplicationEvent → CBOR Encoding → MQTT Publish
                                    ↓
                            OutboxQueue (if offline)
                                    ↓
                            Flush on Reconnection
```

#### Usage Example

```dart
// Initialize publisher
final publisher = ReplicationEventPublisherImpl(
  config: config,
  mqttClient: mqttClient,
  topicScheme: topicScheme,
  metrics: InMemoryReplicationMetrics(),
);
await publisher.initialize();

// Publish event from storage operation
final entry = StorageEntry.value(
  key: 'user:123',
  value: 'John Doe',
  timestampMs: DateTime.now().millisecondsSinceEpoch,
  nodeId: config.nodeId,
  seq: 1,
);

await publisher.publishStorageEvent(entry);

// Monitor status
publisher.outboxStatus.listen((status) {
  print('Pending: ${status.pendingEvents}, Online: ${status.isOnline}');
});
```

#### Observability

The system provides comprehensive metrics for monitoring:

- `replication_events_published_total`: Total events successfully published
- `replication_publish_errors_total`: Total publish failures
- `replication_outbox_size`: Current number of queued events
- `replication_publish_latency_seconds`: Publish latency distribution
- `replication_outbox_flush_duration_seconds`: Time to flush outbox

### Change Event Format

Events are serialized using deterministic CBOR encoding and published to `{prefix}/replication/events`:

```cbor
{
  "key": "user:123",           // Key modified
  "node_id": "device-xyz",     // Source device ID  
  "seq": 42,                   // Sequence number for ordering
  "timestamp_ms": 1640995200000, // Operation timestamp (UTC ms)
  "tombstone": false,          // true for DELETE operations
  "value": "John Doe"          // Value (omitted if tombstone=true)
}
```

### CBOR Serializer (Spec §3.3)

MerkleKV uses deterministic CBOR encoding for replication change events to minimize bandwidth and ensure cross-device consistency. Payloads are strictly limited to ≤ 300 KiB (Spec §11). See [CBOR Replication Event Schema](docs/replication/cbor.md) for schema, examples, and size rules.

## 💻 Implementation Details

### Core Components

1. **Storage Engine**: In-memory key-value store with optional persistence
2. **MQTT Client**: Manages subscriptions, publications, and reconnection logic
3. **Command Processor**: Handles incoming commands and generates responses
4. **Replication Event Publisher**: Publishes change events with at-least-once delivery
5. **Sequence Manager**: Manages monotonic sequence numbers with persistence
6. **Outbox Queue**: Persistent FIFO queue for offline event buffering
7. **Merkle Tree**: Efficient data structure for anti-entropy synchronization (future)

### Message Processing Pipeline

```text
MQTT Message → JSON Parsing → Command Validation → Command Execution → 
Response Generation → Response Publishing → (Optional) Replication
```

## Configuration (MerkleKVConfig)

Locked Spec §11 defaults are applied automatically. Secrets are never serialized.

```dart
import 'package:merkle_kv_core/merkle_kv_core.dart';

final cfg = MerkleKVConfig(
  mqttHost: 'broker.example.com',
  clientId: 'android-123',
  nodeId: 'node-01',
  mqttUseTls: true,           // TLS recommended especially with credentials
  username: 'user',           // sensitive: excluded from toJson()
  password: 'pass',           // sensitive: excluded from toJson()
  persistenceEnabled: true,
  storagePath: '/data/merklekv',
);

// JSON does not include secrets
final json = cfg.toJson();
final restored = MerkleKVConfig.fromJson(json, username: 'user', password: 'pass');
```

**Defaults (per §11):** keepAlive=60, sessionExpiry=86400, skewMaxFutureMs=300000, tombstoneRetentionHours=24.

**Validation:** clientId/nodeId length ∈ [1,128]; mqttPort ∈ [1,65535]; timeouts > 0; storagePath required when persistence is enabled.

**Security:** If credentials are provided and mqttUseTls=false, a security warning is emitted.

## MQTT Client Usage

The client enforces QoS=1 and retain=false for application messages. LWT is configured automatically and suppressed on graceful disconnect.

```dart
import 'package:merkle_kv_core/merkle_kv_core.dart';

final client = MqttClientImpl(cfg); // uses MerkleKVConfig

// Observe connection state
final sub = client.connectionState.listen((s) {
  // disconnected, connecting, connected, disconnecting
});

// Connect (<=10s typical)
await client.connect();

// Subscribe
await client.subscribe('${cfg.topicPrefix}/${cfg.clientId}/cmd', (topic, payload) {
  // handle command
});

// Publish (QoS=1, retain=false enforced)
await client.publish('${cfg.topicPrefix}/${cfg.clientId}/res', '{"status":"ok"}');

// Graceful disconnect (suppresses LWT)
await client.disconnect();

// Cleanup
await sub.cancel();
```

**Reconnect:** Exponential backoff 1s→2s→4s→…→32s with ±20% jitter. Messages published during disconnect are queued (bounded) and flushed after reconnect.

**Sessions:** Clean Start=false; Session Expiry=24h.

**TLS:** Automatically enforced when credentials are present; server cert validation required.

## Command Correlation Usage

The CommandCorrelator provides async/await API over MQTT with automatic ID generation, timeouts, and deduplication.

```dart
import 'package:merkle_kv_core/merkle_kv_core.dart';

// Create correlator with MQTT publish function
final correlator = CommandCorrelator(
  publishCommand: (jsonPayload) async {
    await mqttClient.publish('${config.topicPrefix}/${targetClientId}/cmd', jsonPayload);
  },
  logger: (entry) => print('Request lifecycle: ${entry.toString()}'),
);

// Send commands with automatic correlation
final command = Command(
  id: '', // Empty ID will generate UUIDv4 automatically
  op: 'GET',
  key: 'user:123',
);

try {
  final response = await correlator.send(command);
  if (response.isSuccess) {
    print('Result: ${response.value}');
  } else {
    print('Error: ${response.error} (${response.errorCode})');
  }
} catch (e) {
  print('Request failed: $e');
}

// Handle incoming responses
mqttClient.subscribe('${config.topicPrefix}/${config.clientId}/res', (topic, payload) {
  correlator.onResponse(payload);
});

// Cleanup
correlator.dispose();
```

**Features:**
- **Automatic UUIDv4 generation** when command ID is empty
- **Operation-specific timeouts**: 10s (single-key), 20s (multi-key), 30s (sync)
- **Deduplication cache**: 10-minute TTL with LRU eviction for idempotent replies
- **Payload validation**: Rejects commands > 512 KiB
- **Structured logging**: Request lifecycle with timing and error codes
- **Late response handling**: Caches responses that arrive after timeout

## Command Processor Usage

The CommandProcessor handles core GET/SET/DEL operations with validation and idempotency.

```dart
import 'package:merkle_kv_core/merkle_kv_core.dart';

// Create processor with config and storage
final config = MerkleKVConfig.create(
  mqttHost: 'broker.example.com',
  clientId: 'device-123',
  nodeId: 'node-uuid',
);
final storage = StorageFactory.create(config);
await storage.initialize();

final processor = CommandProcessorImpl(config, storage);

// Process commands directly
final getCmd = Command(id: 'req-1', op: 'GET', key: 'user:123');
final getResponse = await processor.processCommand(getCmd);

final setCmd = Command(id: 'req-2', op: 'SET', key: 'user:123', value: 'John Doe');
final setResponse = await processor.processCommand(setCmd);

final delCmd = Command(id: 'req-3', op: 'DEL', key: 'user:123');
final delResponse = await processor.processCommand(delCmd);

// Or use individual methods
final directGet = await processor.get('user:456');
final directSet = await processor.set('user:456', 'Jane Doe');
final directDel = await processor.delete('user:456');

print('Response: ${directGet.status} - ${directGet.value}');
```

**Features:**
- **UTF-8 validation**: Keys ≤256B, values ≤256KiB with proper multi-byte handling
- **Version vectors**: Automatic generation with timestamps and sequence numbers
- **Idempotency**: 10-minute TTL cache with LRU eviction for duplicate requests
- **Error handling**: Standardized codes (INVALID_REQUEST=100, NOT_FOUND=102, PAYLOAD_TOO_LARGE=103)
- **Thread safety**: Atomic sequence number generation for concurrent operations

final store = MerkleKVMobile(config);
await store.connect();
```

## 📋 Usage Example

```dart
import 'package:merkle_kv_mobile/merkle_kv_mobile.dart';

void main() async {
  // Initialize the store
  final store = MerkleKVMobile(
    MerkleKVConfig(
      mqttBroker: 'test.mosquitto.org',
      mqttPort: 1883,
      clientId: 'mobile-${DateTime.now().millisecondsSinceEpoch}',
      nodeId: 'demo-device',
    ),
  );
  
  // Connect to MQTT broker
  await store.connect();
  
  // Set a value
  final setResult = await store.set('user:123', 'john_doe');
  print('SET result: ${setResult.status}');
  
  // Get a value
  final getResult = await store.get('user:123');
  print('GET result: ${getResult.value}');
  
  // Increment a counter
  await store.set('counter', '10');
  final incrResult = await store.incr('counter', 5);
  print('INCR result: ${incrResult.value}'); // Should be 15
  
  // Delete a value
  final delResult = await store.delete('user:123');
  print('DEL result: ${delResult.status}');
  
  // Close the connection
  await store.disconnect();
}
```

## 🏭 Implementation Steps

### Phase 1: Core Functionality

1. Implement basic MQTT client with reconnection handling
2. Create in-memory storage engine
3. Implement command processing pipeline
4. Add request-response pattern over MQTT
5. Basic GET/SET/DEL operations

### Phase 2: Advanced Operations

1. Add numeric operations (INCR/DECR)
2. Add string operations (APPEND/PREPEND)
3. Add bulk operations (MGET/MSET)
4. Implement operation timeout handling
5. Add persistent storage option

### Phase 3: Replication System

1. Implement change event serialization (CBOR)
2. Add replication event publishing
3. Implement replication event handling
4. Add Last-Write-Wins conflict resolution
5. Implement loop prevention mechanism

### Phase 4: Anti-Entropy & Optimization

1. Implement Merkle tree for efficient synchronization
2. Add anti-entropy protocol
3. Optimize message sizes
4. Add compression for large values
5. Implement efficient binary protocol

## 🧪 Testing Strategy

The MerkleKV Mobile project implements a comprehensive testing strategy covering multiple levels:

### 1. Unit Testing
- **Core Components**: Individual component isolation testing
- **Mock-based Testing**: MQTT communication mocking
- **Business Logic**: Key-value operations and conflict resolution

### 2. Integration Testing 
- **Real MQTT Brokers**: Live broker connectivity testing
- **Cross-component**: End-to-end data flow validation
- **Network Resilience**: Connection failure and recovery

### 3. Android Platform Testing
- **Automated CI/CD**: GitHub Actions with Android emulator
- **Local Testing**: `./test_android_local.sh` for development
- **End-to-End Validation**: Complete mobile app testing
- **Performance Testing**: Memory, CPU, and network monitoring

### 4. Flutter Integration Testing
- **Widget Testing**: UI component validation
- **Integration Tests**: App-level behavior testing
- **Platform Integration**: Native Android functionality

### Running Tests

#### Local Development
```bash
# Quick Android build test
./test_android_local.sh

# Comprehensive E2E testing (requires emulator)
./final_validation_test.sh

# Manual UI testing
./test_merkle_kv_manual.sh
```

#### CI/CD Workflows
- **Main Pipeline**: `.github/workflows/full_ci.yml` - Complete testing including Android
- **Android Specific**: `.github/workflows/android-testing.yml` - Dedicated Android testing
- **Quick Tests**: `.github/workflows/test.yml` - Fast unit and integration tests

#### Integration Tests (MQTT broker required)

- Start a local broker (Docker):
  ```bash
  docker run -d --rm --name mosquitto -p 1883:1883 eclipse-mosquitto:2
  ```

- Environment (defaults):
  ```bash
  export MQTT_HOST=127.0.0.1
  export MQTT_PORT=1883
  ```

- Execute tests:
  ```bash
  dart test -t integration --timeout=90s
  ```

- Enforce broker requirement (CI or strict local runs):
  ```bash
  IT_REQUIRE_BROKER=1 dart test -t integration --timeout=90s
  ```

- Stop the broker:
  ```bash
  docker stop mosquitto
  ```

Integration tests skip cleanly when no usable broker is present, unless `IT_REQUIRE_BROKER=1` is set, in which case they fail early by design.

## 📊 Performance Considerations

- **Message Size**: Use CBOR encoding for compact messages
- **Battery Impact**: Implement intelligent reconnection strategy
- **Bandwidth Usage**: Batch operations when possible
- **Storage Efficiency**: Use incremental updates for large values
- **CPU Usage**: Optimize Merkle tree calculations for mobile CPUs

## 📱 Platform Support

- Android (API level 21+)
- iOS (iOS 10+)
- Flutter compatibility
- React Native compatibility (through native bridge)

## 🔒 Security Considerations

- **Authentication**: Support for MQTT username/password and client certificates
- **Authorization**: Topic-level access control using client ID
- **Encryption**: TLS for transport security
- **Data Privacy**: Optional value encryption at rest

## 🚀 Getting Started

### Quick Start Guide

**📖 [Complete Tutorial Available](TUTORIAL.md)** - Follow our comprehensive step-by-step guide for full setup and testing.

#### Prerequisites

- **Flutter SDK** 3.10.0 or higher
- **Dart SDK** 3.0.0 or higher
- **Android Studio** with Android SDK
- **Java Development Kit (JDK)** 11 or 17
- **Git** for version control
- **Docker** (optional, for local MQTT broker)

#### Fast Setup (5 minutes)

```bash
# 1. Clone and setup
git clone https://github.com/AI-Decenter/MerkleKV-Mobile.git
cd MerkleKV-Mobile
dart pub global activate melos
melos bootstrap

# 2. Start Android emulator
emulator -avd your_device_name -no-window -no-audio &

# 3. Build and run Flutter demo
cd apps/flutter_demo
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.example.flutter_demo_new/.MainActivity
```

#### Comprehensive Testing

```bash
# Run full end-to-end validation
./final_validation_test.sh
```

**✅ Expected Result**: Complete MerkleKV Mobile system running on Android with MQTT connectivity and all CRUD operations functional.

## 📖 Documentation

### Quick Access Guides

- 📖 **[Complete Tutorial](TUTORIAL.md)** - Step-by-step setup and testing guide
- 🏃 **[Running Guide](RUNNING.md)** - Detailed instructions for all platforms
- 📊 **[Test Report](END_TO_END_TEST_REPORT.md)** - Comprehensive testing results
- 🏗️ **[Architecture](docs/architecture.md)** - System design and components
- 🔄 **[Replication](docs/replication/cbor.md)** - CBOR serialization details

### Testing and Validation

- 🧪 **Automated Testing**: `./final_validation_test.sh`
- 🖱️ **Manual Testing**: `./test_merkle_kv_manual.sh`  
- 📱 **Android Testing**: `./test_android_local.sh` - Local Android build and testing
- 📱 **Flutter Integration**: `flutter test integration_test/`
- 🔍 **Performance Monitoring**: Built-in metrics and logging
- 🤖 **CI/CD Android Testing**: Automated Android emulator testing in GitHub Actions

## Quick Start (Development)

### 1. Environment Setup

```bash
# Bootstrap monorepo
melos bootstrap

# Set up Android environment
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_HOME=/opt/android-sdk
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"

# Create and start Android emulator
echo no | avdmanager create avd -n test_device -k "system-images;android-34;google_apis;x86_64"
emulator -avd test_device -no-window -no-audio &
```

### 2. Build and Run Flutter Demo

```bash
cd apps/flutter_demo

# Build and install
flutter clean
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# Launch application
adb shell am start -n com.example.flutter_demo_new/.MainActivity
```

### 3. Test MerkleKV Operations

The Flutter demo app provides a complete UI for testing:
- **MQTT Connection**: Configure broker (default: test.mosquitto.org)
- **SET Operation**: Store key-value pairs
- **GET Operation**: Retrieve values by key
- **DELETE Operation**: Remove key-value pairs
- **KEYS Operation**: List all stored keys

### 4. Automated Testing

```bash
# Static analysis & format checks
dart analyze
dart format --output=none --set-exit-if-changed .

# Run unit tests
dart test -p vm packages/merkle_kv_core
flutter test

# Run comprehensive end-to-end tests
./final_validation_test.sh
```

### Development Setup

1. **Clone and Bootstrap the Project**:

   ```bash
   git clone https://github.com/AI-Decenter/MerkleKV-Mobile.git
   cd MerkleKV-Mobile
   
   # Install Melos for monorepo management
   dart pub global activate melos
   
   # Bootstrap all packages
   melos bootstrap
   ```

2. **Setup Android Environment**:

   ```bash
   # Configure environment variables
   export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
   export ANDROID_HOME=/opt/android-sdk
   export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"
   
   # Create Android emulator
   echo no | avdmanager create avd -n test_device -k "system-images;android-34;google_apis;x86_64"
   
   # Start emulator
   emulator -avd test_device -no-window -no-audio &
   ```

3. **Start the MQTT Broker** (Optional - Local Testing):

   ```bash
   # Navigate to broker directory
   cd broker/mosquitto
   
   # Start the broker with Docker Compose
   docker-compose up -d
   
   # Verify broker is running
   docker-compose ps
   ```

4. **Run the Flutter Demo**:

   ```bash
   cd apps/flutter_demo
   
   # Build and install
   flutter build apk --debug
   adb install -r build/app/outputs/flutter-apk/app-debug.apk
   
   # Launch app
   adb shell am start -n com.example.flutter_demo_new/.MainActivity
   ```

### Quick Usage Example

1. **Add the package to your pubspec.yaml**:

   ```yaml
   dependencies:
     merkle_kv_core:
       path: ../../packages/merkle_kv_core
   ```

2. **Basic Usage**:

   ```dart
   import 'package:merkle_kv_core/merkle_kv_core.dart';

   void main() async {
     // Create configuration
     final config = MerkleKVConfig(
       mqttHost: 'broker.hivemq.com',
       clientId: 'mobile-device-1',
       nodeId: 'unique-node-id',
     );
     
     // Initialize storage
     final storage = StorageFactory.create(config);
     await storage.initialize();
     
     // Store data
     final entry = StorageEntry.value(
       key: 'user:123',
       value: 'John Doe',
       timestampMs: DateTime.now().millisecondsSinceEpoch,
       nodeId: config.nodeId,
       seq: 1,
     );
     await storage.put('user:123', entry);
     
     // Retrieve data
     final result = await storage.get('user:123');
     print('Retrieved: ${result?.value}'); // "John Doe"
     
     await storage.dispose();
   }
   ```

3. **Flutter Demo App Features**:

   - ✅ Real-time MQTT connection management
   - ✅ Complete CRUD operations (SET, GET, DELETE, KEYS)
   - ✅ Live data display and operation feedback
   - ✅ Multiple MQTT broker support
   - ✅ Persistent storage options
   - ✅ Material Design 3 UI

### Project Structure
       ),
     );
     
     // Connect to the broker
     await store.connect();
     
     // Use the store
     await store.set('profile:name', 'John Doe');
     final result = await store.get('profile:name');
     print('Retrieved: ${result.value}');
     
     // Clean up
     await store.disconnect();
   }
   ```

### Project Structure

```text
MerkleKV-Mobile/
├── packages/
│   └── merkle_kv_core/          # Core Dart implementation
├── apps/
│   └── flutter_demo/            # Flutter demonstration app
├── broker/
│   └── mosquitto/               # MQTT broker configuration
├── scripts/
│   └── dev/                     # Development automation
├── docs/                        # Technical documentation
├── .github/workflows/           # CI/CD automation
├── TUTORIAL.md                  # Complete setup guide
├── final_validation_test.sh     # End-to-end testing script
└── test_merkle_kv_manual.sh     # Manual testing utilities
```

### Development Commands

```bash
# Analyze code across all packages
melos run analyze

# Format code across all packages
melos run format

# Run tests across all packages
melos run test

# Start development broker
./scripts/dev/start_broker.sh

# Setup development environment
./scripts/dev/setup.sh
```

### Code Formatting

This project enforces strict Dart formatting in CI.  
Before committing or opening a PR, always run:

```bash
dart format .
```

If formatting is not applied, CI will fail.

## 🎯 Future Roadmap

MerkleKV Mobile v1.0.0 is production-ready with all core features implemented. Future enhancements may include:

- 🔄 **Enhanced Replication**: Merkle tree-based anti-entropy synchronization
- 📱 **iOS Support**: Native iOS implementation and testing
- 🔒 **Advanced Security**: End-to-end encryption and advanced authentication
- ⚡ **Performance Optimization**: Enhanced caching and compression
- 🌐 **Web Support**: Progressive Web App implementation
- 📊 **Monitoring Dashboard**: Real-time system monitoring and analytics

## Code Style and CI Policy

This repository enforces strict Dart formatting in CI. All `.dart` files must pass `dart format --set-exit-if-changed`.

Developers must run the formatter locally before committing:

```bash
dart format .
```

CI will fail if formatting is not compliant.

## Release Workflow Guide

The GitHub Actions job **"Release Management & Distribution"** is **intentionally skipped** on normal
branches and pull requests. It only runs when a **semantic version tag** is pushed (e.g., `v1.0.0`,
`v1.1.0-beta.1`, `v2.0.0-rc.1`).

**When should I push a release tag?**

- After a milestone is complete and CI is green (Static Analysis, Tests, Documentation all passing).
- When publishing a versioned package or a public snapshot for users/contributors.
- Not for every small change (to avoid release spam).

**Tag types (SemVer):**

- Stable: `vX.Y.Z` (e.g., `v1.0.0`)
- Pre-release: `vX.Y.Z-alpha.N`, `vX.Y.Z-beta.N`
- Release Candidate: `vX.Y.Z-rc.N`

**How to create and push a release tag:**

```bash
# Ensure you're on main and CI is green
git checkout main
git pull origin main

# Create a semantic version tag
git tag v0.1.0

# Push the tag to trigger the Release job
git push origin v0.1.0
```

**What happens after pushing the tag?**

The Release job runs and:

- Validates code quality (pre-release gates)
- Builds source distribution & checksums
- Generates detailed release notes
- Publishes a GitHub Release with artifacts

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details on:

- Code of conduct
- Development workflow
- Pull request process
- Issue reporting guidelines

### Development Status

| Component | Status | Description |
|-----------|---------|-------------|
| **Core Package** | ✅ Complete | Full MerkleKV core implementation with MQTT |
| **Flutter Demo** | ✅ Complete | Production-ready mobile application |
| **MQTT Integration** | ✅ Complete | Real MQTT broker connectivity tested |
| **Android Support** | ✅ Complete | Full Android deployment and testing |
| **CRUD Operations** | ✅ Complete | SET, GET, DELETE, KEYS all functional |
| **End-to-End Testing** | ✅ Complete | Comprehensive automated test suite |
| **CI/CD Pipeline** | ✅ Complete | Enterprise-grade automation |
| **Documentation** | ✅ Complete | Complete tutorials and API docs |

**🎉 Project Status: PRODUCTION READY** - All core features implemented and tested on Android emulator.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙋‍♂️ Support

- 📖 **Documentation**: [docs/](docs/)
- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/AI-Decenter/MerkleKV-Mobile/issues)
- 💡 **Feature Requests**: [GitHub Discussions](https://github.com/AI-Decenter/MerkleKV-Mobile/discussions)
- 🔒 **Security Issues**: See [SECURITY.md](SECURITY.md)

---

## Made with ❤️ for mobile distributed systems
