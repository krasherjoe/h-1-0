import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/activity_log_model.dart';
import '../services/activity_log_repository.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final ActivityLogRepository _logRepo = ActivityLogRepository();
  List<ActivityLog> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await _logRepo.getAllLogs();
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm:ss');

    return Scaffold(
      appBar: AppBar(
        title: Text("アクティビティ履歴 (Gitログ風)"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLogs),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text("履歴はありません"))
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    return _buildLogTile(log, dateFormat, context);
                  },
                ),
    );
  }

  Widget _buildLogTile(ActivityLog log, DateFormat fmt, BuildContext ctx) {
    IconData icon;
    Color color;
    final cs = Theme.of(ctx).colorScheme;

    switch (log.action) {
      case "SAVE_INVOICE":
      case "SAVE_PRODUCT":
      case "SAVE_CUSTOMER":
        icon = Icons.save;
        color = cs.primary;
        break;
      case "DELETE_INVOICE":
      case "DELETE_PRODUCT":
      case "DELETE_CUSTOMER":
        icon = Icons.delete_forever;
        color = cs.error;
        break;
      case "GENERATE_PDF":
        icon = Icons.picture_as_pdf;
        color = cs.tertiary;
        break;
      default:
        icon = Icons.info_outline;
        color = cs.onSurfaceVariant;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cs.surfaceContainerHighest.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          "${_getActionJapanese(log.action)} [${log.targetType}]",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (log.details != null)
              Text(log.details!, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 4),
            Text(fmt.format(log.timestamp), style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
        isThreeLine: log.details != null,
      ),
    );
  }

  String _getActionJapanese(String action) {
    switch (action) {
      case "SAVE_INVOICE": return "伝票保存";
      case "DELETE_INVOICE": return "伝票削除";
      case "SAVE_PRODUCT": return "商品更新";
      case "DELETE_PRODUCT": return "商品削除";
      case "SAVE_CUSTOMER": return "顧客更新";
      case "DELETE_CUSTOMER": return "顧客削除";
      case "GENERATE_PDF": return "PDF発行";
      default: return action;
    }
  }
}
