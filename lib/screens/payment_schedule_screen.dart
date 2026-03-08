/// 支払予定一覧画面
import 'package:flutter/material.dart';
import '../services/payment_schedule_repository.dart';
import '../widgets/generic_list_screen.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state_widget.dart';
import '../models/base_document.dart';
import '../models/payment_schedule_model.dart';

class PaymentScheduleScreen extends StatefulWidget {
  const PaymentScheduleScreen({super.key});

  @override
  State<PaymentScheduleScreen> createState() => _PaymentScheduleScreenState();
}

class _PaymentScheduleScreenState extends State<PaymentScheduleScreen> {
  @override
  Widget build(BuildContext context) {
    final repo = PaymentScheduleRepository();

    return GenericListScreen<PaymentSchedule>(
      screenId: 'P1',
      title: '支払予定',
      icon: Icons.payment,
      themeColor: Colors.blue,

      // データ取得
      fetchData: () => repo.getAllSchedules(),

      // カード表示
      buildCard: (context, schedule, onRefresh) {
        return DocumentCard(
          title: schedule.displayTitle,
          subtitle: schedule.displaySubtitle,
          amount: schedule.displayAmount,
          date: schedule.dueDate,
          status: _getDocumentStatus(schedule),
          themeColor: schedule.getThemeColor(),
          onTap: () {
            if (!mounted) return;
            _showScheduleDialog(schedule);
          },
          actions: [
            CardAction(
              label: '支払登録',
              icon: Icons.receipt_long,
              onPressed: () {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('支払登録画面は今後実装予定です')),
                );
              },
            ),
            if (schedule.status == PaymentStatus.unpaid)
              CardAction(
                label: '支払済',
                icon: Icons.check_circle,
                onPressed: () async {
                  await _markAsPaid(schedule, onRefresh);
                },
              ),
          ],
        );
      },

      // フィルタ
      filters: [
        FilterOption(
          label: '全て',
          value: 'all',
          filter: (schedules) => schedules,
        ),
        FilterOption(
          label: '未払',
          value: 'unpaid',
          filter: (schedules) => schedules
              .where((s) => s.status == PaymentStatus.unpaid)
              .toList(),
        ),
        FilterOption(
          label: '延滞',
          value: 'overdue',
          filter: (schedules) => schedules
              .where((s) => s.isOverdue)
              .toList(),
        ),
        FilterOption(
          label: '期日近',
          value: 'due_soon',
          filter: (schedules) => schedules
              .where((s) => s.isDueSoon)
              .toList(),
        ),
        FilterOption(
          label: '支払済',
          value: 'paid',
          filter: (schedules) => schedules
              .where((s) => s.status == PaymentStatus.paid)
              .toList(),
        ),
      ],

      // 新規作成（支払予定は手動作成しない）
      onCreateNew: () async {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('支払予定は仕入データから自動生成されます')),
        );
      },

      // 空状態
      emptyWidget: EmptyStateWidget(
        icon: Icons.payment,
        title: '支払予定がありません',
        subtitle: '仕入データを登録すると支払予定が自動生成されます',
        actionLabel: '仕入入力へ',
        iconColor: Colors.blue,
        onAction: () {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('仕入入力画面に遷移します')),
          );
        },
      ),
    );
  }

  DocumentStatus _getDocumentStatus(PaymentSchedule schedule) {
    switch (schedule.status) {
      case PaymentStatus.unpaid:
        if (schedule.isOverdue) return DocumentStatus.cancelled;
        return DocumentStatus.draft;
      case PaymentStatus.partial:
        return DocumentStatus.draft;
      case PaymentStatus.paid:
        return DocumentStatus.confirmed;
      case PaymentStatus.overdue:
        return DocumentStatus.cancelled;
    }
  }

  void _showScheduleDialog(PaymentSchedule schedule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(schedule.displayTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('支払金額: ${schedule.displayAmount}'),
            Text('支払期日: ${schedule.dueDate.year}/${schedule.dueDate.month}/${schedule.dueDate.day}'),
            Text('ステータス: ${schedule.statusDisplayName}'),
            if (schedule.paidDate != null)
              Text('支払日: ${schedule.paidDate!.year}/${schedule.paidDate!.month}/${schedule.paidDate!.day}'),
            if (schedule.daysUntilDue >= 0)
              Text('期日まで: ${schedule.daysUntilDue}日')
            else
              Text('延滞日数: ${-schedule.daysUntilDue}日', style: TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            Text('仕入伝票: ${schedule.purchase.documentNumber}'),
            Text('仕入日: ${schedule.purchase.date.year}/${schedule.purchase.date.month}/${schedule.purchase.date.day}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
          if (schedule.status == PaymentStatus.unpaid)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _markAsPaid(schedule, () {});
              },
              child: const Text('支払済にする'),
            ),
        ],
      ),
    );
  }

  Future<void> _markAsPaid(PaymentSchedule schedule, VoidCallback onRefresh) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: Text('${schedule.displayTitle}を支払済にしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('支払済にする'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repo = PaymentScheduleRepository();
        await repo.updateScheduleStatus(schedule.id, PaymentStatus.paid);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('支払済にしました')),
        );
        onRefresh();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新に失敗しました: $e')),
        );
      }
    }
  }
}
