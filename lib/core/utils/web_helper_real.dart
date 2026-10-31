import 'dart:html' as html;

class WebHelper {
  static void setLocalStorage(String key, String value) {
    html.window.localStorage[key] = value;
  }

  static String? getLocalStorage(String key) {
    return html.window.localStorage[key];
  }

  static void removeLocalStorage(String key) {
    html.window.localStorage.remove(key);
  }

  static void listenStorage(Function(dynamic) callback) {
    html.window.onStorage.listen(callback);
  }

  static String getHash() {
    return html.window.location.hash.toLowerCase();
  }

  static void replaceState(String hash) {
    if (html.window.location.hash.toLowerCase() != hash.toLowerCase()) {
      html.window.history.replaceState(null, '', hash);
    }
  }

  static void pickFile(Function(String? name, String? dataUrl) onFilePicked) {
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'image/*';
    uploadInput.click();
    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        final reader = html.FileReader();
        reader.readAsDataUrl(file);
        reader.onLoadEnd.listen((e) {
          final result = reader.result as String?;
          onFilePicked(file.name, result);
        });
      }
    });
  }

  static void reloadWindow() {
    html.window.location.reload();
  }

  static Future<bool> checkForNewBuild(String currentBuild) async {
    try {
      final req = await html.HttpRequest.request(
        '/main.dart.js?t=${DateTime.now().millisecondsSinceEpoch}',
        method: 'HEAD',
      );
      final etag = req.getResponseHeader('etag') ??
          req.getResponseHeader('last-modified') ??
          req.getResponseHeader('content-length') ??
          '';
      final savedEtag = getLocalStorage('app_build_etag');
      if (savedEtag != null && savedEtag.isNotEmpty && etag.isNotEmpty && savedEtag != etag) {
        setLocalStorage('app_build_etag', etag);
        return true;
      }
      if (etag.isNotEmpty) {
        setLocalStorage('app_build_etag', etag);
      }
    } catch (_) {}
    return false;
  }
}
