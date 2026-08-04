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

  /// 自增序号 — 标签 id 单调唯一，避免同一毫秒连开多标签时 Key 冲突
  int _idSeq = 0;

  List<TabModel> get tabs => List.unmodifiable(_tabs);
  int get activeTabIndex => _activeTabIndex;
  TabModel? get activeTab =>
      _tabs.isEmpty ? null : _tabs[_activeTabIndex];
  bool get isIncognitoMode => _isIncognitoMode;
  int get tabCount => _tabs.length;

  String _newTabId() => '${DateTime.now().millisecondsSinceEpoch}-${_idSeq++}';

  void addTab({String? url}) {
    final tab = TabModel(
      id: _newTabId(),
      url: url ?? '',
      isIncognito: _isIncognitoMode,
    );
    _tabs.add(tab);
    _activeTabIndex = _tabs.length - 1;
    notifyListeners();
  }

  /// 关闭指定标签页，保持「标签数始终 ≥ 1」的状态不变式。
  ///
  /// 关闭最后一个标签时自动新建一个默认首页标签页（New Tab）并激活，
  /// 避免进入 0 标签页的无效状态（主视图空白 / 标签管理器空态）。
  void closeTab(int index) {
    if (_tabs.isEmpty) return;
    if (index < 0 || index >= _tabs.length) return;
    _tabs.removeAt(index);
    if (_tabs.isEmpty) {
      _createDefaultTab();
    } else if (_activeTabIndex >= _tabs.length) {
      _activeTabIndex = _tabs.length - 1;
    }
    notifyListeners();
  }

  /// 新建默认首页标签页（空 URL）并激活。调用方负责 notifyListeners。
  void _createDefaultTab() {
    _tabs.add(TabModel(
      id: _newTabId(),
      isIncognito: _isIncognitoMode,
    ));
    _activeTabIndex = _tabs.length - 1;
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

  /// 关闭全部标签页 → 自动新建一个默认首页标签页并激活（tabs.length >= 1）。
  void clearAllTabs() {
    _tabs.clear();
    _createDefaultTab();
    notifyListeners();
  }
}
