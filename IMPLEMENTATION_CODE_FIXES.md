# Implementation Code Fixes for Memory Optimization

## Fix #1: HttpClient Memory Leak (CRITICAL)

### Problem Location
`lib/app/data/services/backend_process_service.dart:83-107`

### Current Code (BROKEN)
```dart
Future<bool> _isBackendReady() async {
  try {
    final uri = Uri.parse(_appController.backendUrl.value);
    final client = HttpClient();  // ❌ Creates new client each call
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(milliseconds: 700));
    final response = await request
        .close()
        .timeout(const Duration(milliseconds: 700));
    await response.drain();
    client.close();
    return response.statusCode >= 200 && response.statusCode < 500;
  } catch (_) {
    return false;
  }
}
```

### Fixed Code
```dart
// Add this at the class level
static final HttpClient _httpClient = HttpClient()
  ..connectionTimeout = const Duration(milliseconds: 700);

Future<bool> _isBackendReady() async {
  try {
    final uri = Uri.parse(_appController.backendUrl.value);
    final request = await _httpClient
        .getUrl(uri)
        .timeout(const Duration(milliseconds: 700));
    final response = await request
        .close()
        .timeout(const Duration(milliseconds: 700));
    await response.drain();
    return response.statusCode >= 200 && response.statusCode < 500;
  } catch (_) {
    return false;
  }
}

@override
void onClose() {
  _httpClient.close(force: true);
  // Sengaja tidak kill backend jika ingin backend tetap hidup.
  super.onClose();
}
```

---

## Fix #2: Remove Permanent HomeController (CRITICAL)

### Problem Location
`lib/app/modules/home/bindings/home_binding.dart:8`

### Current Code (BROKEN)
```dart
import 'package:get/get.dart';

import '../controllers/home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<HomeController>(HomeController(), permanent: true);  // ❌ BUG
  }
}
```

### Fixed Code
```dart
import 'package:get/get.dart';

import '../controllers/home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    // Remove permanent: true - this should be route-scoped
    Get.put<HomeController>(HomeController());
  }
}
```

---

## Fix #3: StreamController Debouncing (CRITICAL)

### Problem Location
`lib/app/data/services/bluetooth_event_service.dart:16-19`

### Current Code (BROKEN)
```dart
final StreamController<BluetoothEventModel> _eventController =
    StreamController<BluetoothEventModel>.broadcast();  // ❌ No buffer management

Stream<BluetoothEventModel> get events => _eventController.stream;
```

### Fixed Code (Option A: Using Timer-based debounce)
```dart
final StreamController<BluetoothEventModel> _eventController =
    StreamController<BluetoothEventModel>.broadcast();

Timer? _debounceTimer;
late StreamController<BluetoothEventModel> _debouncedController;

@override
void onInit() {
  super.onInit();
  _debouncedController = StreamController<BluetoothEventModel>.broadcast();
}

Stream<BluetoothEventModel> get events => _debouncedController.stream;

void _handleMessage(dynamic message) {
  if (message is! String) {
    return;
  }
  final decoded = jsonDecode(message);
  if (decoded is! Map<String, dynamic>) {
    return;
  }
  
  // Debounce: cancel previous timer and create new one
  _debounceTimer?.cancel();
  _debounceTimer = Timer(const Duration(milliseconds: 100), () {
    final event = BluetoothEventModel.fromJson(decoded);
    _debouncedController.add(event);
  });
}

@override
void onClose() {
  _debounceTimer?.cancel();
  _debouncedController.close();
  _eventController.close();
  super.onClose();
}
```

### Fixed Code (Option B: Using rxdart - RECOMMENDED)
```dart
import 'package:rxdart/rxdart.dart';

final _eventSubject = ReplaySubject<BluetoothEventModel>(
  maxSize: 10,  // Keep only last 10 events
);

Stream<BluetoothEventModel> get events => _eventSubject.stream.throttleTime(
  const Duration(milliseconds: 100),  // Only emit max once per 100ms
);

void _handleMessage(dynamic message) {
  if (message is! String) {
    return;
  }
  try {
    final decoded = jsonDecode(message);
    if (decoded is! Map<String, dynamic>) {
      return;
    }
    final event = BluetoothEventModel.fromJson(decoded);
    _eventSubject.add(event);
  } catch (e) {
    debugPrint('Error parsing event: $e');
  }
}

@override
void onClose() {
  _eventSubject.close();
  super.onClose();
}
```

Note: Add to pubspec.yaml:
```yaml
dependencies:
  rxdart: ^0.27.7
```

---

## Fix #4: WebSocket Reconnect Exponential Backoff (HIGH)

### Problem Location
`lib/app/data/services/bluetooth_event_service.dart:74-80`

### Current Code (BROKEN)
```dart
void _reconnectLater() {
  Future.delayed(const Duration(seconds: 3), () {  // ❌ Fixed delay, no max retries
    if (_socket == null) {
      connect();
    }
  });
}
```

### Fixed Code
```dart
int _reconnectAttempts = 0;
Timer? _reconnectTimer;
static const int _maxReconnectAttempts = 5;
static const Duration _baseBackoffDuration = Duration(seconds: 1);

void _reconnectLater() {
  if (_reconnectAttempts >= _maxReconnectAttempts) {
    debugPrint('Max reconnection attempts reached');
    return;
  }

  // Exponential backoff: 1s, 2s, 4s, 8s, 16s
  final backoffDuration = _baseBackoffDuration * (1 << _reconnectAttempts);
  _reconnectAttempts++;

  _reconnectTimer?.cancel();
  _reconnectTimer = Timer(backoffDuration, () {
    if (_socket == null) {
      connect();
    }
  });
}

Future<void> connect() async {
  if (_socket != null) {
    return;
  }

  try {
    final wsUrl = _buildWebSocketUrl(_appController.backendUrl.value);
    _socket = await WebSocket.connect(wsUrl);
    _reconnectAttempts = 0;  // Reset on successful connection
    connected.value = true;
    // ... rest of code
  } catch (_) {
    _cleanup();
    _reconnectLater();
  }
}

void _cleanup() {
  _subscription = null;
  _socket = null;
  connected.value = false;
}

@override
void onClose() {
  _reconnectTimer?.cancel();
  disconnect();
  _eventController.close();
  super.onClose();
}
```

---

## Fix #5: TextEditingController Disposal (HIGH)

### Problem Location
`lib/app/modules/settings/views/settings_view.dart:12-14`

### Current Code (BROKEN)
```dart
class SettingsView extends GetView<AppController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final backendUrlController = TextEditingController(
      text: controller.backendUrl.value,
    );  // ❌ Created on every build, never disposed

    return Scaffold(
      // ...
    );
  }
}
```

### Fixed Code
```dart
class SettingsView extends GetView<AppController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return _SettingsViewContent();
  }
}

class _SettingsViewContent extends StatefulWidget {
  const _SettingsViewContent();

  @override
  State<_SettingsViewContent> createState() => _SettingsViewContentState();
}

class _SettingsViewContentState extends State<_SettingsViewContent> {
  late TextEditingController backendUrlController;
  final appController = Get.find<AppController>();

  @override
  void initState() {
    super.initState();
    backendUrlController = TextEditingController(
      text: appController.backendUrl.value,
    );
  }

  @override
  void dispose() {
    backendUrlController.dispose();  // ✓ Explicit cleanup
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 700;
    final maxWidth = isCompact ? double.infinity : 760.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: ListView(
                  padding: EdgeInsets.all(isCompact ? 14 : 24),
                  children: [
                    // ... rest of settings UI
                    TextField(
                      controller: backendUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Backend URL',
                        hintText: 'http://127.0.0.1:8787',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (value) async {
                        await appController.setBackendUrl(value);
                        Get.snackbar(
                          'Saved',
                          'Backend URL updated',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      },
                    ),
                    // ... rest of content
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
```

---

## Fix #6: Debounce Timer in HomeController (HIGH)

### Problem Location
`lib/app/modules/home/controllers/home_controller.dart:76-80`

### Current Code (BROKEN)
```dart
late Timer? _refreshDebounce;

Future<void> _connectEventStream() async {
  await _eventService.connect();
  _eventSubscription = _eventService.events.listen((_) {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 400), () {
      refreshData();  // ❌ Creates new Timer on every event
    });
  });
}
```

### Fixed Code (using simple extension)
```dart
import 'dart:async';

extension DebouncerExtension<T> on StreamSubscription<T> {
  void debounce(Duration duration, Function() callback) {
    Timer? timer;
    listen(
      (_) {
        timer?.cancel();
        timer = Timer(duration, callback);
      },
      onError: (e) {
        timer?.cancel();
        throw e;
      },
      onDone: () {
        timer?.cancel();
      },
    );
  }
}

class HomeController extends GetxController {
  late StreamSubscription? _eventSubscription;
  late Timer? _refreshDebounce;

  @override
  void onClose() {
    _eventSubscription?.cancel();
    _refreshDebounce?.cancel();
    super.onClose();
  }

  Future<void> _connectEventStream() async {
    await _eventService.connect();
    _eventSubscription = _eventService.events.listen(
      (_) {
        // Cancel previous timer
        _refreshDebounce?.cancel();
        // Create new debounce timer
        _refreshDebounce = Timer(const Duration(milliseconds: 400), () {
          refreshData();
        });
      },
      onError: (_) {
        _refreshDebounce?.cancel();
      },
      onDone: () {
        _refreshDebounce?.cancel();
      },
    );
  }
}
```

Or use the `debounce` package:
```yaml
dependencies:
  debounce: ^2.0.0
```

```dart
import 'package:debounce/debounce.dart';

class HomeController extends GetxController {
  late StreamSubscription? _eventSubscription;

  Future<void> _connectEventStream() async {
    await _eventService.connect();
    _eventSubscription = _eventService.events.listen(
      debounce(
        const Duration(milliseconds: 400),
        () => refreshData(),
      ),
    );
  }
}
```

---

## Fix #7: Add Keys to List Items (HIGH)

### Problem Location
`lib/app/modules/home/views/home_view.dart:451-481`

### Current Code (BROKEN)
```dart
if (layoutMode == DeviceLayoutMode.compact) {
  return ListView.separated(
    itemCount: devices.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      return _DeviceCompactTile(device: devices[index]);  // ❌ No key
    },
  );
}

if (layoutMode == DeviceLayoutMode.tile || isCompact) {
  return ListView.separated(
    itemCount: devices.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (context, index) {
      return _DeviceTile(device: devices[index]);  // ❌ No key
    },
  );
}

return GridView.builder(
  itemCount: devices.length,
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: _getCrossAxisCount(MediaQuery.sizeOf(context).width),
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    mainAxisExtent: 170,
  ),
  itemBuilder: (context, index) {
    return _DeviceGridCard(device: devices[index]);  // ❌ No key
  },
);
```

### Fixed Code
```dart
if (layoutMode == DeviceLayoutMode.compact) {
  return ListView.separated(
    addAutomaticKeepAlives: false,  // ✓ Don't keep offscreen alive
    cacheExtent: 500,  // ✓ Cache 500dp beyond visible
    itemCount: devices.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      final device = devices[index];
      return _DeviceCompactTile(
        key: ValueKey(device.path),  // ✓ Stable key
        device: device,
      );
    },
  );
}

if (layoutMode == DeviceLayoutMode.tile || isCompact) {
  return ListView.separated(
    addAutomaticKeepAlives: false,  // ✓ Don't keep offscreen alive
    cacheExtent: 500,  // ✓ Cache 500dp beyond visible
    itemCount: devices.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (context, index) {
      final device = devices[index];
      return _DeviceTile(
        key: ValueKey(device.path),  // ✓ Stable key
        device: device,
      );
    },
  );
}

return GridView.builder(
  addAutomaticKeepAlives: false,  // ✓ Don't keep offscreen alive
  cacheExtent: 500,  // ✓ Cache 500dp beyond visible
  itemCount: devices.length,
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: _getCrossAxisCount(MediaQuery.sizeOf(context).width),
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    mainAxisExtent: 170,
  ),
  itemBuilder: (context, index) {
    final device = devices[index];
    return _DeviceGridCard(
      key: ValueKey(device.path),  // ✓ Stable key
      device: device,
    );
  },
);
```

---

## Fix #8: Optimize Obx Rebuilds with GetBuilder (MEDIUM)

### Problem Location
`lib/app/modules/home/views/home_view.dart:19-43`

### Current Code (BROKEN)
```dart
@override
Widget build(BuildContext context) {
  return Obx(() {  // ❌ Entire widget watches ALL changes
    final layoutMode = controller.layoutMode.value;

    return AppShell(
      title: 'Devices',
      actions: [
        // ...
      ],
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // ... 100+ lines affected by layoutMode change
          },
        ),
      ),
    );
  });
}
```

### Fixed Code
```dart
@override
Widget build(BuildContext context) {
  return AppShell(
    title: 'Devices',
    actions: [
      IconButton(
        onPressed: () {
          Get.find<HomeController>().refreshData();
        },
        icon: const Icon(Icons.refresh_rounded),
      ),
      IconButton(
        onPressed: () {
          Get.toNamed(Routes.SETTINGS);
        },
        icon: const Icon(Icons.settings_rounded),
      ),
    ],
    child: SafeArea(
      child: GetBuilder<AppController>(
        id: 'layout',  // Only rebuild when layout changes
        builder: (appController) {
          final layoutMode = appController.layoutMode.value;
          
          return LayoutBuilder(
            builder: (context, constraints) {
              // ... rest of content
            },
          );
        },
      ),
    ),
  );
}
```

---

## Summary of Changes

### pubspec.yaml - Add Dependencies
```yaml
dependencies:
  # ... existing
  rxdart: ^0.27.7  # For StreamController optimization
```

### Testing the Fixes

Run memory profiling:
```bash
flutter run --profile

# Then in another terminal:
flutter devtools
# Open DevTools > Memory tab
# Monitor during app usage
```

Check for improvements:
```bash
# Analyze code quality
flutter analyze

# Profile memory
dart run custom_lint
```

---

## Implementation Checklist

- [ ] Apply Fix #1: HttpClient singleton
- [ ] Apply Fix #2: Remove permanent HomeController
- [ ] Apply Fix #3: StreamController debouncing (pick Option A or B)
- [ ] Apply Fix #4: WebSocket exponential backoff
- [ ] Apply Fix #5: TextEditingController disposal
- [ ] Apply Fix #6: Proper debounce timer management
- [ ] Apply Fix #7: Add ValueKey to list items
- [ ] Apply Fix #8: Replace Obx with GetBuilder
- [ ] Test with Flutter DevTools Memory profiler
- [ ] Measure before/after memory usage
- [ ] Check performance improvements

