import 'package:flutter/foundation.dart';

/// Tracks whether the UI is in edit/reorder mode.
///
/// Only one surface can be in edit mode at a time.
enum EditTarget { none, dashboard, appGrid }

class EditModeProvider extends ChangeNotifier {
  EditTarget _target = EditTarget.none;
  int _editingTileIndex = -1;

  EditTarget get target => _target;
  bool get isEditing => _target != EditTarget.none;
  bool get isDashboardEditing => _target == EditTarget.dashboard;
  bool get isAppGridEditing => _target == EditTarget.appGrid;

  /// The tile index currently showing its picker (-1 when none).
  int get editingTileIndex => _editingTileIndex;

  void enter(EditTarget target, {int tileIndex = -1}) {
    if (_target == target && _editingTileIndex == tileIndex) return;
    _target = target;
    _editingTileIndex = tileIndex;
    notifyListeners();
  }

  void exit() {
    if (_target == EditTarget.none) return;
    _target = EditTarget.none;
    _editingTileIndex = -1;
    notifyListeners();
  }
}
