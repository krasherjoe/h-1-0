# Testing Patterns

**Analysis Date:** 2026-05-22

## Test Framework

**Runner:** Flutter's built-in `flutter_test` (via `sdk: flutter`)
- Config: No separate test config file — uses default `flutter test` behavior
- SDK: Dart SDK ^3.10.7, Flutter SDK ^3.10.7

**Mocking:** `mockito` (v5.4.6) with `@GenerateMocks` annotation and code generation
- Run code generation: `dart run build_runner build` (generates `.mocks.dart` files)

**Database testing:** `sqflite_common_ffi` (v2.3.2, dev dependency) — enables SQLite on desktop/test environments

**Run commands:**
```bash
flutter test                           # Run all tests (no coverage by default)
flutter test --coverage                # Run with coverage
```

## Test File Organization

**Directory structure under `test/`:**
```
test/
├── widget_test.dart                         # Basic app smoke test (sqflite FFI init + MaterialApp render)
└── unit/
    ├── hash_chain_test.dart                 # HashUtils SHA256 integrity tests
    ├── models/
    │   ├── business_profile_model_test.dart
    │   ├── customer_model_test.dart
    │   ├── inventory_location_model_test.dart
    │   ├── quotation_model_test.dart
    │   └── sales_model_test.dart
    ├── services/
    │   ├── business_profile_repository_test.dart
    │   ├── business_profile_repository_test.mocks.dart   # Generated
    │   ├── inventory_location_repository_test.dart
    │   ├── inventory_location_repository_test.mocks.dart # Generated
    │   └── quotation_repository_test.dart
    └── widgets/
        ├── document_card_test.dart
        └── empty_state_widget_test.dart
```

**Naming convention:** `<file_being_tested>_test.dart` (e.g. `customer_model.dart` → `customer_model_test.dart`)

**Location pattern:** Mirrors `lib/` structure under `test/unit/`:
- `lib/models/` → `test/unit/models/`
- `lib/services/` → `test/unit/services/`
- `lib/widgets/` → `test/unit/widgets/`

No integration tests or e2e test directories found.

## Test Structure Patterns

### Widget Tests — `test/unit/widgets/`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h_1/widgets/empty_state_widget.dart';

void main() {
  group('EmptyStateWidget', () {
    const testIcon = Icons.inbox;
    const testTitle = 'データがありません';

    testWidgets('should display empty state information', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: testIcon,
              title: testTitle,
              iconColor: Colors.grey,
              onAction: () {},
            ),
          ),
        ),
      );

      // Assert
      expect(find.text(testTitle), findsOneWidget);
      expect(find.byIcon(testIcon), findsOneWidget);
    });

    testWidgets('should handle action button tap', (tester) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: testIcon,
              title: testTitle,
              actionLabel: '作成',
              iconColor: Colors.grey,
              onAction: () => actionTapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('作成'));
      await tester.pump();

      expect(actionTapped, isTrue);
    });
  });
}
```

Key widget test patterns:
- `tester.pumpWidget(MaterialApp(home: Scaffold(body: ...)))` — standard wrapper
- `tester.tap(find.byType(WidgetType))` or `tester.tap(find.text('label'))`
- `findsOneWidget`, `findsNothing`, `findsAtLeastNWidgets(n)` matchers
- Boolean callback tracking via closure
- `tester.pumpWidget(Container())` for cleanup between iterations
- `const` test data at group level for reuse

### Model Unit Tests — `test/unit/models/`

```dart
void main() {
  group('CustomerModel', () {
    late Customer customer;

    setUp(() {
      customer = Customer(
        id: 'test-customer-1',
        formalName: '株式会社テスト',
        displayName: 'テスト',
        // ...
      );
    });

    test('should create customer with all fields', () {
      expect(customer.id, 'test-customer-1');
      expect(customer.formalName, '株式会社テスト');
    });

    test('should convert to map correctly', () {
      final map = customer.toMap();
      expect(map['id'], 'test-customer-1');
      expect(map['formal_name'], '株式会社テスト');
    });

    test('should create from map correctly', () {
      final fromMapCustomer = Customer.fromMap(map);
      expect(fromMapCustomer.id, 'test-2');
    });
  });
}
```

Key model test patterns:
- `setUp()` for shared test fixture initialization
- `group()` for logical test organization
- **Arrange-Act-Assert** (AAA) with comments
- Test both `toMap()` and `fromMap()` round-trip
- Default values tested (e.g. `title: '様'` default, `updatedAt: DateTime.now()` default)
- Edge cases: minimal fields, empty strings, null handling

### Repository Tests — `test/unit/services/`

```dart
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'business_profile_repository_test.mocks.dart';

@GenerateMocks([DatabaseHelper])
void main() {
  group('BusinessProfileRepository', () {
    late BusinessProfileRepository repository;
    late MockDatabaseHelper mockDb;

    setUp(() {
      mockDb = MockDatabaseHelper();
      repository = BusinessProfileRepository();
    });

    group('getCurrentProfile', () {
      test('should return current profile when exists', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.query(
          'business_profiles',
          orderBy: 'updated_at DESC',
          limit: 1,
        )).thenAnswer((_) async => [ /* test data */ ]);

        // Act
        final result = await repository.getCurrentProfile();

        // Assert
        expect(result.id, 'test-id');
        verify(mockDatabase.query(
          'business_profiles',
          orderBy: 'updated_at DESC',
          limit: 1,
        )).called(1);
      });
    });
  });
}
```

## Mocking Approach

**Framework:** `mockito` with `@GenerateMocks` annotation

**Pattern:**
1. Annotate `@GenerateMocks([ClassName])` above `main()` in the test file
2. Run `dart run build_runner build` to generate `class_name_test.mocks.dart`
3. Import the generated mocks file
4. Use `MockDatabase()` (a generated subclass) to create mock instances

**What to Mock:**
- `DatabaseHelper` — the SQLite database helper (primary mock target)
- `Database` — the sqflite `Database` class methods (`query`, `insert`, `delete`, `rawQuery`)
- External API services

**Mock verification:** `verify(mock.query(...)).called(1)` ensures methods are invoked with exact parameters

**Matchers used:**
- `any` — wildcard for any value
- `argThat(containsPair('key', 'value'))` — partial map matching
- `argThat(allOf([...]))` — compound matchers
- `anyNamed('conflictAlgorithm')` — named parameter matching

## App Smoke Test — `test/widget_test.dart`

```dart
TestWidgetsFlutterBinding.ensureInitialized();
sqfliteFfiInit();
databaseFactory = databaseFactoryFfi;

testWidgets('アプリが初期化されてホーム画面を描画できる', (tester) async {
  final expiryInfo = BuildExpiryInfo.fromEnvironment();
  await tester.pumpWidget(MyApp(expiryInfo: expiryInfo));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
  expect(find.byType(MaterialApp), findsOneWidget);
});
```

- Uses `sqflite_common_ffi` to initialize SQLite for test environment
- Multiple `pump()` calls to wait for async initialization
- Verifies `MaterialApp` renders without error

## Coverage

**Current state:** No coverage enforcement found (no `lcov.info` config, no CI coverage gates)
**View coverage:**
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## CI/CD

**Current state:** No CI configuration found (no `.github/`, `.gitlab-ci.yml`, or `Jenkinsfile`)

## Test Types Present

| Type | Files | Scope |
|------|-------|-------|
| **Unit (models)** | 5 files | Constructor, serialization (`toMap`/`fromMap`), `copyWith`, defaults, edge cases |
| **Unit (services/repos)** | 3 files | CRUD operations via mock DB, parameter verification, return data mapping, empty state, error paths |
| **Unit (hashes)** | 1 file | SHA256 computation, chain integrity, tamper detection, version linking |
| **Widget** | 2 files | Render output, tap handling, null safety, edge cases, action callbacks |
| **App smoke** | 1 file | Full app initialization |

## Key Gaps

- No state management tests (Riverpod/Provider not yet widely adopted)
- No integration tests (multi-screen flows)
- No golden file tests for visual regression
- Limited service-layer tests (only 3 of ~68 service files tested)
- No widget tests for screens (only shared widgets)
- No CI pipeline to enforce test execution
- Coverage target not defined

---

*Testing analysis: 2026-05-22*
