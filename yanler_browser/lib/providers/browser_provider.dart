import 'package:flutter/foundation.dart';

class TabModel {
  final String id;
  String title;
  String url;
  bool isLoading;
  bool isIncognito;

  TabModel({
    required this.id,
    this.title = '新标签页',
    this.url = '',
    this.isLoading = false,
    this.isIncognito = false,
  });
}

class BrowserProvider extends ChangeNotifier {
  final List<TabModel> _tabs = [];
  int _activeTabIndex = 0;
  bool _isIncognitoMode = false;

  List<TabModel> get tabs => List.unmodifiable(_tabs);
  int get activeTabIndex => _activeTabIndex;
  TabModel? get activeTab =>
      _tabs.isEmpty ? null : _tabs[_activeTabIndex];
  bool get isIncognitoMode => _isIncognitoMode;
  int get tabCount => _tabs.length;

  void addTab({String? url}) {
    final tab = TabModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: url ?? '',
      isIncognito: _isIncognitoMode,
    );
    _tabs.add(tab);
    _activeTabIndex = _tabs.length - 1;
    notifyListeners();
  }

  void closeTab(int index) {
    if (_tabs.isEmpty) return;
    _tabs.removeAt(index);
    if (_activeTabIndex >= _tabs.length && _tabs.isNotEmpty) {
      _activeTabIndex = _tabs.length - 1;
    }
    notifyListeners();
  }

  void switchTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      _activeTabIndex = index;
      notifyListeners();
    }
  }

  void updateTabUrl(int index, String url) {
    if (index >= 0 && index < _tabs.length) {
      _tabs[index].url = url;
      notifyListeners();
    }
  }

  void updateTabTitle(int index, String title) {
    if (index >= 0 && index < _tabs.length) {
      _tabs[index].title = title;
      notifyListeners();
    }
  }

  void setTabLoading(int index, bool loading) {
    if (index >= 0 && index < _tabs.length) {
      _tabs[index].isLoading = loading;
      notifyListeners();
    }
  }

  void toggleIncognito() {
    _isIncognitoMode = !_isIncognitoMode;
    notifyListeners();
  }

  void clearAllTabs() {
    _tabs.clear();
    _activeTabIndex = 0;
    notifyListeners();
  }
}
