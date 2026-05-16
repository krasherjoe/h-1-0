# Testing Patterns

**Analysis Date:** 2026-05-16

## Test Framework

**Runner:**
- Flutter Test (`flutter_test` package)
- No separate test runner configuration — uses default Flutter test discovery

**Config:**
- `pubspec.yaml` declares `flutter_test` as dev dependency
- No `test/` directory configuration file (e.g., no `pubspec_overrides.yaml` test config)
- Widget tests initialize binding via `TestWidgetsFlutterBinding.ensureInitialized()`
- SQLite FFI initialization in widget test: `sqfliteFfiInit(); databaseFactory = databaseFactoryFfi;`

**Assertion Library:**
- Built-in Flutter assertions from `flutter_test`: `expect()`, `find.byType()`, `find.text()`, `findsOneWidget`, `findsNothing`, `findsAtLeastNWidgets`
- Mockito matchers: `isNotNull`, `isA<T>()`, `any`, `argThat()`

**Run Commands:**
```bash
flutter test                    # Run all tests
flutter test test/unit/         # Run only unit tests
flutter test --coverage         # Run with coverage
flutter analyze --no-fatal-infos  # Code analysis (not a test, but used for quality gate)
```

## Test File Organization

**Location:**
- `test/widget_test.dart` — single integration/widget test (app initialization)
- `test/unit/` — all unit and widget tests organized by layer:
  - `test/unit/models/` — model serialization, validation, business logic tests
  - `test/unit/services/` — repository/service tests with mocked dependencies
  - `test/unit/widgets/` — widget interaction tests

**Naming:**
- `{source_file}_test.dart` — mirrors source file name: `customer_model_test.dart`, `document_card_test.dart`
- `{service_name}_test.mocks.dart` — auto-generated mockito mocks alongside test files
- Test group names use descriptive Japanese or English phrases matching the feature

**Structure:**
```
test/
├── widget_test.dart                    # App-level integration test
└── unit/
    ├── models/
    │   ├── business_profile_model_test.dart
    │   ├── customer_model_test.dart
    │   └── hash_chain_test.dart
    ├── services/
    │   ├── business_profile_repository_test.dart
    │   ├── business_profile_repository_test.mocks.dart
    │   ├── inventory_location_repository_test.dart
    │   └── inventory_location_repository_test.mocks.dart
    └── widgets/
        ├── document_card_test.dart
        ├── empty_state_widget_test.dart
        └── hash_chain_test.dart
```

## Test Structure

**Suite Organization:**
```dart
void main() {
  group('Customer', () {
    test('should create customer correctly', () { ... });
    test('should convert to map correctly', () { ... });
    
    group('hash chain verification', () {
      test('should verify valid hash chain', () { ... });
      test('should detect tampered hash', () { ... });
    });
  });
}
```

**Patterns:**
- `group()` for logical grouping by feature or method
- Nested `group()` for sub-categories (e.g., "hash chain verification" under Customer)
- Individual `test()` blocks for specific behaviors

**Setup/Teardown:**
```dart
// Service tests use setUp() for mock initialization
setUp(() {
  mockDb = MockDatabaseHelper();
  repository = InventoryLocationRepository();
});
```

**Assertion Patterns:**
- Value equality: `expect(result.length, 2)`
- Type checking: `expect(repository, isA<InventoryLocationRepository>())`
- Non-null: `expect(profile.id, isNotNull)`, `expect(profile.id, isNotEmpty)`
- Widget existence: `expect(find.text(testTitle), findsOneWidget)`, `expect(find.byType(ElevatedButton), findsNothing)`
- Verification of mock calls: `verify(mockDatabase.query(...)).called(1)`

## Mocking

**Framework:** Mockito (`mockito` package with `@GenerateMocks` annotation)

**Patterns:**
```dart
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:sqflite/sqflite.dart';
import '../../../lib/services/database_helper.dart';
import 'inventory_location_repository_test.mocks.dart';  // Generated mocks

@GenerateMocks([DatabaseHelper])
void main() {
  late MockDatabaseHelper mockDb;
  
  setUp(() {
    mockDb = MockDatabaseHelper();
  });
  
  test('should return all locations', () async {
    final mockDatabase = MockDatabase();
    when(mockDatabase.query('inventory_locations'))
        .thenAnswer((_) async => [...]);
    
    final result = await repository.getAllLocations();
    expect(result.length, 2);
    verify(mockDatabase.query('inventory_locations')).called(1);
  });
}
```

**What to Mock:**
- `DatabaseHelper` — all database/repository tests mock this to isolate business logic
- `Database` (from sqflite) — mocked for query/transaction expectations
- Repository dependencies when testing higher-level services

**What NOT to Mock:**
- Model classes (`Customer`, `BusinessProfile`, etc.) — tested as pure objects with real instances
- Flutter framework widgets in widget tests — built and interacted with via `WidgetTester`

## Fixtures and Factories

**Test Data:**
```dart
// Inline test data (no external fixtures)
final mockDatabase = MockDatabase();
when(mockDatabase.query('inventory_locations')).thenAnswer((_) async => [
  {
    'id': 'location-1',
    'warehouse_id': 'warehouse-1',
    'location_code': 'A-01',
    'location_name': 'ロケーションA-01',
    'description': 'テスト用ロケーション1',
    'is_active': 1,
    'created_at': '2023-01-01T00:00:00.000Z',
    'updated_at': '2023-01-02T00:00:00.000Z',
  },
]);

// Model instances created inline
final profile = BusinessProfile(
  id: 'test-id',
  businessType: BusinessType.service,
  productUnits: ['件', '時間'],
  needsInventory: false,
  needsGPS: true,
  needsPhotos: false,
  workflow: WorkflowType.service,
  pricing: PricingType.custom,
  createdAt: DateTime(2023, 1, 1),
  updatedAt: DateTime(2023, 1, 2),
);
```

**Location:**
- All test data is inline — no external fixture files or factories detected
- `test/unit/models/business_profile_model_test.dart` uses `BusinessProfile.defaultProfile()` factory for default instance testing

## Coverage

**Requirements:** No enforced coverage target. No coverage configuration in `pubspec.yaml` or analysis_options.

**View Coverage:**
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

**Current State:** ~15 test files total, covering approximately:
- Model serialization (Customer, BusinessProfile) ✓
- Hash chain integrity verification ✓
- Widget interaction (DocumentCard, EmptyStateWidget) ✓
- Repository query logic with mocked DatabaseHelper ✓
- Large gaps in screen-level testing, service business logic, and integration paths

## Test Types

**Unit Tests:**
- **Scope:** Model serialization/deserialization, hash chain verification, repository query mapping
- **Approach:** Pure Dart tests (no Flutter framework), using `flutter_test` for assertions only
- **Example:** `test/unit/models/customer_model_test.dart` — tests fields, toJson/fromJson, copyWith, hash chain

**Widget Tests:**
- **Scope:** Widget rendering, user interaction (tap, text input), state changes
- **Framework:** `flutter_test` with `WidgetTester`
- **Pattern:** `pumpWidget()` → `tester.tap()` → `pump()` → `expect()`
- **Example:** `test/unit/widgets/empty_state_widget_test.dart` — 9 test cases for rendering, interaction, edge cases

**Integration Tests:**
- **Scope:** App initialization with SQLite FFI setup
- **Location:** `test/widget_test.dart` (single integration test)
- **Pattern:** Initializes FFI database, pumps `MyApp`, verifies MaterialApp renders

**E2E Tests:**
- Not detected — no `integration_test/` directory or e2e framework configured

## Common Patterns

**Async Testing:**
```dart
test('should return all locations', () async {
  // Arrange
  when(mockDatabase.query('inventory_locations')).thenAnswer((_) async => [...]);
  
  // Act
  final result = await repository.getAllLocations();
  
  // Assert
  expect(result.length, 2);
  verify(mockDatabase.query('inventory_locations')).called(1);
});
```

**Widget Async Testing:**
```dart
testWidgets('should handle action button tap', (tester) async {
  bool actionTapped = false;
  
  await tester.pumpWidget(MaterialApp(...));
  await tester.tap(find.text(testActionLabel));
  await tester.pump();
  
  expect(actionTapped, isTrue);
});
```

**Error Testing:**
- Exception throwing tested implicitly through repository tests (mocked Database throws errors)
- No explicit negative test cases for error conditions detected in widget tests
- Service tests focus on happy path with mocked data

**Null Safety Testing:**
```dart
testWidgets('should handle null onAction gracefully', (tester) async {
  await tester.pumpWidget(EmptyStateWidget(
    icon: Icons.inbox,
    title: testTitle,
    subtitle: testSubtitle,
    actionLabel: testActionLabel,
    iconColor: Colors.grey,
    onAction: null, // Null onAction
  ));
  
  expect(find.byType(ElevatedButton), findsNothing);
});
```

**Edge Case Testing:**
- Long Japanese text strings tested in `empty_state_widget_test.dart`
- Multiple icon types tested in loop
- Optional parameters (null subtitle, null action) tested explicitly

## Hash Chain Integrity Tests

A dedicated test file (`test/unit/hash_chain_test.dart`) tests SHA256 hash chain verification for Customer and Product models:
```dart
// Tests hash chain integrity across model fields
// Validates tamper detection when any field is modified
// Covers both valid and invalid hash scenarios
```

## Gaps Identified

1. **No screen tests** — ~40 screens have zero test coverage
2. **No service business logic tests** — Repository query mapping is tested, but complex business rules (invoice formal issue, stock transfer validation, purchase allocation) lack tests
3. **No integration path tests** — Only one widget-level app init test exists
4. **No mockito-generated mocks for many services** — Only `DatabaseHelper` and `BusinessProfileRepository` have generated mocks
5. **No test for error paths** — Exception throwing from services (44 throw sites identified) has no corresponding negative tests
6. **No PDF generation tests** — `pdf_generator.dart` has no test coverage despite being core to invoice output

---

*Testing analysis: 2026-05-16*
