import 'package:flutter/material.dart';

/// AppBar 用の画面ID表示ウィジェット。
/// 必ず2桁の ScreenID と正式タイトルをセットで表示し、
/// サポート時に下段へ `ScreenID: XX` を出す。
class ScreenAppBarTitle extends StatelessWidget {
  const ScreenAppBarTitle({
    super.key,
    required this.screenId,
    required this.title,
    this.caption,
  });

  final String screenId;
  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryStyle = theme.appBarTheme.titleTextStyle ??
        theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600);
    final secondaryStyle = theme.textTheme.bodySmall?.copyWith(color: Colors.white70, fontSize: 11);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$screenId:$title',
          style: primaryStyle,
        ),
        Text(
          'ScreenID: $screenId',
          style: secondaryStyle,
        ),
        if (caption != null)
          Text(
            caption!,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
      ],
    );
  }
}
