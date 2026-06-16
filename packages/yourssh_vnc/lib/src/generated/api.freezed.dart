// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'api.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$VncEvent {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int sessionId) started,
    required TResult Function(int width, int height) connected,
    required TResult Function(int width, int height) resize,
    required TResult Function(
      int x,
      int y,
      int width,
      int height,
      Uint8List rgba,
    )
    frameUpdate,
    required TResult Function(String text) clipboardText,
    required TResult Function() bell,
    required TResult Function(String reason) disconnected,
    required TResult Function(String message) error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int sessionId)? started,
    TResult? Function(int width, int height)? connected,
    TResult? Function(int width, int height)? resize,
    TResult? Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult? Function(String text)? clipboardText,
    TResult? Function()? bell,
    TResult? Function(String reason)? disconnected,
    TResult? Function(String message)? error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int sessionId)? started,
    TResult Function(int width, int height)? connected,
    TResult Function(int width, int height)? resize,
    TResult Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult Function(String text)? clipboardText,
    TResult Function()? bell,
    TResult Function(String reason)? disconnected,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(VncEvent_Started value) started,
    required TResult Function(VncEvent_Connected value) connected,
    required TResult Function(VncEvent_Resize value) resize,
    required TResult Function(VncEvent_FrameUpdate value) frameUpdate,
    required TResult Function(VncEvent_ClipboardText value) clipboardText,
    required TResult Function(VncEvent_Bell value) bell,
    required TResult Function(VncEvent_Disconnected value) disconnected,
    required TResult Function(VncEvent_Error value) error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(VncEvent_Started value)? started,
    TResult? Function(VncEvent_Connected value)? connected,
    TResult? Function(VncEvent_Resize value)? resize,
    TResult? Function(VncEvent_FrameUpdate value)? frameUpdate,
    TResult? Function(VncEvent_ClipboardText value)? clipboardText,
    TResult? Function(VncEvent_Bell value)? bell,
    TResult? Function(VncEvent_Disconnected value)? disconnected,
    TResult? Function(VncEvent_Error value)? error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(VncEvent_Started value)? started,
    TResult Function(VncEvent_Connected value)? connected,
    TResult Function(VncEvent_Resize value)? resize,
    TResult Function(VncEvent_FrameUpdate value)? frameUpdate,
    TResult Function(VncEvent_ClipboardText value)? clipboardText,
    TResult Function(VncEvent_Bell value)? bell,
    TResult Function(VncEvent_Disconnected value)? disconnected,
    TResult Function(VncEvent_Error value)? error,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VncEventCopyWith<$Res> {
  factory $VncEventCopyWith(VncEvent value, $Res Function(VncEvent) then) =
      _$VncEventCopyWithImpl<$Res, VncEvent>;
}

/// @nodoc
class _$VncEventCopyWithImpl<$Res, $Val extends VncEvent>
    implements $VncEventCopyWith<$Res> {
  _$VncEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VncEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$VncEvent_StartedImplCopyWith<$Res> {
  factory _$$VncEvent_StartedImplCopyWith(
    _$VncEvent_StartedImpl value,
    $Res Function(_$VncEvent_StartedImpl) then,
  ) = __$$VncEvent_StartedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int sessionId});
}

/// @nodoc
class __$$VncEvent_StartedImplCopyWithImpl<$Res>
    extends _$VncEventCopyWithImpl<$Res, _$VncEvent_StartedImpl>
    implements _$$VncEvent_StartedImplCopyWith<$Res> {
  __$$VncEvent_StartedImplCopyWithImpl(
    _$VncEvent_StartedImpl _value,
    $Res Function(_$VncEvent_StartedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of VncEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? sessionId = null}) {
    return _then(
      _$VncEvent_StartedImpl(
        sessionId: null == sessionId
            ? _value.sessionId
            : sessionId // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$VncEvent_StartedImpl extends VncEvent_Started {
  const _$VncEvent_StartedImpl({required this.sessionId}) : super._();

  @override
  final int sessionId;

  @override
  String toString() {
    return 'VncEvent.started(sessionId: $sessionId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VncEvent_StartedImpl &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId));
  }

  @override
  int get hashCode => Object.hash(runtimeType, sessionId);

  /// Create a copy of VncEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VncEvent_StartedImplCopyWith<_$VncEvent_StartedImpl> get copyWith =>
      __$$VncEvent_StartedImplCopyWithImpl<_$VncEvent_StartedImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int sessionId) started,
    required TResult Function(int width, int height) connected,
    required TResult Function(int width, int height) resize,
    required TResult Function(
      int x,
      int y,
      int width,
      int height,
      Uint8List rgba,
    )
    frameUpdate,
    required TResult Function(String text) clipboardText,
    required TResult Function() bell,
    required TResult Function(String reason) disconnected,
    required TResult Function(String message) error,
  }) {
    return started(sessionId);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int sessionId)? started,
    TResult? Function(int width, int height)? connected,
    TResult? Function(int width, int height)? resize,
    TResult? Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult? Function(String text)? clipboardText,
    TResult? Function()? bell,
    TResult? Function(String reason)? disconnected,
    TResult? Function(String message)? error,
  }) {
    return started?.call(sessionId);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int sessionId)? started,
    TResult Function(int width, int height)? connected,
    TResult Function(int width, int height)? resize,
    TResult Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult Function(String text)? clipboardText,
    TResult Function()? bell,
    TResult Function(String reason)? disconnected,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (started != null) {
      return started(sessionId);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(VncEvent_Started value) started,
    required TResult Function(VncEvent_Connected value) connected,
    required TResult Function(VncEvent_Resize value) resize,
    required TResult Function(VncEvent_FrameUpdate value) frameUpdate,
    required TResult Function(VncEvent_ClipboardText value) clipboardText,
    required TResult Function(VncEvent_Bell value) bell,
    required TResult Function(VncEvent_Disconnected value) disconnected,
    required TResult Function(VncEvent_Error value) error,
  }) {
    return started(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(VncEvent_Started value)? started,
    TResult? Function(VncEvent_Connected value)? connected,
    TResult? Function(VncEvent_Resize value)? resize,
    TResult? Function(VncEvent_FrameUpdate value)? frameUpdate,
    TResult? Function(VncEvent_ClipboardText value)? clipboardText,
    TResult? Function(VncEvent_Bell value)? bell,
    TResult? Function(VncEvent_Disconnected value)? disconnected,
    TResult? Function(VncEvent_Error value)? error,
  }) {
    return started?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(VncEvent_Started value)? started,
    TResult Function(VncEvent_Connected value)? connected,
    TResult Function(VncEvent_Resize value)? resize,
    TResult Function(VncEvent_FrameUpdate value)? frameUpdate,
    TResult Function(VncEvent_ClipboardText value)? clipboardText,
    TResult Function(VncEvent_Bell value)? bell,
    TResult Function(VncEvent_Disconnected value)? disconnected,
    TResult Function(VncEvent_Error value)? error,
    required TResult orElse(),
  }) {
    if (started != null) {
      return started(this);
    }
    return orElse();
  }
}

abstract class VncEvent_Started extends VncEvent {
  const factory VncEvent_Started({required final int sessionId}) =
      _$VncEvent_StartedImpl;
  const VncEvent_Started._() : super._();

  int get sessionId;

  /// Create a copy of VncEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VncEvent_StartedImplCopyWith<_$VncEvent_StartedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$VncEvent_ConnectedImplCopyWith<$Res> {
  factory _$$VncEvent_ConnectedImplCopyWith(
    _$VncEvent_ConnectedImpl value,
    $Res Function(_$VncEvent_ConnectedImpl) then,
  ) = __$$VncEvent_ConnectedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int width, int height});
}

/// @nodoc
class __$$VncEvent_ConnectedImplCopyWithImpl<$Res>
    extends _$VncEventCopyWithImpl<$Res, _$VncEvent_ConnectedImpl>
    implements _$$VncEvent_ConnectedImplCopyWith<$Res> {
  __$$VncEvent_ConnectedImplCopyWithImpl(
    _$VncEvent_ConnectedImpl _value,
    $Res Function(_$VncEvent_ConnectedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of VncEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? width = null, Object? height = null}) {
    return _then(
      _$VncEvent_ConnectedImpl(
        width: null == width
            ? _value.width
            : width // ignore: cast_nullable_to_non_nullable
                  as int,
        height: null == height
            ? _value.height
            : height // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$VncEvent_ConnectedImpl extends VncEvent_Connected {
  const _$VncEvent_ConnectedImpl({required this.width, required this.height})
    : super._();

  @override
  final int width;
  @override
  final int height;

  @override
  String toString() {
    return 'VncEvent.connected(width: $width, height: $height)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VncEvent_ConnectedImpl &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.height, height) || other.height == height));
  }

  @override
  int get hashCode => Object.hash(runtimeType, width, height);

  /// Create a copy of VncEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VncEvent_ConnectedImplCopyWith<_$VncEvent_ConnectedImpl> get copyWith =>
      __$$VncEvent_ConnectedImplCopyWithImpl<_$VncEvent_ConnectedImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int sessionId) started,
    required TResult Function(int width, int height) connected,
    required TResult Function(int width, int height) resize,
    required TResult Function(
      int x,
      int y,
      int width,
      int height,
      Uint8List rgba,
    )
    frameUpdate,
    required TResult Function(String text) clipboardText,
    required TResult Function() bell,
    required TResult Function(String reason) disconnected,
    required TResult Function(String message) error,
  }) {
    return connected(width, height);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int sessionId)? started,
    TResult? Function(int width, int height)? connected,
    TResult? Function(int width, int height)? resize,
    TResult? Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult? Function(String text)? clipboardText,
    TResult? Function()? bell,
    TResult? Function(String reason)? disconnected,
    TResult? Function(String message)? error,
  }) {
    return connected?.call(width, height);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int sessionId)? started,
    TResult Function(int width, int height)? connected,
    TResult Function(int width, int height)? resize,
    TResult Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult Function(String text)? clipboardText,
    TResult Function()? bell,
    TResult Function(String reason)? disconnected,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (connected != null) {
      return connected(width, height);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(VncEvent_Started value) started,
    required TResult Function(VncEvent_Connected value) connected,
    required TResult Function(VncEvent_Resize value) resize,
    required TResult Function(VncEvent_FrameUpdate value) frameUpdate,
    required TResult Function(VncEvent_ClipboardText value) clipboardText,
    required TResult Function(VncEvent_Bell value) bell,
    required TResult Function(VncEvent_Disconnected value) disconnected,
    required TResult Function(VncEvent_Error value) error,
  }) {
    return connected(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(VncEvent_Started value)? started,
    TResult? Function(VncEvent_Connected value)? connected,
    TResult? Function(VncEvent_Resize value)? resize,
    TResult? Function(VncEvent_FrameUpdate value)? frameUpdate,
    TResult? Function(VncEvent_ClipboardText value)? clipboardText,
    TResult? Function(VncEvent_Bell value)? bell,
    TResult? Function(VncEvent_Disconnected value)? disconnected,
    TResult? Function(VncEvent_Error value)? error,
  }) {
    return connected?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(VncEvent_Started value)? started,
    TResult Function(VncEvent_Connected value)? connected,
    TResult Function(VncEvent_Resize value)? resize,
    TResult Function(VncEvent_FrameUpdate value)? frameUpdate,
    TResult Function(VncEvent_ClipboardText value)? clipboardText,
    TResult Function(VncEvent_Bell value)? bell,
    TResult Function(VncEvent_Disconnected value)? disconnected,
    TResult Function(VncEvent_Error value)? error,
    required TResult orElse(),
  }) {
    if (connected != null) {
      return connected(this);
    }
    return orElse();
  }
}

abstract class VncEvent_Connected extends VncEvent {
  const factory VncEvent_Connected({
    required final int width,
    required final int height,
  }) = _$VncEvent_ConnectedImpl;
  const VncEvent_Connected._() : super._();

  int get width;
  int get height;

  /// Create a copy of VncEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VncEvent_ConnectedImplCopyWith<_$VncEvent_ConnectedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$VncEvent_ResizeImplCopyWith<$Res> {
  factory _$$VncEvent_ResizeImplCopyWith(
    _$VncEvent_ResizeImpl value,
    $Res Function(_$VncEvent_ResizeImpl) then,
  ) = __$$VncEvent_ResizeImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int width, int height});
}

/// @nodoc
class __$$VncEvent_ResizeImplCopyWithImpl<$Res>
    extends _$VncEventCopyWithImpl<$Res, _$VncEvent_ResizeImpl>
    implements _$$VncEvent_ResizeImplCopyWith<$Res> {
  __$$VncEvent_ResizeImplCopyWithImpl(
    _$VncEvent_ResizeImpl _value,
    $Res Function(_$VncEvent_ResizeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of VncEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? width = null, Object? height = null}) {
    return _then(
      _$VncEvent_ResizeImpl(
        width: null == width
            ? _value.width
            : width // ignore: cast_nullable_to_non_nullable
                  as int,
        height: null == height
            ? _value.height
            : height // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$VncEvent_ResizeImpl extends VncEvent_Resize {
  const _$VncEvent_ResizeImpl({required this.width, required this.height})
    : super._();

  @override
  final int width;
  @override
  final int height;

  @override
  String toString() {
    return 'VncEvent.resize(width: $width, height: $height)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VncEvent_ResizeImpl &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.height, height) || other.height == height));
  }

  @override
  int get hashCode => Object.hash(runtimeType, width, height);

  /// Create a copy of VncEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VncEvent_ResizeImplCopyWith<_$VncEvent_ResizeImpl> get copyWith =>
      __$$VncEvent_ResizeImplCopyWithImpl<_$VncEvent_ResizeImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int sessionId) started,
    required TResult Function(int width, int height) connected,
    required TResult Function(int width, int height) resize,
    required TResult Function(
      int x,
      int y,
      int width,
      int height,
      Uint8List rgba,
    )
    frameUpdate,
    required TResult Function(String text) clipboardText,
    required TResult Function() bell,
    required TResult Function(String reason) disconnected,
    required TResult Function(String message) error,
  }) {
    return resize(width, height);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int sessionId)? started,
    TResult? Function(int width, int height)? connected,
    TResult? Function(int width, int height)? resize,
    TResult? Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult? Function(String text)? clipboardText,
    TResult? Function()? bell,
    TResult? Function(String reason)? disconnected,
    TResult? Function(String message)? error,
  }) {
    return resize?.call(width, height);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int sessionId)? started,
    TResult Function(int width, int height)? connected,
    TResult Function(int width, int height)? resize,
    TResult Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult Function(String text)? clipboardText,
    TResult Function()? bell,
    TResult Function(String reason)? disconnected,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (resize != null) {
      return resize(width, height);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(VncEvent_Started value) started,
    required TResult Function(VncEvent_Connected value) connected,
    required TResult Function(VncEvent_Resize value) resize,
    required TResult Function(VncEvent_FrameUpdate value) frameUpdate,
    required TResult Function(VncEvent_ClipboardText value) clipboardText,
    required TResult Function(VncEvent_Bell value) bell,
    required TResult Function(VncEvent_Disconnected value) disconnected,
    required TResult Function(VncEvent_Error value) error,
  }) {
    return resize(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(VncEvent_Started value)? started,
    TResult? Function(VncEvent_Connected value)? connected,
    TResult? Function(VncEvent_Resize value)? resize,
    TResult? Function(VncEvent_FrameUpdate value)? frameUpdate,
    TResult? Function(VncEvent_ClipboardText value)? clipboardText,
    TResult? Function(VncEvent_Bell value)? bell,
    TResult? Function(VncEvent_Disconnected value)? disconnected,
    TResult? Function(VncEvent_Error value)? error,
  }) {
    return resize?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(VncEvent_Started value)? started,
    TResult Function(VncEvent_Connected value)? connected,
    TResult Function(VncEvent_Resize value)? resize,
    TResult Function(VncEvent_FrameUpdate value)? frameUpdate,
    TResult Function(VncEvent_ClipboardText value)? clipboardText,
    TResult Function(VncEvent_Bell value)? bell,
    TResult Function(VncEvent_Disconnected value)? disconnected,
    TResult Function(VncEvent_Error value)? error,
    required TResult orElse(),
  }) {
    if (resize != null) {
      return resize(this);
    }
    return orElse();
  }
}

abstract class VncEvent_Resize extends VncEvent {
  const factory VncEvent_Resize({
    required final int width,
    required final int height,
  }) = _$VncEvent_ResizeImpl;
  const VncEvent_Resize._() : super._();

  int get width;
  int get height;

  /// Create a copy of VncEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VncEvent_ResizeImplCopyWith<_$VncEvent_ResizeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$VncEvent_FrameUpdateImplCopyWith<$Res> {
  factory _$$VncEvent_FrameUpdateImplCopyWith(
    _$VncEvent_FrameUpdateImpl value,
    $Res Function(_$VncEvent_FrameUpdateImpl) then,
  ) = __$$VncEvent_FrameUpdateImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int x, int y, int width, int height, Uint8List rgba});
}

/// @nodoc
class __$$VncEvent_FrameUpdateImplCopyWithImpl<$Res>
    extends _$VncEventCopyWithImpl<$Res, _$VncEvent_FrameUpdateImpl>
    implements _$$VncEvent_FrameUpdateImplCopyWith<$Res> {
  __$$VncEvent_FrameUpdateImplCopyWithImpl(
    _$VncEvent_FrameUpdateImpl _value,
    $Res Function(_$VncEvent_FrameUpdateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of VncEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? x = null,
    Object? y = null,
    Object? width = null,
    Object? height = null,
    Object? rgba = null,
  }) {
    return _then(
      _$VncEvent_FrameUpdateImpl(
        x: null == x
            ? _value.x
            : x // ignore: cast_nullable_to_non_nullable
                  as int,
        y: null == y
            ? _value.y
            : y // ignore: cast_nullable_to_non_nullable
                  as int,
        width: null == width
            ? _value.width
            : width // ignore: cast_nullable_to_non_nullable
                  as int,
        height: null == height
            ? _value.height
            : height // ignore: cast_nullable_to_non_nullable
                  as int,
        rgba: null == rgba
            ? _value.rgba
            : rgba // ignore: cast_nullable_to_non_nullable
                  as Uint8List,
      ),
    );
  }
}

/// @nodoc

class _$VncEvent_FrameUpdateImpl extends VncEvent_FrameUpdate {
  const _$VncEvent_FrameUpdateImpl({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rgba,
  }) : super._();

  @override
  final int x;
  @override
  final int y;
  @override
  final int width;
  @override
  final int height;
  @override
  final Uint8List rgba;

  @override
  String toString() {
    return 'VncEvent.frameUpdate(x: $x, y: $y, width: $width, height: $height, rgba: $rgba)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VncEvent_FrameUpdateImpl &&
            (identical(other.x, x) || other.x == x) &&
            (identical(other.y, y) || other.y == y) &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.height, height) || other.height == height) &&
            const DeepCollectionEquality().equals(other.rgba, rgba));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    x,
    y,
    width,
    height,
    const DeepCollectionEquality().hash(rgba),
  );

  /// Create a copy of VncEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VncEvent_FrameUpdateImplCopyWith<_$VncEvent_FrameUpdateImpl>
  get copyWith =>
      __$$VncEvent_FrameUpdateImplCopyWithImpl<_$VncEvent_FrameUpdateImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int sessionId) started,
    required TResult Function(int width, int height) connected,
    required TResult Function(int width, int height) resize,
    required TResult Function(
      int x,
      int y,
      int width,
      int height,
      Uint8List rgba,
    )
    frameUpdate,
    required TResult Function(String text) clipboardText,
    required TResult Function() bell,
    required TResult Function(String reason) disconnected,
    required TResult Function(String message) error,
  }) {
    return frameUpdate(x, y, width, height, rgba);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int sessionId)? started,
    TResult? Function(int width, int height)? connected,
    TResult? Function(int width, int height)? resize,
    TResult? Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult? Function(String text)? clipboardText,
    TResult? Function()? bell,
    TResult? Function(String reason)? disconnected,
    TResult? Function(String message)? error,
  }) {
    return frameUpdate?.call(x, y, width, height, rgba);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int sessionId)? started,
    TResult Function(int width, int height)? connected,
    TResult Function(int width, int height)? resize,
    TResult Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult Function(String text)? clipboardText,
    TResult Function()? bell,
    TResult Function(String reason)? disconnected,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (frameUpdate != null) {
      return frameUpdate(x, y, width, height, rgba);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(VncEvent_Started value) started,
    required TResult Function(VncEvent_Connected value) connected,
    required TResult Function(VncEvent_Resize value) resize,
    required TResult Function(VncEvent_FrameUpdate value) frameUpdate,
    required TResult Function(VncEvent_ClipboardText value) clipboardText,
    required TResult Function(VncEvent_Bell value) bell,
    required TResult Function(VncEvent_Disconnected value) disconnected,
    required TResult Function(VncEvent_Error value) error,
  }) {
    return frameUpdate(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(VncEvent_Started value)? started,
    TResult? Function(VncEvent_Connected value)? connected,
    TResult? Function(VncEvent_Resize value)? resize,
    TResult? Function(VncEvent_FrameUpdate value)? frameUpdate,
    TResult? Function(VncEvent_ClipboardText value)? clipboardText,
    TResult? Function(VncEvent_Bell value)? bell,
    TResult? Function(VncEvent_Disconnected value)? disconnected,
    TResult? Function(VncEvent_Error value)? error,
  }) {
    return frameUpdate?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(VncEvent_Started value)? started,
    TResult Function(VncEvent_Connected value)? connected,
    TResult Function(VncEvent_Resize value)? resize,
    TResult Function(VncEvent_FrameUpdate value)? frameUpdate,
    TResult Function(VncEvent_ClipboardText value)? clipboardText,
    TResult Function(VncEvent_Bell value)? bell,
    TResult Function(VncEvent_Disconnected value)? disconnected,
    TResult Function(VncEvent_Error value)? error,
    required TResult orElse(),
  }) {
    if (frameUpdate != null) {
      return frameUpdate(this);
    }
    return orElse();
  }
}

abstract class VncEvent_FrameUpdate extends VncEvent {
  const factory VncEvent_FrameUpdate({
    required final int x,
    required final int y,
    required final int width,
    required final int height,
    required final Uint8List rgba,
  }) = _$VncEvent_FrameUpdateImpl;
  const VncEvent_FrameUpdate._() : super._();

  int get x;
  int get y;
  int get width;
  int get height;
  Uint8List get rgba;

  /// Create a copy of VncEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VncEvent_FrameUpdateImplCopyWith<_$VncEvent_FrameUpdateImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$VncEvent_ClipboardTextImplCopyWith<$Res> {
  factory _$$VncEvent_ClipboardTextImplCopyWith(
    _$VncEvent_ClipboardTextImpl value,
    $Res Function(_$VncEvent_ClipboardTextImpl) then,
  ) = __$$VncEvent_ClipboardTextImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String text});
}

/// @nodoc
class __$$VncEvent_ClipboardTextImplCopyWithImpl<$Res>
    extends _$VncEventCopyWithImpl<$Res, _$VncEvent_ClipboardTextImpl>
    implements _$$VncEvent_ClipboardTextImplCopyWith<$Res> {
  __$$VncEvent_ClipboardTextImplCopyWithImpl(
    _$VncEvent_ClipboardTextImpl _value,
    $Res Function(_$VncEvent_ClipboardTextImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of VncEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? text = null}) {
    return _then(
      _$VncEvent_ClipboardTextImpl(
        text: null == text
            ? _value.text
            : text // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$VncEvent_ClipboardTextImpl extends VncEvent_ClipboardText {
  const _$VncEvent_ClipboardTextImpl({required this.text}) : super._();

  @override
  final String text;

  @override
  String toString() {
    return 'VncEvent.clipboardText(text: $text)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VncEvent_ClipboardTextImpl &&
            (identical(other.text, text) || other.text == text));
  }

  @override
  int get hashCode => Object.hash(runtimeType, text);

  /// Create a copy of VncEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VncEvent_ClipboardTextImplCopyWith<_$VncEvent_ClipboardTextImpl>
  get copyWith =>
      __$$VncEvent_ClipboardTextImplCopyWithImpl<_$VncEvent_ClipboardTextImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int sessionId) started,
    required TResult Function(int width, int height) connected,
    required TResult Function(int width, int height) resize,
    required TResult Function(
      int x,
      int y,
      int width,
      int height,
      Uint8List rgba,
    )
    frameUpdate,
    required TResult Function(String text) clipboardText,
    required TResult Function() bell,
    required TResult Function(String reason) disconnected,
    required TResult Function(String message) error,
  }) {
    return clipboardText(text);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int sessionId)? started,
    TResult? Function(int width, int height)? connected,
    TResult? Function(int width, int height)? resize,
    TResult? Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult? Function(String text)? clipboardText,
    TResult? Function()? bell,
    TResult? Function(String reason)? disconnected,
    TResult? Function(String message)? error,
  }) {
    return clipboardText?.call(text);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int sessionId)? started,
    TResult Function(int width, int height)? connected,
    TResult Function(int width, int height)? resize,
    TResult Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult Function(String text)? clipboardText,
    TResult Function()? bell,
    TResult Function(String reason)? disconnected,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (clipboardText != null) {
      return clipboardText(text);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(VncEvent_Started value) started,
    required TResult Function(VncEvent_Connected value) connected,
    required TResult Function(VncEvent_Resize value) resize,
    required TResult Function(VncEvent_FrameUpdate value) frameUpdate,
    required TResult Function(VncEvent_ClipboardText value) clipboardText,
    required TResult Function(VncEvent_Bell value) bell,
    required TResult Function(VncEvent_Disconnected value) disconnected,
    required TResult Function(VncEvent_Error value) error,
  }) {
    return clipboardText(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(VncEvent_Started value)? started,
    TResult? Function(VncEvent_Connected value)? connected,
    TResult? Function(VncEvent_Resize value)? resize,
    TResult? Function(VncEvent_FrameUpdate value)? frameUpdate,
    TResult? Function(VncEvent_ClipboardText value)? clipboardText,
    TResult? Function(VncEvent_Bell value)? bell,
    TResult? Function(VncEvent_Disconnected value)? disconnected,
    TResult? Function(VncEvent_Error value)? error,
  }) {
    return clipboardText?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(VncEvent_Started value)? started,
    TResult Function(VncEvent_Connected value)? connected,
    TResult Function(VncEvent_Resize value)? resize,
    TResult Function(VncEvent_FrameUpdate value)? frameUpdate,
    TResult Function(VncEvent_ClipboardText value)? clipboardText,
    TResult Function(VncEvent_Bell value)? bell,
    TResult Function(VncEvent_Disconnected value)? disconnected,
    TResult Function(VncEvent_Error value)? error,
    required TResult orElse(),
  }) {
    if (clipboardText != null) {
      return clipboardText(this);
    }
    return orElse();
  }
}

abstract class VncEvent_ClipboardText extends VncEvent {
  const factory VncEvent_ClipboardText({required final String text}) =
      _$VncEvent_ClipboardTextImpl;
  const VncEvent_ClipboardText._() : super._();

  String get text;

  /// Create a copy of VncEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VncEvent_ClipboardTextImplCopyWith<_$VncEvent_ClipboardTextImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$VncEvent_BellImplCopyWith<$Res> {
  factory _$$VncEvent_BellImplCopyWith(
    _$VncEvent_BellImpl value,
    $Res Function(_$VncEvent_BellImpl) then,
  ) = __$$VncEvent_BellImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$VncEvent_BellImplCopyWithImpl<$Res>
    extends _$VncEventCopyWithImpl<$Res, _$VncEvent_BellImpl>
    implements _$$VncEvent_BellImplCopyWith<$Res> {
  __$$VncEvent_BellImplCopyWithImpl(
    _$VncEvent_BellImpl _value,
    $Res Function(_$VncEvent_BellImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of VncEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$VncEvent_BellImpl extends VncEvent_Bell {
  const _$VncEvent_BellImpl() : super._();

  @override
  String toString() {
    return 'VncEvent.bell()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$VncEvent_BellImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int sessionId) started,
    required TResult Function(int width, int height) connected,
    required TResult Function(int width, int height) resize,
    required TResult Function(
      int x,
      int y,
      int width,
      int height,
      Uint8List rgba,
    )
    frameUpdate,
    required TResult Function(String text) clipboardText,
    required TResult Function() bell,
    required TResult Function(String reason) disconnected,
    required TResult Function(String message) error,
  }) {
    return bell();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int sessionId)? started,
    TResult? Function(int width, int height)? connected,
    TResult? Function(int width, int height)? resize,
    TResult? Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult? Function(String text)? clipboardText,
    TResult? Function()? bell,
    TResult? Function(String reason)? disconnected,
    TResult? Function(String message)? error,
  }) {
    return bell?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int sessionId)? started,
    TResult Function(int width, int height)? connected,
    TResult Function(int width, int height)? resize,
    TResult Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult Function(String text)? clipboardText,
    TResult Function()? bell,
    TResult Function(String reason)? disconnected,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (bell != null) {
      return bell();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(VncEvent_Started value) started,
    required TResult Function(VncEvent_Connected value) connected,
    required TResult Function(VncEvent_Resize value) resize,
    required TResult Function(VncEvent_FrameUpdate value) frameUpdate,
    required TResult Function(VncEvent_ClipboardText value) clipboardText,
    required TResult Function(VncEvent_Bell value) bell,
    required TResult Function(VncEvent_Disconnected value) disconnected,
    required TResult Function(VncEvent_Error value) error,
  }) {
    return bell(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(VncEvent_Started value)? started,
    TResult? Function(VncEvent_Connected value)? connected,
    TResult? Function(VncEvent_Resize value)? resize,
    TResult? Function(VncEvent_FrameUpdate value)? frameUpdate,
    TResult? Function(VncEvent_ClipboardText value)? clipboardText,
    TResult? Function(VncEvent_Bell value)? bell,
    TResult? Function(VncEvent_Disconnected value)? disconnected,
    TResult? Function(VncEvent_Error value)? error,
  }) {
    return bell?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(VncEvent_Started value)? started,
    TResult Function(VncEvent_Connected value)? connected,
    TResult Function(VncEvent_Resize value)? resize,
    TResult Function(VncEvent_FrameUpdate value)? frameUpdate,
    TResult Function(VncEvent_ClipboardText value)? clipboardText,
    TResult Function(VncEvent_Bell value)? bell,
    TResult Function(VncEvent_Disconnected value)? disconnected,
    TResult Function(VncEvent_Error value)? error,
    required TResult orElse(),
  }) {
    if (bell != null) {
      return bell(this);
    }
    return orElse();
  }
}

abstract class VncEvent_Bell extends VncEvent {
  const factory VncEvent_Bell() = _$VncEvent_BellImpl;
  const VncEvent_Bell._() : super._();
}

/// @nodoc
abstract class _$$VncEvent_DisconnectedImplCopyWith<$Res> {
  factory _$$VncEvent_DisconnectedImplCopyWith(
    _$VncEvent_DisconnectedImpl value,
    $Res Function(_$VncEvent_DisconnectedImpl) then,
  ) = __$$VncEvent_DisconnectedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String reason});
}

/// @nodoc
class __$$VncEvent_DisconnectedImplCopyWithImpl<$Res>
    extends _$VncEventCopyWithImpl<$Res, _$VncEvent_DisconnectedImpl>
    implements _$$VncEvent_DisconnectedImplCopyWith<$Res> {
  __$$VncEvent_DisconnectedImplCopyWithImpl(
    _$VncEvent_DisconnectedImpl _value,
    $Res Function(_$VncEvent_DisconnectedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of VncEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? reason = null}) {
    return _then(
      _$VncEvent_DisconnectedImpl(
        reason: null == reason
            ? _value.reason
            : reason // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$VncEvent_DisconnectedImpl extends VncEvent_Disconnected {
  const _$VncEvent_DisconnectedImpl({required this.reason}) : super._();

  @override
  final String reason;

  @override
  String toString() {
    return 'VncEvent.disconnected(reason: $reason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VncEvent_DisconnectedImpl &&
            (identical(other.reason, reason) || other.reason == reason));
  }

  @override
  int get hashCode => Object.hash(runtimeType, reason);

  /// Create a copy of VncEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VncEvent_DisconnectedImplCopyWith<_$VncEvent_DisconnectedImpl>
  get copyWith =>
      __$$VncEvent_DisconnectedImplCopyWithImpl<_$VncEvent_DisconnectedImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int sessionId) started,
    required TResult Function(int width, int height) connected,
    required TResult Function(int width, int height) resize,
    required TResult Function(
      int x,
      int y,
      int width,
      int height,
      Uint8List rgba,
    )
    frameUpdate,
    required TResult Function(String text) clipboardText,
    required TResult Function() bell,
    required TResult Function(String reason) disconnected,
    required TResult Function(String message) error,
  }) {
    return disconnected(reason);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int sessionId)? started,
    TResult? Function(int width, int height)? connected,
    TResult? Function(int width, int height)? resize,
    TResult? Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult? Function(String text)? clipboardText,
    TResult? Function()? bell,
    TResult? Function(String reason)? disconnected,
    TResult? Function(String message)? error,
  }) {
    return disconnected?.call(reason);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int sessionId)? started,
    TResult Function(int width, int height)? connected,
    TResult Function(int width, int height)? resize,
    TResult Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult Function(String text)? clipboardText,
    TResult Function()? bell,
    TResult Function(String reason)? disconnected,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (disconnected != null) {
      return disconnected(reason);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(VncEvent_Started value) started,
    required TResult Function(VncEvent_Connected value) connected,
    required TResult Function(VncEvent_Resize value) resize,
    required TResult Function(VncEvent_FrameUpdate value) frameUpdate,
    required TResult Function(VncEvent_ClipboardText value) clipboardText,
    required TResult Function(VncEvent_Bell value) bell,
    required TResult Function(VncEvent_Disconnected value) disconnected,
    required TResult Function(VncEvent_Error value) error,
  }) {
    return disconnected(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(VncEvent_Started value)? started,
    TResult? Function(VncEvent_Connected value)? connected,
    TResult? Function(VncEvent_Resize value)? resize,
    TResult? Function(VncEvent_FrameUpdate value)? frameUpdate,
    TResult? Function(VncEvent_ClipboardText value)? clipboardText,
    TResult? Function(VncEvent_Bell value)? bell,
    TResult? Function(VncEvent_Disconnected value)? disconnected,
    TResult? Function(VncEvent_Error value)? error,
  }) {
    return disconnected?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(VncEvent_Started value)? started,
    TResult Function(VncEvent_Connected value)? connected,
    TResult Function(VncEvent_Resize value)? resize,
    TResult Function(VncEvent_FrameUpdate value)? frameUpdate,
    TResult Function(VncEvent_ClipboardText value)? clipboardText,
    TResult Function(VncEvent_Bell value)? bell,
    TResult Function(VncEvent_Disconnected value)? disconnected,
    TResult Function(VncEvent_Error value)? error,
    required TResult orElse(),
  }) {
    if (disconnected != null) {
      return disconnected(this);
    }
    return orElse();
  }
}

abstract class VncEvent_Disconnected extends VncEvent {
  const factory VncEvent_Disconnected({required final String reason}) =
      _$VncEvent_DisconnectedImpl;
  const VncEvent_Disconnected._() : super._();

  String get reason;

  /// Create a copy of VncEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VncEvent_DisconnectedImplCopyWith<_$VncEvent_DisconnectedImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$VncEvent_ErrorImplCopyWith<$Res> {
  factory _$$VncEvent_ErrorImplCopyWith(
    _$VncEvent_ErrorImpl value,
    $Res Function(_$VncEvent_ErrorImpl) then,
  ) = __$$VncEvent_ErrorImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$$VncEvent_ErrorImplCopyWithImpl<$Res>
    extends _$VncEventCopyWithImpl<$Res, _$VncEvent_ErrorImpl>
    implements _$$VncEvent_ErrorImplCopyWith<$Res> {
  __$$VncEvent_ErrorImplCopyWithImpl(
    _$VncEvent_ErrorImpl _value,
    $Res Function(_$VncEvent_ErrorImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of VncEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? message = null}) {
    return _then(
      _$VncEvent_ErrorImpl(
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$VncEvent_ErrorImpl extends VncEvent_Error {
  const _$VncEvent_ErrorImpl({required this.message}) : super._();

  @override
  final String message;

  @override
  String toString() {
    return 'VncEvent.error(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VncEvent_ErrorImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of VncEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VncEvent_ErrorImplCopyWith<_$VncEvent_ErrorImpl> get copyWith =>
      __$$VncEvent_ErrorImplCopyWithImpl<_$VncEvent_ErrorImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int sessionId) started,
    required TResult Function(int width, int height) connected,
    required TResult Function(int width, int height) resize,
    required TResult Function(
      int x,
      int y,
      int width,
      int height,
      Uint8List rgba,
    )
    frameUpdate,
    required TResult Function(String text) clipboardText,
    required TResult Function() bell,
    required TResult Function(String reason) disconnected,
    required TResult Function(String message) error,
  }) {
    return error(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int sessionId)? started,
    TResult? Function(int width, int height)? connected,
    TResult? Function(int width, int height)? resize,
    TResult? Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult? Function(String text)? clipboardText,
    TResult? Function()? bell,
    TResult? Function(String reason)? disconnected,
    TResult? Function(String message)? error,
  }) {
    return error?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int sessionId)? started,
    TResult Function(int width, int height)? connected,
    TResult Function(int width, int height)? resize,
    TResult Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult Function(String text)? clipboardText,
    TResult Function()? bell,
    TResult Function(String reason)? disconnected,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(VncEvent_Started value) started,
    required TResult Function(VncEvent_Connected value) connected,
    required TResult Function(VncEvent_Resize value) resize,
    required TResult Function(VncEvent_FrameUpdate value) frameUpdate,
    required TResult Function(VncEvent_ClipboardText value) clipboardText,
    required TResult Function(VncEvent_Bell value) bell,
    required TResult Function(VncEvent_Disconnected value) disconnected,
    required TResult Function(VncEvent_Error value) error,
  }) {
    return error(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(VncEvent_Started value)? started,
    TResult? Function(VncEvent_Connected value)? connected,
    TResult? Function(VncEvent_Resize value)? resize,
    TResult? Function(VncEvent_FrameUpdate value)? frameUpdate,
    TResult? Function(VncEvent_ClipboardText value)? clipboardText,
    TResult? Function(VncEvent_Bell value)? bell,
    TResult? Function(VncEvent_Disconnected value)? disconnected,
    TResult? Function(VncEvent_Error value)? error,
  }) {
    return error?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(VncEvent_Started value)? started,
    TResult Function(VncEvent_Connected value)? connected,
    TResult Function(VncEvent_Resize value)? resize,
    TResult Function(VncEvent_FrameUpdate value)? frameUpdate,
    TResult Function(VncEvent_ClipboardText value)? clipboardText,
    TResult Function(VncEvent_Bell value)? bell,
    TResult Function(VncEvent_Disconnected value)? disconnected,
    TResult Function(VncEvent_Error value)? error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(this);
    }
    return orElse();
  }
}

abstract class VncEvent_Error extends VncEvent {
  const factory VncEvent_Error({required final String message}) =
      _$VncEvent_ErrorImpl;
  const VncEvent_Error._() : super._();

  String get message;

  /// Create a copy of VncEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VncEvent_ErrorImplCopyWith<_$VncEvent_ErrorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
