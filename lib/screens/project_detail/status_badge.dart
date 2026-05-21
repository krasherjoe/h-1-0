import 'package:flutter/material.dart';
import '../../models/project_model.dart';

class ProjectStatusBadge extends StatelessWidget {
  final ProjectStatus status;
  final Color color;
  const ProjectStatusBadge({super.key, required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(status.displayName,
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.bold)),
    );
  }
}
