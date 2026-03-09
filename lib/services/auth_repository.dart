import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/auth_models.dart';
import 'database_helper.dart';

/// 認証リポジトリ
class AuthRepository {
  static final AuthRepository _instance = AuthRepository._internal();
  factory AuthRepository() => _instance;
  AuthRepository._internal();
  
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();
  
  // ユーザー管理
  Future<List<User>> getAllUsers() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('users');
    return maps.map((map) => User.fromMap(map)).toList();
  }
  
  Future<User?> getUserById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }
  
  Future<User?> getUserByUsername(String username) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }
  
  Future<User?> getUserByEmail(String email) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }
  
  Future<String> createUser(User user) async {
    final db = await _dbHelper.database;
    final id = _uuid.v4();
    final newUser = user.copyWith(id: id);
    await db.insert('users', newUser.toMap());
    return id;
  }
  
  Future<void> updateUser(User user) async {
    final db = await _dbHelper.database;
    await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }
  
  Future<void> deleteUser(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<void> toggleUserStatus(String id) async {
    final user = await getUserById(id);
    if (user != null) {
      final updatedUser = user.copyWith(isActive: !user.isActive);
      await updateUser(updatedUser);
    }
  }
  
  // ロール管理
  Future<List<Role>> getAllRoles() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('roles');
    return maps.map((map) => Role.fromMap(map)).toList();
  }
  
  Future<Role?> getRoleById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'roles',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Role.fromMap(maps.first);
    }
    return null;
  }
  
  Future<String> createRole(Role role) async {
    final db = await _dbHelper.database;
    final id = _uuid.v4();
    final newRole = role.copyWith(id: id);
    await db.insert('roles', newRole.toMap());
    return id;
  }
  
  Future<void> updateRole(Role role) async {
    final db = await _dbHelper.database;
    await db.update(
      'roles',
      role.toMap(),
      where: 'id = ?',
      whereArgs: [role.id],
    );
  }
  
  Future<void> deleteRole(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'roles',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<void> toggleRoleStatus(String id) async {
    final role = await getRoleById(id);
    if (role != null) {
      final updatedRole = role.copyWith(isActive: !role.isActive);
      await updateRole(updatedRole);
    }
  }
  
  // ユーザーロール関連付け
  Future<void> assignRolesToUser(String userId, List<String> roleIds) async {
    final db = await _dbHelper.database;
    
    // 既存の関連付けを削除
    await db.delete(
      'user_roles',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    
    // 新しい関連付けを追加
    for (final roleId in roleIds) {
      await db.insert('user_roles', {
        'id': _uuid.v4(),
        'user_id': userId,
        'role_id': roleId,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }
  
  Future<List<Role>> getUserRoles(String userId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT r.* FROM roles r
      INNER JOIN user_roles ur ON r.id = ur.role_id
      WHERE ur.user_id = ? AND r.is_active = 1
    ''', [userId]);
    return maps.map((map) => Role.fromMap(map)).toList();
  }
  
  Future<List<User>> getUsersByRole(String roleId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT u.* FROM users u
      INNER JOIN user_roles ur ON u.id = ur.user_id
      WHERE ur.role_id = ? AND u.is_active = 1
    ''', [roleId]);
    return maps.map((map) => User.fromMap(map)).toList();
  }
  
  // 権限チェック
  Future<bool> hasPermission(String userId, Permission permission) async {
    final roles = await getUserRoles(userId);
    for (final role in roles) {
      if (role.permissions.contains(permission)) {
        return true;
      }
    }
    return false;
  }
  
  Future<List<Permission>> getUserPermissions(String userId) async {
    final roles = await getUserRoles(userId);
    final Set<Permission> permissions = <Permission>{};
    for (final role in roles) {
      permissions.addAll(role.permissions);
    }
    return permissions.toList();
  }
  
  // 操作ログ
  Future<void> logAction({
    required String userId,
    required String username,
    required String action,
    required String resourceType,
    String? resourceId,
    String? oldValue,
    String? newValue,
    String? ipAddress,
    String? userAgent,
  }) async {
    final db = await _dbHelper.database;
    final log = AuditLog(
      id: _uuid.v4(),
      userId: userId,
      username: username,
      action: action,
      resourceType: resourceType,
      resourceId: resourceId,
      oldValue: oldValue,
      newValue: newValue,
      ipAddress: ipAddress,
      userAgent: userAgent,
      createdAt: DateTime.now(),
    );
    await db.insert('audit_logs', log.toMap());
  }
  
  Future<List<AuditLog>> getAuditLogs({
    String? userId,
    String? resourceType,
    String? resourceId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  }) async {
    final db = await _dbHelper.database;
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];
    
    if (userId != null) {
      whereClause += ' AND user_id = ?';
      whereArgs.add(userId);
    }
    
    if (resourceType != null) {
      whereClause += ' AND resource_type = ?';
      whereArgs.add(resourceType);
    }
    
    if (resourceId != null) {
      whereClause += ' AND resource_id = ?';
      whereArgs.add(resourceId);
    }
    
    if (startDate != null) {
      whereClause += ' AND created_at >= ?';
      whereArgs.add(startDate.toIso8601String());
    }
    
    if (endDate != null) {
      whereClause += ' AND created_at <= ?';
      whereArgs.add(endDate.toIso8601String());
    }
    
    String orderBy = 'created_at DESC';
    if (limit != null) {
      orderBy += ' LIMIT $limit';
      if (offset != null) {
        orderBy += ' OFFSET $offset';
      }
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'audit_logs',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );
    return maps.map((map) => AuditLog.fromMap(map)).toList();
  }
  
  Future<int> getAuditLogCount({
    String? userId,
    String? resourceType,
    String? resourceId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbHelper.database;
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];
    
    if (userId != null) {
      whereClause += ' AND user_id = ?';
      whereArgs.add(userId);
    }
    
    if (resourceType != null) {
      whereClause += ' AND resource_type = ?';
      whereArgs.add(resourceType);
    }
    
    if (resourceId != null) {
      whereClause += ' AND resource_id = ?';
      whereArgs.add(resourceId);
    }
    
    if (startDate != null) {
      whereClause += ' AND created_at >= ?';
      whereArgs.add(startDate.toIso8601String());
    }
    
    if (endDate != null) {
      whereClause += ' AND created_at <= ?';
      whereArgs.add(endDate.toIso8601String());
    }
    
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM audit_logs WHERE $whereClause',
      whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
  
  // セッション管理
  Future<String> createSession({
    required String userId,
    required String username,
    String? ipAddress,
    String? userAgent,
    Duration? duration,
  }) async {
    final db = await _dbHelper.database;
    final sessionId = _uuid.v4();
    final expiresAt = duration != null 
        ? DateTime.now().add(duration)
        : DateTime.now().add(const Duration(hours: 8));
    
    final session = UserSession(
      id: sessionId,
      userId: userId,
      username: username,
      ipAddress: ipAddress,
      userAgent: userAgent,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
      isActive: true,
    );
    
    await db.insert('user_sessions', session.toMap());
    return sessionId;
  }
  
  Future<UserSession?> getSession(String sessionId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_sessions',
      where: 'id = ? AND is_active = 1 AND expires_at > ?',
      whereArgs: [sessionId, DateTime.now().toIso8601String()],
    );
    if (maps.isNotEmpty) {
      return UserSession.fromMap(maps.first);
    }
    return null;
  }
  
  Future<void> invalidateSession(String sessionId) async {
    final db = await _dbHelper.database;
    await db.update(
      'user_sessions',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }
  
  Future<void> invalidateAllUserSessions(String userId) async {
    final db = await _dbHelper.database;
    await db.update(
      'user_sessions',
      {'is_active': 0},
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }
  
  Future<List<UserSession>> getActiveSessions(String userId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_sessions',
      where: 'user_id = ? AND is_active = 1 AND expires_at > ?',
      whereArgs: [userId, DateTime.now().toIso8601String()],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => UserSession.fromMap(map)).toList();
  }
  
  Future<void> cleanupExpiredSessions() async {
    final db = await _dbHelper.database;
    await db.update(
      'user_sessions',
      {'is_active': 0},
      where: 'expires_at <= ?',
      whereArgs: [DateTime.now().toIso8601String()],
    );
  }
  
  // 統計情報
  Future<Map<String, dynamic>> getStatistics() async {
    final db = await _dbHelper.database;
    
    // ユーザー数
    final userCountResult = await db.rawQuery('SELECT COUNT(*) as count FROM users');
    final totalUsers = Sqflite.firstIntValue(userCountResult) ?? 0;
    
    final activeUserCountResult = await db.rawQuery('SELECT COUNT(*) as count FROM users WHERE is_active = 1');
    final activeUsers = Sqflite.firstIntValue(activeUserCountResult) ?? 0;
    
    // ロール数
    final roleCountResult = await db.rawQuery('SELECT COUNT(*) as count FROM roles');
    final totalRoles = Sqflite.firstIntValue(roleCountResult) ?? 0;
    
    final activeRoleCountResult = await db.rawQuery('SELECT COUNT(*) as count FROM roles WHERE is_active = 1');
    final activeRoles = Sqflite.firstIntValue(activeRoleCountResult) ?? 0;
    
    // アクティブセッション数
    final sessionCountResult = await db.rawQuery('''
      SELECT COUNT(*) as count FROM user_sessions 
      WHERE is_active = 1 AND expires_at > ?
    ''', [DateTime.now().toIso8601String()]);
    final activeSessions = Sqflite.firstIntValue(sessionCountResult) ?? 0;
    
    // 今日の操作ログ数
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final logCountResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM audit_logs WHERE created_at >= ?',
      [todayStart.toIso8601String()],
    );
    final todayLogs = Sqflite.firstIntValue(logCountResult) ?? 0;
    
    return {
      'totalUsers': totalUsers,
      'activeUsers': activeUsers,
      'totalRoles': totalRoles,
      'activeRoles': activeRoles,
      'activeSessions': activeSessions,
      'todayLogs': todayLogs,
    };
  }
  
  // 初期データの作成
  Future<void> createInitialData() async {
    final db = await _dbHelper.database;
    
    // 管理者ロールの作成
    final adminRole = Role(
      id: _uuid.v4(),
      name: '管理者',
      description: 'すべての権限を持つ管理者',
      permissions: Permission.values,
      isActive: true,
      createdAt: DateTime.now(),
    );
    await db.insert('roles', adminRole.toMap());
    
    // 一般ユーザーロールの作成
    final userRole = Role(
      id: _uuid.v4(),
      name: '一般ユーザー',
      description: '基本的な権限を持つ一般ユーザー',
      permissions: [
        Permission.quoteView,
        Permission.orderView,
        Permission.salesView,
        Permission.purchaseView,
        Permission.inventoryView,
        Permission.deliveryView,
        Permission.invoiceView,
        Permission.paymentView,
        Permission.reportView,
      ],
      isActive: true,
      createdAt: DateTime.now(),
    );
    await db.insert('roles', userRole.toMap());
    
    // 管理者ユーザーの作成
    final adminUser = User(
      id: _uuid.v4(),
      username: 'admin',
      email: 'admin@example.com',
      fullName: 'システム管理者',
      department: 'システム部',
      position: '管理者',
      isActive: true,
      createdAt: DateTime.now(),
      roleIds: [adminRole.id],
    );
    await db.insert('users', adminUser.toMap());
    
    // 管理者とロールの関連付け
    await db.insert('user_roles', {
      'id': _uuid.v4(),
      'user_id': adminUser.id,
      'role_id': adminRole.id,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
