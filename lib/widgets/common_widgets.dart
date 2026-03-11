import 'package:flutter/material.dart';
import '../utils/theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final String? label;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.status,
    this.label,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final color = statusColors[status] ?? AppTheme.gray500;
    final bgColor = statusBgColors[status] ?? AppTheme.gray100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label ?? _getStatusLabel(status),
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w500),
      ),
    );
  }

  String _getStatusLabel(String s) {
    const labels = {
      'active': '운영중', 'inactive': '비운영', 'suspended': '중지',
      'normal': '정상', 'warning': '주의', 'fault': '고장', 'stopped': '정지',
    };
    return labels[s] ?? s;
  }
}

class SeverityBadge extends StatelessWidget {
  final String severity;
  final double fontSize;

  const SeverityBadge({super.key, required this.severity, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    final color = severityColors[severity] ?? AppTheme.gray500;
    final bgColor = severityBgColors[severity] ?? AppTheme.gray100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        severity,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const InfoCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
      ),
    );
  }
}

class ErrorWidget2 extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorWidget2({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.gray600),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('다시 시도'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyWidget extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyWidget({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppTheme.gray400),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppTheme.gray400, fontSize: 14)),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final IconData? icon;
  final Color? iconColor;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: iconColor ?? AppTheme.primary),
          const SizedBox(width: 6),
        ],
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.gray700,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmLabel;
  final Color? confirmColor;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmLabel = '삭제',
    this.confirmColor,
  });

  static Future<bool?> show(BuildContext context, {
    required String title,
    required String content,
    String confirmLabel = '삭제',
    Color? confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: title,
        content: content,
        confirmLabel: confirmLabel,
        confirmColor: confirmColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      content: Text(content, style: const TextStyle(color: AppTheme.gray600)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor ?? AppTheme.danger,
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

void showToast(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: isError ? AppTheme.danger : AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ),
  );
}

String fmtDate(String? d) => d != null && d.length >= 10 ? d.substring(0, 10) : '-';
