class WebHelper {
  static void setLocalStorage(String key, String value) {}
  static String? getLocalStorage(String key) => null;
  static void removeLocalStorage(String key) {}
  static void listenStorage(Function(dynamic) callback) {}
  static String getHash() => '';
  static void replaceState(String hash) {}
  static void pickFile(Function(String? name, String? dataUrl) onFilePicked) {}
  static void reloadWindow() {}
  static Future<bool> checkForNewBuild(String currentBuild) async => false;
}
