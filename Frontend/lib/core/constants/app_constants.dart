class AppConstants {
  static const String appName = 'DroneHub';
  static const String appVersion = '1.0.0';

  // API — localhost works in any network since Flutter Web runs on the same Mac.
  // For testing from a phone/tablet on the same network, use:
  // http://Mohammeds-Mackbook-MacBook-Air.local:5001/api
  static const String baseUrl = 'http://localhost:5001/api';
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
