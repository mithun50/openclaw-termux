import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class UpdateResult {
  final String latest;
  final String url;
  final bool available;

  const UpdateResult({
    required this.latest,
    required this.url,
    required this.available,
  });
}

class UpdateService {
  static Future<UpdateResult> check() async {
    final response = await http.get(
      Uri.parse(AppConstants.githubApiLatestRelease),
      headers: {'Accept': 'application/vnd.github.v3+json'},
    );

    if (response.statusCode != 200) {
      throw Exception('GitHub API returned ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tagName = data['tag_name'] as String;
    final htmlUrl = data['html_url'] as String;

    // Strip leading 'v' if present
    final latest = tagName.startsWith('v') ? tagName.substring(1) : tagName;
    final available = _isNewer(latest, AppConstants.version);

    return UpdateResult(latest: latest, url: htmlUrl, available: available);
  }

  /// Returns true if [remote] is newer than [local] by semver comparison.
  static bool _isNewer(String remote, String local) {
    final r = remote.split('.').map(int.parse).toList();
    final l = local.split('.').map(int.parse).toList();
    for (var i = 0; i < 3; i++) {
      final rv = i < r.length ? r[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (rv > lv) return true;
      if (rv < lv) return false;
    }
    return false;
  }
}
