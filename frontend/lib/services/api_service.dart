import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Local development backend URL (Accessible by computer & physical phone over Wi-Fi)
  static String baseUrl = "http://192.168.14.235:8000/api/v1";

  // --- Integrations & Telemetry ---

  static Future<Map<String, dynamic>?> fetchIntegrationStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/integrations/status'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("Error fetching integration status: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> fetchGitHubActivity() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/integrations/github/activity'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("Error fetching GitHub activity: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> fetchDaemonStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/tracker/status'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("Error fetching daemon status: $e");
    }
    return null;
  }

  static Future<String?> getGitHubAuthUrl() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/integrations/github/auth-url'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['auth_url'];
      }
    } catch (e) {
      print("Error getting GitHub auth URL: $e");
    }
    return null;
  }

  static Future<String?> getGoogleAuthUrl() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/integrations/google/auth-url'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['auth_url'];
      }
    } catch (e) {
      print("Error getting Google auth URL: $e");
    }
    return null;
  }

  static Future<bool> disconnectGitHub() async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/integrations/github/disconnect'));
      return response.statusCode == 200;
    } catch (e) {
      print("Error disconnecting GitHub: $e");
      return false;
    }
  }

  static Future<bool> disconnectGoogle() async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/integrations/google/disconnect'));
      return response.statusCode == 200;
    } catch (e) {
      print("Error disconnecting Google: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>?> fetchGoogleCalendarEvents() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/integrations/google/calendar/events'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("Error fetching Google Calendar events: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> fetchGmailMessages() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/integrations/google/gmail/messages'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("Error fetching Gmail messages: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> fetchGoogleSummary() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/integrations/google/summary'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("Error fetching Google summary: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> fetchTrackerSummary() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/tracker/summary'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("Error fetching tracker summary: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> fetchAppBreakdown() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/tracker/app-breakdown'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("Error fetching app breakdown: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> fetchActivityTimeline() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/tracker/timeline'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("Error fetching activity timeline: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> fetchAppDetails(String appName) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/tracker/app-details?app_name=${Uri.encodeComponent(appName)}'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("Error fetching app details: $e");
    }
    return null;
  }

  // --- Habits ---

  static Future<List<dynamic>> fetchHabits() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/habits/'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("Error fetching habits: $e");
    }
    return [];
  }

  static Future<bool> createHabit(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/habits/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("Error creating habit: $e");
      return false;
    }
  }

  static Future<bool> logHabit(String habitId, int count) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/habits/$habitId/log'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'count': count}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error logging habit: $e");
      return false;
    }
  }

  // --- Tasks & Projects ---

  static Future<List<dynamic>> fetchProjects() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/projects/'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("Error fetching projects: $e");
    }
    return [];
  }

  static Future<bool> createProject(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/projects/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("Error creating project: $e");
      return false;
    }
  }

  static Future<List<dynamic>> fetchTasks() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/projects/tasks'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("Error fetching tasks: $e");
    }
    return [];
  }

  static Future<bool> createTask(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/projects/tasks'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("Error creating task: $e");
      return false;
    }
  }

  static Future<bool> recordFocusSession(int durationMinutes, String type) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/focus/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'duration_minutes': durationMinutes,
          'session_type': type,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("Error recording focus session: $e");
      return false;
    }
  }
}
