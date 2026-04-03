/// ユーザーモデル
class User {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String department;
  final String position;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final List<String> roleIds;
  
  User({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    required this.department,
    required this.position,
    required this.isActive,
    required this.createdAt,
    this.lastLoginAt,
    required this.roleIds,
  });
  
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      username: map['username'] as String,
      email: map['email'] as String,
      fullName: map['full_name'] as String,
      phoneNumber: map['phone_number'] as String?,
      department: map['department'] as String,
      position: map['position'] as String,
      isActive: map['is_active'] == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      lastLoginAt: map['last_login_at'] != null 
          ? DateTime.parse(map['last_login_at'] as String)
          : null,
      roleIds: (map['role_ids'] as String?)?.split(',') ?? [],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'department': department,
      'position': position,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'last_login_at': lastLoginAt?.toIso8601String(),
      'role_ids': roleIds.join(','),
    };
  }
  
  User copyWith({
    String? id,
    String? username,
    String? email,
    String? fullName,
    String? phoneNumber,
    String? department,
    String? position,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    List<String>? roleIds,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      department: department ?? this.department,
      position: position ?? this.position,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      roleIds: roleIds ?? this.roleIds,
    );
  }
}

/// ロールモデル
class Role {
  final String id;
  final String name;
  final String description;
  final List<Permission> permissions;
  final bool isActive;
  final DateTime createdAt;
  
  Role({
    required this.id,
    required this.name,
    required this.description,
    required this.permissions,
    required this.isActive,
    required this.createdAt,
  });
  
  factory Role.fromMap(Map<String, dynamic> map) {
    return Role(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      permissions: (map['permissions'] as String?)
          ?.split(',')
          .map((p) => Permission.values.firstWhere(
              (perm) => perm.toString().split('.').last == p))
          .toList() ?? [],
      isActive: map['is_active'] == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'permissions': permissions.map((p) => p.toString().split('.').last).join(','),
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
  
  Role copyWith({
    String? id,
    String? name,
    String? description,
    List<Permission>? permissions,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Role(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      permissions: permissions ?? this.permissions,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 権限列挙
enum Permission {
  // ユーザー管理
  userView,
  userCreate,
  userEdit,
  userDelete,
  
  // ロール管理
  roleView,
  roleCreate,
  roleEdit,
  roleDelete,
  
  // 見積管理
  quoteView,
  quoteCreate,
  quoteEdit,
  quoteDelete,
  quoteApprove,
  
  // 受注管理
  orderView,
  orderCreate,
  orderEdit,
  orderDelete,
  orderConfirm,
  
  // 売上管理
  salesView,
  salesCreate,
  salesEdit,
  salesDelete,
  
  // 仕入管理
  purchaseView,
  purchaseCreate,
  purchaseEdit,
  purchaseDelete,
  purchaseApprove,
  
  // 在庫管理
  inventoryView,
  inventoryCreate,
  inventoryEdit,
  inventoryDelete,
  inventoryAdjust,
  
  // 配送管理
  deliveryView,
  deliveryCreate,
  deliveryEdit,
  deliveryDelete,
  deliveryConfirm,
  
  // 請求管理
  invoiceView,
  invoiceCreate,
  invoiceEdit,
  invoiceDelete,
  invoiceApprove,
  
  // 支払管理
  paymentView,
  paymentCreate,
  paymentEdit,
  paymentDelete,
  paymentConfirm,
  
  // レポート
  reportView,
  reportExport,
  
  // 設定
  settingsView,
  settingsEdit,
  
  // 監査
  auditView,
  auditExport,
}

/// 操作ログモデル
class AuditLog {
  final String id;
  final String userId;
  final String username;
  final String action;
  final String resourceType;
  final String? resourceId;
  final String? oldValue;
  final String? newValue;
  final String? ipAddress;
  final String? userAgent;
  final DateTime createdAt;
  
  AuditLog({
    required this.id,
    required this.userId,
    required this.username,
    required this.action,
    required this.resourceType,
    this.resourceId,
    this.oldValue,
    this.newValue,
    this.ipAddress,
    this.userAgent,
    required this.createdAt,
  });
  
  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      username: map['username'] as String,
      action: map['action'] as String,
      resourceType: map['resource_type'] as String,
      resourceId: map['resource_id'] as String?,
      oldValue: map['old_value'] as String?,
      newValue: map['new_value'] as String?,
      ipAddress: map['ip_address'] as String?,
      userAgent: map['user_agent'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'action': action,
      'resource_type': resourceType,
      'resource_id': resourceId,
      'old_value': oldValue,
      'new_value': newValue,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// セッションモデル
class UserSession {
  final String id;
  final String userId;
  final String username;
  final String? ipAddress;
  final String? userAgent;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isActive;
  
  UserSession({
    required this.id,
    required this.userId,
    required this.username,
    this.ipAddress,
    this.userAgent,
    required this.createdAt,
    this.expiresAt,
    required this.isActive,
  });
  
  factory UserSession.fromMap(Map<String, dynamic> map) {
    return UserSession(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      username: map['username'] as String,
      ipAddress: map['ip_address'] as String?,
      userAgent: map['user_agent'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      expiresAt: map['expires_at'] != null 
          ? DateTime.parse(map['expires_at'] as String)
          : null,
      isActive: map['is_active'] == 1,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }
}

/// 権限拡張メソッド
extension PermissionExtension on Permission {
  String get displayName {
    switch (this) {
      case Permission.userView: return 'ユーザー閲覧';
      case Permission.userCreate: return 'ユーザー作成';
      case Permission.userEdit: return 'ユーザー編集';
      case Permission.userDelete: return 'ユーザー削除';
      case Permission.roleView: return 'ロール閲覧';
      case Permission.roleCreate: return 'ロール作成';
      case Permission.roleEdit: return 'ロール編集';
      case Permission.roleDelete: return 'ロール削除';
      case Permission.quoteView: return '見積閲覧';
      case Permission.quoteCreate: return '見積作成';
      case Permission.quoteEdit: return '見積編集';
      case Permission.quoteDelete: return '見積削除';
      case Permission.quoteApprove: return '見積承認';
      case Permission.orderView: return '受注閲覧';
      case Permission.orderCreate: return '受注作成';
      case Permission.orderEdit: return '受注編集';
      case Permission.orderDelete: return '受注削除';
      case Permission.orderConfirm: return '受注確認';
      case Permission.salesView: return '売上閲覧';
      case Permission.salesCreate: return '売上作成';
      case Permission.salesEdit: return '売上編集';
      case Permission.salesDelete: return '売上削除';
      case Permission.purchaseView: return '仕入閲覧';
      case Permission.purchaseCreate: return '仕入作成';
      case Permission.purchaseEdit: return '仕入編集';
      case Permission.purchaseDelete: return '仕入削除';
      case Permission.purchaseApprove: return '仕入承認';
      case Permission.inventoryView: return '在庫閲覧';
      case Permission.inventoryCreate: return '在庫作成';
      case Permission.inventoryEdit: return '在庫編集';
      case Permission.inventoryDelete: return '在庫削除';
      case Permission.inventoryAdjust: return '在庫調整';
      case Permission.deliveryView: return '配送閲覧';
      case Permission.deliveryCreate: return '配送作成';
      case Permission.deliveryEdit: return '配送編集';
      case Permission.deliveryDelete: return '配送削除';
      case Permission.deliveryConfirm: return '配送確認';
      case Permission.invoiceView: return '請求閲覧';
      case Permission.invoiceCreate: return '請求作成';
      case Permission.invoiceEdit: return '請求編集';
      case Permission.invoiceDelete: return '請求削除';
      case Permission.invoiceApprove: return '請求承認';
      case Permission.paymentView: return '支払閲覧';
      case Permission.paymentCreate: return '支払作成';
      case Permission.paymentEdit: return '支払編集';
      case Permission.paymentDelete: return '支払削除';
      case Permission.paymentConfirm: return '支払確認';
      case Permission.reportView: return 'レポート閲覧';
      case Permission.reportExport: return 'レポート出力';
      case Permission.settingsView: return '設定閲覧';
      case Permission.settingsEdit: return '設定編集';
      case Permission.auditView: return '監査閲覧';
      case Permission.auditExport: return '監査出力';
    }
  }
  
  String get description {
    switch (this) {
      case Permission.userView: return 'ユーザー情報の閲覧が可能';
      case Permission.userCreate: return '新規ユーザーの作成が可能';
      case Permission.userEdit: return 'ユーザー情報の編集が可能';
      case Permission.userDelete: return 'ユーザーの削除が可能';
      case Permission.roleView: return 'ロール情報の閲覧が可能';
      case Permission.roleCreate: return '新規ロールの作成が可能';
      case Permission.roleEdit: return 'ロール情報の編集が可能';
      case Permission.roleDelete: return 'ロールの削除が可能';
      case Permission.quoteView: return '見積情報の閲覧が可能';
      case Permission.quoteCreate: return '新規見積の作成が可能';
      case Permission.quoteEdit: return '見積情報の編集が可能';
      case Permission.quoteDelete: return '見積の削除が可能';
      case Permission.quoteApprove: return '見積の承認が可能';
      case Permission.orderView: return '受注情報の閲覧が可能';
      case Permission.orderCreate: return '新規受注の作成が可能';
      case Permission.orderEdit: return '受注情報の編集が可能';
      case Permission.orderDelete: return '受注の削除が可能';
      case Permission.orderConfirm: return '受注の確認が可能';
      case Permission.salesView: return '売上情報の閲覧が可能';
      case Permission.salesCreate: return '新規売上の作成が可能';
      case Permission.salesEdit: return '売上情報の編集が可能';
      case Permission.salesDelete: return '売上の削除が可能';
      case Permission.purchaseView: return '仕入情報の閲覧が可能';
      case Permission.purchaseCreate: return '新規仕入の作成が可能';
      case Permission.purchaseEdit: return '仕入情報の編集が可能';
      case Permission.purchaseDelete: return '仕入の削除が可能';
      case Permission.purchaseApprove: return '仕入の承認が可能';
      case Permission.inventoryView: return '在庫情報の閲覧が可能';
      case Permission.inventoryCreate: return '在庫情報の作成が可能';
      case Permission.inventoryEdit: return '在庫情報の編集が可能';
      case Permission.inventoryDelete: return '在庫情報の削除が可能';
      case Permission.inventoryAdjust: return '在庫調整が可能';
      case Permission.deliveryView: return '配送情報の閲覧が可能';
      case Permission.deliveryCreate: return '新規配送の作成が可能';
      case Permission.deliveryEdit: return '配送情報の編集が可能';
      case Permission.deliveryDelete: return '配送の削除が可能';
      case Permission.deliveryConfirm: return '配送の確認が可能';
      case Permission.invoiceView: return '請求情報の閲覧が可能';
      case Permission.invoiceCreate: return '新規請求の作成が可能';
      case Permission.invoiceEdit: return '請求情報の編集が可能';
      case Permission.invoiceDelete: return '請求の削除が可能';
      case Permission.invoiceApprove: return '請求の承認が可能';
      case Permission.paymentView: return '支払情報の閲覧が可能';
      case Permission.paymentCreate: return '新規支払の作成が可能';
      case Permission.paymentEdit: return '支払情報の編集が可能';
      case Permission.paymentDelete: return '支払の削除が可能';
      case Permission.paymentConfirm: return '支払の確認が可能';
      case Permission.reportView: return 'レポートの閲覧が可能';
      case Permission.reportExport: return 'レポートの出力が可能';
      case Permission.settingsView: return '設定情報の閲覧が可能';
      case Permission.settingsEdit: return '設定情報の編集が可能';
      case Permission.auditView: return '監査ログの閲覧が可能';
      case Permission.auditExport: return '監査ログの出力が可能';
    }
  }
  
  String get category {
    switch (this) {
      case Permission.userView:
      case Permission.userCreate:
      case Permission.userEdit:
      case Permission.userDelete:
        return 'ユーザー管理';
      case Permission.roleView:
      case Permission.roleCreate:
      case Permission.roleEdit:
      case Permission.roleDelete:
        return 'ロール管理';
      case Permission.quoteView:
      case Permission.quoteCreate:
      case Permission.quoteEdit:
      case Permission.quoteDelete:
      case Permission.quoteApprove:
        return '見積管理';
      case Permission.orderView:
      case Permission.orderCreate:
      case Permission.orderEdit:
      case Permission.orderDelete:
      case Permission.orderConfirm:
        return '受注管理';
      case Permission.salesView:
      case Permission.salesCreate:
      case Permission.salesEdit:
      case Permission.salesDelete:
        return '売上管理';
      case Permission.purchaseView:
      case Permission.purchaseCreate:
      case Permission.purchaseEdit:
      case Permission.purchaseDelete:
      case Permission.purchaseApprove:
        return '仕入管理';
      case Permission.inventoryView:
      case Permission.inventoryCreate:
      case Permission.inventoryEdit:
      case Permission.inventoryDelete:
      case Permission.inventoryAdjust:
        return '在庫管理';
      case Permission.deliveryView:
      case Permission.deliveryCreate:
      case Permission.deliveryEdit:
      case Permission.deliveryDelete:
      case Permission.deliveryConfirm:
        return '配送管理';
      case Permission.invoiceView:
      case Permission.invoiceCreate:
      case Permission.invoiceEdit:
      case Permission.invoiceDelete:
      case Permission.invoiceApprove:
        return '請求管理';
      case Permission.paymentView:
      case Permission.paymentCreate:
      case Permission.paymentEdit:
      case Permission.paymentDelete:
      case Permission.paymentConfirm:
        return '支払管理';
      case Permission.reportView:
      case Permission.reportExport:
        return 'レポート';
      case Permission.settingsView:
      case Permission.settingsEdit:
        return '設定';
      case Permission.auditView:
      case Permission.auditExport:
        return '監査';
    }
  }
}
