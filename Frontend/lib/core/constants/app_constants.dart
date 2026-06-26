class AppConstants {
  static const String appName = 'DroneHub';
  static const String appVersion = '1.0.0';

  // API
  static const String baseUrl = 'http://10.155.83.72:5001/api';
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String themeKey = 'theme_mode';

  // Pagination
  static const int defaultPageSize = 20;

  // Categories
  static const List<Map<String, String>> categories = [
    {'value': 'esc', 'label': 'ESC'},
    {'value': 'flight_controller', 'label': 'Flight Controllers'},
    {'value': 'motor', 'label': 'Motors'},
    {'value': 'fiber_optic', 'label': 'Fiber Optic'},
    {'value': 'frame', 'label': 'Frames'},
    {'value': 'propeller', 'label': 'Propellers'},
    {'value': 'battery', 'label': 'Batteries'},
    {'value': 'camera', 'label': 'Cameras'},
    {'value': 'vtx', 'label': 'VTX'},
    {'value': 'receiver', 'label': 'Receivers'},
    {'value': 'accessories', 'label': 'Accessories'},
  ];
}
