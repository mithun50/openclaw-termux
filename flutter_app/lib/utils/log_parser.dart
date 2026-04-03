import 'package:flutter/material.dart';
import '../app.dart';
import '../l10n/app_strings.dart';

enum LogLevel { info, warn, error, success, debug, system }

class ParsedLog {
  final LogLevel level;
  final String time;
  final String rawMessage;
  final String friendlyMessage; // 中文友好说明
  final String? detail; // 可选的技术细节
  final IconData icon;
  final Color color;

  const ParsedLog({
    required this.level,
    required this.time,
    required this.rawMessage,
    required this.friendlyMessage,
    this.detail,
    required this.icon,
    required this.color,
  });
}

class LogParser {
  static ParsedLog parse(String raw, ThemeData theme) {
    final time = _extractTime(raw);
    final msg = _stripTime(raw).trim();

    // 错误级别
    if (_isError(msg)) {
      return ParsedLog(
        level: LogLevel.error,
        time: time,
        rawMessage: raw,
        friendlyMessage: _translateError(msg),
        detail: msg,
        icon: Icons.error_outline,
        color: theme.colorScheme.error,
      );
    }

    // 警告级别
    if (_isWarn(msg)) {
      return ParsedLog(
        level: LogLevel.warn,
        time: time,
        rawMessage: raw,
        friendlyMessage: _translateWarn(msg),
        detail: msg,
        icon: Icons.warning_amber_outlined,
        color: AppColors.statusAmber,
      );
    }

    // 成功/健康
    if (_isSuccess(msg)) {
      return ParsedLog(
        level: LogLevel.success,
        time: time,
        rawMessage: raw,
        friendlyMessage: _translateSuccess(msg),
        icon: Icons.check_circle_outline,
        color: AppColors.statusGreen,
      );
    }

    // 系统/启动
    if (_isSystem(msg)) {
      return ParsedLog(
        level: LogLevel.system,
        time: time,
        rawMessage: raw,
        friendlyMessage: _translateSystem(msg),
        icon: Icons.settings_outlined,
        color: AppColors.mutedText,
      );
    }

    // 普通信息
    return ParsedLog(
      level: LogLevel.info,
      time: time,
      rawMessage: raw,
      friendlyMessage: _translateInfo(msg),
      icon: Icons.info_outline,
      color: AppColors.mutedText,
    );
  }

  static String _extractTime(String raw) {
    // ISO 时间格式: 2024-01-01T12:00:00.000Z
    final iso = RegExp(r'\d{4}-\d{2}-\d{2}T(\d{2}:\d{2}:\d{2})');
    final m = iso.firstMatch(raw);
    if (m != null) return m.group(1)!;
    // HH:MM:SS 格式
    final hms = RegExp(r'(\d{2}:\d{2}:\d{2})');
    final m2 = hms.firstMatch(raw);
    if (m2 != null) return m2.group(1)!;
    return '';
  }

  static String _stripTime(String raw) {
    return raw
        .replaceAll(
            RegExp(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z?\s*'), '')
        .replaceAll(RegExp(r'\[\w+\]\s*'), '')
        .trim();
  }

  static bool _isError(String msg) =>
      msg.contains('[ERR]') ||
      msg.contains('ERROR') ||
      msg.contains('error') ||
      msg.contains('failed') ||
      msg.contains('Failed') ||
      msg.contains('exception') ||
      msg.contains('ECONNREFUSED') ||
      msg.contains('ENOENT');

  static bool _isWarn(String msg) =>
      msg.contains('[WARN]') ||
      msg.contains('WARNING') ||
      msg.contains('warn') ||
      msg.contains('deprecated');

  static bool _isSuccess(String msg) =>
      msg.contains('healthy') ||
      msg.contains('ready') ||
      msg.contains('started') ||
      msg.contains('connected') ||
      msg.contains('complete') ||
      msg.contains('success') ||
      msg.contains('Gateway is healthy') ||
      msg.contains('Running');

  static bool _isSystem(String msg) =>
      msg.contains('Starting') ||
      msg.contains('Stopping') ||
      msg.contains('Auto-start') ||
      msg.contains('reconnect') ||
      msg.contains('detected') ||
      msg.contains('process');

  static String _translateError(String msg) {
    if (!AppStrings.isChinese) return msg;
    if (msg.contains('ECONNREFUSED') || msg.contains('Connection refused')) {
      return '连接被拒绝：网关服务未响应，请检查是否已启动';
    }
    if (msg.contains('ENOENT') || msg.contains('No such file')) {
      return '文件不存在：安装可能不完整，建议重新安装';
    }
    if (msg.contains('timeout') || msg.contains('Timeout')) {
      return '连接超时：网络或服务响应过慢';
    }
    if (msg.contains('Failed to start')) {
      return '启动失败：请检查环境是否正确安装';
    }
    if (msg.contains('permission') || msg.contains('Permission')) {
      return '权限不足：请检查应用权限设置';
    }
    if (msg.contains('port') || msg.contains('Port')) {
      return '端口错误：18789 端口可能被占用';
    }
    if (msg.contains('memory') || msg.contains('Memory')) {
      return '内存不足：请关闭其他应用后重试';
    }
    return '发生错误：$msg';
  }

  static String _translateWarn(String msg) {
    if (!AppStrings.isChinese) return msg;
    if (msg.contains('deprecated')) return '功能已过时，建议更新版本';
    if (msg.contains('retry') || msg.contains('Retry')) return '正在重试连接...';
    if (msg.contains('slow') || msg.contains('Slow')) return '响应较慢，请耐心等待';
    if (msg.contains('not running')) return '网关进程未运行';
    return '警告：$msg';
  }

  static String _translateSuccess(String msg) {
    if (!AppStrings.isChinese) return msg;
    if (msg.contains('healthy') || msg.contains('Gateway is healthy')) {
      return '✓ 网关运行正常，服务健康';
    }
    if (msg.contains('started') || msg.contains('Starting gateway')) {
      return '网关正在启动中...';
    }
    if (msg.contains('connected') || msg.contains('reconnecting')) {
      return '已连接到网关服务';
    }
    if (msg.contains('complete') || msg.contains('success')) {
      return '操作成功完成';
    }
    if (msg.contains('Running') || msg.contains('ready')) {
      return '服务已就绪，可以开始使用';
    }
    return msg;
  }

  static String _translateSystem(String msg) {
    if (!AppStrings.isChinese) return msg;
    if (msg.contains('Auto-starting')) return '自动启动网关...';
    if (msg.contains('Starting gateway')) return '正在启动网关服务...';
    if (msg.contains('Stopping') || msg.contains('stopped')) return '网关已停止';
    if (msg.contains('detected') || msg.contains('reconnecting')) {
      return '检测到网关进程，正在重新连接...';
    }
    if (msg.contains('waiting')) return '等待网关启动，请稍候...';
    if (msg.contains('process not running')) return '网关进程已退出';
    return msg;
  }

  static String _translateInfo(String msg) {
    if (!AppStrings.isChinese) return msg;
    if (msg.contains('token') || msg.contains('Token')) {
      return '获取到访问令牌，控制台已就绪';
    }
    if (msg.contains('Dashboard')) return '控制台地址已更新';
    if (msg.contains('health') || msg.contains('Health'))
      return '正在检查服务健康状态...';
    if (msg.contains('log') || msg.contains('Log')) return '日志记录中';
    if (msg.isEmpty) return '系统消息';
    return msg;
  }
}
