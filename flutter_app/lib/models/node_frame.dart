import 'dart:convert';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Gateway Protocol v3 frame.
/// Types: "req", "res", "event"
class NodeFrame {
  final String type;
  final String? id;
  final String? method;
  final Map<String, dynamic>? params;
  final bool? ok;
  final Map<String, dynamic>? payload;
  final Map<String, dynamic>? error;
  final String? event;

  const NodeFrame({
    required this.type,
    this.id,
    this.method,
    this.params,
    this.ok,
    this.payload,
    this.error,
    this.event,
  });

  factory NodeFrame.request(String method, [Map<String, dynamic>? params]) {
    return NodeFrame(
      type: 'req',
      id: _uuid.v4(),
      method: method,
      params: params ?? {},
    );
  }

  factory NodeFrame.response(String id,
      {Map<String, dynamic>? payload, Map<String, dynamic>? error}) {
    return NodeFrame(
      type: 'res',
      id: id,
      ok: error == null,
      payload: payload,
      error: error,
    );
  }

  factory NodeFrame.event(String event, [Map<String, dynamic>? payload]) {
    return NodeFrame(
      type: 'event',
      event: event,
      payload: payload,
    );
  }

  factory NodeFrame.fromJson(Map<String, dynamic> json) {
    return NodeFrame(
      type: json['type'] as String? ?? 'res',
      id: json['id'] as String?,
      method: json['method'] as String?,
      params: json['params'] != null
          ? Map<String, dynamic>.from(json['params'] as Map)
          : null,
      ok: json['ok'] as bool?,
      payload: json['payload'] != null
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : null,
      error: json['error'] != null
          ? Map<String, dynamic>.from(json['error'] as Map)
          : null,
      event: json['event'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': type};
    if (id != null) map['id'] = id;
    if (method != null) map['method'] = method;
    if (params != null) map['params'] = params;
    if (ok != null) map['ok'] = ok;
    if (payload != null) map['payload'] = payload;
    if (error != null) map['error'] = error;
    if (event != null) map['event'] = event;
    return map;
  }

  String encode() => jsonEncode(toJson());

  static NodeFrame decode(String raw) =>
      NodeFrame.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  bool get isRequest => type == 'req';
  bool get isResponse => type == 'res';
  bool get isEvent => type == 'event';
  bool get isError => ok == false || error != null;
  bool get isOk => ok == true;
}
