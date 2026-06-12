enum TerminalMouseButton {
  left(id: 0),

  middle(id: 1),

  right(id: 2),

  // YOURSSH PATCH: wheel buttons are X11 buttons 4-7, encoded as flag 64 plus
  // the LOW TWO BITS of the button index (4→0, 5→1, 6→2, 7→3), i.e. 64-67.
  // The previous ids (64+4 … 64+7 = 68-71) produced reports no application
  // recognizes, so mouse-wheel scrolling was dead inside every mouse-aware
  // TUI (claude, htop, vim mouse=a, lazygit, tmux with mouse on, …).
  wheelUp(id: 64 + 0, isWheel: true),

  wheelDown(id: 64 + 1, isWheel: true),

  wheelLeft(id: 64 + 2, isWheel: true),

  wheelRight(id: 64 + 3, isWheel: true),
  ;

  /// The id that is used to report a button press or release to the terminal.
  ///
  /// Mouse wheel up / down are X11 buttons 4 and 5; in reports they are
  /// encoded as 64 (the wheel flag) plus their low two bits (0 and 1).
  final int id;

  /// Whether this button is a mouse wheel button.
  final bool isWheel;

  const TerminalMouseButton({required this.id, this.isWheel = false});
}
