import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 汎用伝票カードウィジェット
/// 見積・受注・売上など、あらゆる伝票の一覧表示に使用可能
class DocumentCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final DateTime date;
  final DocumentStatus status;
  final Color themeColor;
  final VoidCallback? onTap;
  final List<CardAction>? actions;

  const DocumentCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.status,
    required this.themeColor,
    this.onTap,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (subtitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        amount,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                      Text(
                        DateFormat('yyyy/MM/dd').format(date),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatusChip(status),
                  const Spacer(),
                  if (actions != null)
                    ...actions!.map((action) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: IconButton(
                            icon: Icon(action.icon, size: 20),
                            onPressed: action.onPressed,
                            tooltip: action.label,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(DocumentStatus status) {
    Color color;
    String label;

    switch (status) {
      case DocumentStatus.draft:
        color = Colors.orange;
        label = '下書き';
        break;
      case DocumentStatus.confirmed:
        color = Colors.green;
        label = '確定';
        break;
      case DocumentStatus.cancelled:
        color = Colors.grey;
        label = 'キャンセル';
        break;
    }

    return Chip(
      label: Text(label),
      backgroundColor: color is MaterialColor ? color.shade100 : color.withOpacity(0.2),
      labelStyle: TextStyle(
        color: color is MaterialColor ? color.shade700 : color,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// 伝票ステータス
enum DocumentStatus {
  draft,      // 下書き
  confirmed,  // 確定
  cancelled,  // キャンセル
}

/// カードアクション
class CardAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const CardAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
}
