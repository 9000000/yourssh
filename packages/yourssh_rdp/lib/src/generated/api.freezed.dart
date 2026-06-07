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
mixin _$RdpEvent {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int sessionId) started,
    required TResult Function(
      RdpCertInfo cert,
      int desktopWidth,
      int desktopHeight,
    )
    connected,
    required TResult Function(String fingerprint) certMismatch,
    required TResult Function(
      int x,
      int y,
      int width,
      int height,
      Uint8List rgba,
    )
    frameUpdate,
    required TResult Function(String text) clipboardText,
    required TResult Function(String reason) disconnected,
    required TResult Function(String message) error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int sessionId)? started,
    TResult? Function(RdpCertInfo cert, int desktopWidth, int desktopHeight)?
    connected,
    TResult? Function(String fingerprint)? certMismatch,
    TResult? Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult? Function(String text)? clipboardText,
    TResult? Function(String reason)? disconnected,
    TResult? Function(String message)? error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int sessionId)? started,
    TResult Function(RdpCertInfo cert, int desktopWidth, int desktopHeight)?
    connected,
    TResult Function(String fingerprint)? certMismatch,
    TResult Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult Function(String text)? clipboardText,
    TResult Function(String reason)? disconnected,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RdpEvent_Started value) started,
    required TResult Function(RdpEvent_Connected value) connected,
    required TResult Function(RdpEvent_CertMismatch value) certMismatch,
    required TResult Function(RdpEvent_FrameUpdate value) frameUpdate,
    required TResult Function(RdpEvent_ClipboardText value) clipboardText,
    required TResult Function(RdpEvent_Disconnected value) disconnected,
    required TResult Function(RdpEvent_Error value) error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RdpEvent_Started value)? started,
    TResult? Function(RdpEvent_Connected value)? connected,
    TResult? Function(RdpEvent_CertMismatch value)? certMismatch,
    TResult? Function(RdpEvent_FrameUpdate value)? frameUpdate,
    TResult? Function(RdpEvent_ClipboardText value)? clipboardText,
    TResult? Function(RdpEvent_Disconnected value)? disconnected,
    TResult? Function(RdpEvent_Error value)? error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RdpEvent_Started value)? started,
    TResult Function(RdpEvent_Connected value)? connected,
    TResult Function(RdpEvent_CertMismatch value)? certMismatch,
    TResult Function(RdpEvent_FrameUpdate value)? frameUpdate,
    TResult Function(RdpEvent_ClipboardText value)? clipboardText,
    TResult Function(RdpEvent_Disconnected value)? disconnected,
    TResult Function(RdpEvent_Error value)? error,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RdpEventCopyWith<$Res> {
  factory $RdpEventCopyWith(RdpEvent value, $Res Function(RdpEvent) then) =
      _$RdpEventCopyWithImpl<$Res, RdpEvent>;
}

/// @nodoc
class _$RdpEventCopyWithImpl<$Res, $Val extends RdpEvent>
    implements $RdpEventCopyWith<$Res> {
  _$RdpEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RdpEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$RdpEvent_StartedImplCopyWith<$Res> {
  factory _$$RdpEvent_StartedImplCopyWith(
    _$RdpEvent_StartedImpl value,
    $Res Function(_$RdpEvent_StartedImpl) then,
  ) = __$$RdpEvent_StartedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int sessionId});
}

/// @nodoc
class __$$RdpEvent_StartedImplCopyWithImpl<$Res>
    extends _$RdpEventCopyWithImpl<$Res, _$RdpEvent_StartedImpl>
    implements _$$RdpEvent_StartedImplCopyWith<$Res> {
  __$$RdpEvent_StartedImplCopyWithImpl(
    _$RdpEvent_StartedImpl _value,
    $Res Function(_$RdpEvent_StartedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RdpEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? sessionId = null}) {
    return _then(
      _$RdpEvent_StartedImpl(
        sessionId: null == sessionId
            ? _value.sessionId
            : sessionId // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$RdpEvent_StartedImpl extends RdpEvent_Started {
  const _$RdpEvent_StartedImpl({required this.sessionId}) : super._();

  @override
  final int sessionId;

  @override
  String toString() {
    return 'RdpEvent.started(sessionId: $sessionId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RdpEvent_StartedImpl &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId));
  }

  @override
  int get hashCode => Object.hash(runtimeType, sessionId);

  /// Create a copy of RdpEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RdpEvent_StartedImplCopyWith<_$RdpEvent_StartedImpl> get copyWith =>
      __$$RdpEvent_StartedImplCopyWithImpl<_$RdpEvent_StartedImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int sessionId) started,
    required TResult Function(
      RdpCertInfo cert,
      int desktopWidth,
      int desktopHeight,
    )
    connected,
    required TResult Function(String fingerprint) certMismatch,
    required TResult Function(
      int x,
      int y,
      int width,
      int height,
      Uint8List rgba,
    )
    frameUpdate,
    required TResult Function(String text) clipboardText,
    required TResult Function(String reason) disconnected,
    required TResult Function(String message) error,
  }) {
    return started(sessionId);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int sessionId)? started,
    TResult? Function(RdpCertInfo cert, int desktopWidth, int desktopHeight)?
    connected,
    TResult? Function(String fingerprint)? certMismatch,
    TResult? Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult? Function(String text)? clipboardText,
    TResult? Function(String reason)? disconnected,
    TResult? Function(String message)? error,
  }) {
    return started?.call(sessionId);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int sessionId)? started,
    TResult Function(RdpCertInfo cert, int desktopWidth, int desktopHeight)?
    connected,
    TResult Function(String fingerprint)? certMismatch,
    TResult Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult Function(String text)? clipboardText,
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
    required TResult Function(RdpEvent_Started value) started,
    required TResult Function(RdpEvent_Connected value) connected,
    required TResult Function(RdpEvent_CertMismatch value) certMismatch,
    required TResult Function(RdpEvent_FrameUpdate value) frameUpdate,
    required TResult Function(RdpEvent_ClipboardText value) clipboardText,
    required TResult Function(RdpEvent_Disconnected value) disconnected,
    required TResult Function(RdpEvent_Error value) error,
  }) {
    return started(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RdpEvent_Started value)? started,
    TResult? Function(RdpEvent_Connected value)? connected,
    TResult? Function(RdpEvent_CertMismatch value)? certMismatch,
    TResult? Function(RdpEvent_FrameUpdate value)? frameUpdate,
    TResult? Function(RdpEvent_ClipboardText value)? clipboardText,
    TResult? Function(RdpEvent_Disconnected value)? disconnected,
    TResult? Function(RdpEvent_Error value)? error,
  }) {
    return started?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RdpEvent_Started value)? started,
    TResult Function(RdpEvent_Connected value)? connected,
    TResult Function(RdpEvent_CertMismatch value)? certMismatch,
    TResult Function(RdpEvent_FrameUpdate value)? frameUpdate,
    TResult Function(RdpEvent_ClipboardText value)? clipboardText,
    TResult Function(RdpEvent_Disconnected value)? disconnected,
    TResult Function(RdpEvent_Error value)? error,
    required TResult orElse(),
  }) {
    if (started != null) {
      return started(this);
    }
    return orElse();
  }
}

abstract class RdpEvent_Started extends RdpEvent {
  const factory RdpEvent_Started({required final int sessionId}) =
      _$RdpEvent_StartedImpl;
  const RdpEvent_Started._() : super._();

  int get sessionId;

  /// Create a copy of RdpEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RdpEvent_StartedImplCopyWith<_$RdpEvent_StartedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RdpEvent_ConnectedImplCopyWith<$Res> {
  factory _$$RdpEvent_ConnectedImplCopyWith(
    _$RdpEvent_ConnectedImpl value,
    $Res Function(_$RdpEvent_ConnectedImpl) then,
  ) = __$$RdpEvent_ConnectedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({RdpCertInfo cert, int desktopWidth, int desktopHeight});
}

/// @nodoc
class __$$RdpEvent_ConnectedImplCopyWithImpl<$Res>
    extends _$RdpEventCopyWithImpl<$Res, _$RdpEvent_ConnectedImpl>
    implements _$$RdpEvent_ConnectedImplCopyWith<$Res> {
  __$$RdpEvent_ConnectedImplCopyWithImpl(
    _$RdpEvent_ConnectedImpl _value,
    $Res Function(_$RdpEvent_ConnectedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RdpEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? cert = null,
    Object? desktopWidth = null,
    Object? desktopHeight = null,
  }) {
    return _then(
      _$RdpEvent_ConnectedImpl(
        cert: null == cert
            ? _value.cert
            : cert // ignore: cast_nullable_to_non_nullable
                  as RdpCertInfo,
        desktopWidth: null == desktopWidth
            ? _value.desktopWidth
            : desktopWidth // ignore: cast_nullable_to_non_nullable
                  as int,
        desktopHeight: null == desktopHeight
            ? _value.desktopHeight
            : desktopHeight // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$RdpEvent_ConnectedImpl extends RdpEvent_Connected {
  const _$RdpEvent_ConnectedImpl({
    required this.cert,
    required this.desktopWidth,
    required this.desktopHeight,
  }) : super._();

  @override
  final RdpCertInfo cert;
  @override
  final int desktopWidth;
  @override
  final int desktopHeight;

  @override
  String toString() {
    return 'RdpEvent.connected(cert: $cert, desktopWidth: $desktopWidth, desktopHeight: $desktopHeight)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RdpEvent_ConnectedImpl &&
            (identical(other.cert, cert) || other.cert == cert) &&
            (identical(other.desktopWidth, desktopWidth) ||
                other.desktopWidth == desktopWidth) &&
            (identical(other.desktopHeight, desktopHeight) ||
                other.desktopHeight == desktopHeight));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, cert, desktopWidth, desktopHeight);

  /// Create a copy of RdpEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RdpEvent_ConnectedImplCopyWith<_$RdpEvent_ConnectedImpl> get copyWith =>
      __$$RdpEvent_ConnectedImplCopyWithImpl<_$RdpEvent_ConnectedImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int sessionId) started,
    required TResult Function(
      RdpCertInfo cert,
      int desktopWidth,
      int desktopHeight,
    )
    connected,
    required TResult Function(String fingerprint) certMismatch,
    required TResult Function(
      int x,
      int y,
      int width,
      int height,
      Uint8List rgba,
    )
    frameUpdate,
    required TResult Function(String text) clipboardText,
    required TResult Function(String reason) disconnected,
    required TResult Function(String message) error,
  }) {
    return connected(cert, desktopWidth, desktopHeight);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int sessionId)? started,
    TResult? Function(RdpCertInfo cert, int desktopWidth, int desktopHeight)?
    connected,
    TResult? Function(String fingerprint)? certMismatch,
    TResult? Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult? Function(String text)? clipboardText,
    TResult? Function(String reason)? disconnected,
    TResult? Function(String message)? error,
  }) {
    return connected?.call(cert, desktopWidth, desktopHeight);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int sessionId)? started,
    TResult Function(RdpCertInfo cert, int desktopWidth, int desktopHeight)?
    connected,
    TResult Function(String fingerprint)? certMismatch,
    TResult Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult Function(String text)? clipboardText,
    TResult Function(String reason)? disconnected,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (connected != null) {
      return connected(cert, desktopWidth, desktopHeight);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RdpEvent_Started value) started,
    required TResult Function(RdpEvent_Connected value) connected,
    required TResult Function(RdpEvent_CertMismatch value) certMismatch,
    required TResult Function(RdpEvent_FrameUpdate value) frameUpdate,
    required TResult Function(RdpEvent_ClipboardText value) clipboardText,
    required TResult Function(RdpEvent_Disconnected value) disconnected,
    required TResult Function(RdpEvent_Error value) error,
  }) {
    return connected(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RdpEvent_Started value)? started,
    TResult? Function(RdpEvent_Connected value)? connected,
    TResult? Function(RdpEvent_CertMismatch value)? certMismatch,
    TResult? Function(RdpEvent_FrameUpdate value)? frameUpdate,
    TResult? Function(RdpEvent_ClipboardText value)? clipboardText,
    TResult? Function(RdpEvent_Disconnected value)? disconnected,
    TResult? Function(RdpEvent_Error value)? error,
  }) {
    return connected?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RdpEvent_Started value)? started,
    TResult Function(RdpEvent_Connected value)? connected,
    TResult Function(RdpEvent_CertMismatch value)? certMismatch,
    TResult Function(RdpEvent_FrameUpdate value)? frameUpdate,
    TResult Function(RdpEvent_ClipboardText value)? clipboardText,
    TResult Function(RdpEvent_Disconnected value)? disconnected,
    TResult Function(RdpEvent_Error value)? error,
    required TResult orElse(),
  }) {
    if (connected != null) {
      return connected(this);
    }
    return orElse();
  }
}

abstract class RdpEvent_Connected extends RdpEvent {
  const factory RdpEvent_Connected({
    required final RdpCertInfo cert,
    required final int desktopWidth,
    required final int desktopHeight,
  }) = _$RdpEvent_ConnectedImpl;
  const RdpEvent_Connected._() : super._();

  RdpCertInfo get cert;
  int get desktopWidth;
  int get desktopHeight;

  /// Create a copy of RdpEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RdpEvent_ConnectedImplCopyWith<_$RdpEvent_ConnectedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RdpEvent_CertMismatchImplCopyWith<$Res> {
  factory _$$RdpEvent_CertMismatchImplCopyWith(
    _$RdpEvent_CertMismatchImpl value,
    $Res Function(_$RdpEvent_CertMismatchImpl) then,
  ) = __$$RdpEvent_CertMismatchImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String fingerprint});
}

/// @nodoc
class __$$RdpEvent_CertMismatchImplCopyWithImpl<$Res>
    extends _$RdpEventCopyWithImpl<$Res, _$RdpEvent_CertMismatchImpl>
    implements _$$RdpEvent_CertMismatchImplCopyWith<$Res> {
  __$$RdpEvent_CertMismatchImplCopyWithImpl(
    _$RdpEvent_CertMismatchImpl _value,
    $Res Function(_$RdpEvent_CertMismatchImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RdpEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? fingerprint = null}) {
    return _then(
      _$RdpEvent_CertMismatchImpl(
        fingerprint: null == fingerprint
            ? _value.fingerprint
            : fingerprint // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$RdpEvent_CertMismatchImpl extends RdpEvent_CertMismatch {
  const _$RdpEvent_CertMismatchImpl({required this.fingerprint}) : super._();

  @override
  final String fingerprint;

  @override
  String toString() {
    return 'RdpEvent.certMismatch(fingerprint: $fingerprint)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RdpEvent_CertMismatchImpl &&
            (identical(other.fingerprint, fingerprint) ||
                other.fingerprint == fingerprint));
  }

  @override
  int get hashCode => Object.hash(runtimeType, fingerprint);

  /// Create a copy of RdpEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RdpEvent_CertMismatchImplCopyWith<_$RdpEvent_CertMismatchImpl>
  get copyWith =>
      __$$RdpEvent_CertMismatchImplCopyWithImpl<_$RdpEvent_CertMismatchImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int sessionId) started,
    required TResult Function(
      RdpCertInfo cert,
      int desktopWidth,
      int desktopHeight,
    )
    connected,
    required TResult Function(String fingerprint) certMismatch,
    required TResult Function(
      int x,
      int y,
      int width,
      int height,
      Uint8List rgba,
    )
    frameUpdate,
    required TResult Function(String text) clipboardText,
    required TResult Function(String reason) disconnected,
    required TResult Function(String message) error,
  }) {
    return certMismatch(fingerprint);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int sessionId)? started,
    TResult? Function(RdpCertInfo cert, int desktopWidth, int desktopHeight)?
    connected,
    TResult? Function(String fingerprint)? certMismatch,
    TResult? Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult? Function(String text)? clipboardText,
    TResult? Function(String reason)? disconnected,
    TResult? Function(String message)? error,
  }) {
    return certMismatch?.call(fingerprint);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int sessionId)? started,
    TResult Function(RdpCertInfo cert, int desktopWidth, int desktopHeight)?
    connected,
    TResult Function(String fingerprint)? certMismatch,
    TResult Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult Function(String text)? clipboardText,
    TResult Function(String reason)? disconnected,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (certMismatch != null) {
      return certMismatch(fingerprint);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RdpEvent_Started value) started,
    required TResult Function(RdpEvent_Connected value) connected,
    required TResult Function(RdpEvent_CertMismatch value) certMismatch,
    required TResult Function(RdpEvent_FrameUpdate value) frameUpdate,
    required TResult Function(RdpEvent_ClipboardText value) clipboardText,
    required TResult Function(RdpEvent_Disconnected value) disconnected,
    required TResult Function(RdpEvent_Error value) error,
  }) {
    return certMismatch(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RdpEvent_Started value)? started,
    TResult? Function(RdpEvent_Connected value)? connected,
    TResult? Function(RdpEvent_CertMismatch value)? certMismatch,
    TResult? Function(RdpEvent_FrameUpdate value)? frameUpdate,
    TResult? Function(RdpEvent_ClipboardText value)? clipboardText,
    TResult? Function(RdpEvent_Disconnected value)? disconnected,
    TResult? Function(RdpEvent_Error value)? error,
  }) {
    return certMismatch?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RdpEvent_Started value)? started,
    TResult Function(RdpEvent_Connected value)? connected,
    TResult Function(RdpEvent_CertMismatch value)? certMismatch,
    TResult Function(RdpEvent_FrameUpdate value)? frameUpdate,
    TResult Function(RdpEvent_ClipboardText value)? clipboardText,
    TResult Function(RdpEvent_Disconnected value)? disconnected,
    TResult Function(RdpEvent_Error value)? error,
    required TResult orElse(),
  }) {
    if (certMismatch != null) {
      return certMismatch(this);
    }
    return orElse();
  }
}

abstract class RdpEvent_CertMismatch extends RdpEvent {
  const factory RdpEvent_CertMismatch({required final String fingerprint}) =
      _$RdpEvent_CertMismatchImpl;
  const RdpEvent_CertMismatch._() : super._();

  String get fingerprint;

  /// Create a copy of RdpEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RdpEvent_CertMismatchImplCopyWith<_$RdpEvent_CertMismatchImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RdpEvent_FrameUpdateImplCopyWith<$Res> {
  factory _$$RdpEvent_FrameUpdateImplCopyWith(
    _$RdpEvent_FrameUpdateImpl value,
    $Res Function(_$RdpEvent_FrameUpdateImpl) then,
  ) = __$$RdpEvent_FrameUpdateImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int x, int y, int width, int height, Uint8List rgba});
}

/// @nodoc
class __$$RdpEvent_FrameUpdateImplCopyWithImpl<$Res>
    extends _$RdpEventCopyWithImpl<$Res, _$RdpEvent_FrameUpdateImpl>
    implements _$$RdpEvent_FrameUpdateImplCopyWith<$Res> {
  __$$RdpEvent_FrameUpdateImplCopyWithImpl(
    _$RdpEvent_FrameUpdateImpl _value,
    $Res Function(_$RdpEvent_FrameUpdateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RdpEvent
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
      _$RdpEvent_FrameUpdateImpl(
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

class _$RdpEvent_FrameUpdateImpl extends RdpEvent_FrameUpdate {
  const _$RdpEvent_FrameUpdateImpl({
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
    return 'RdpEvent.frameUpdate(x: $x, y: $y, width: $width, height: $height, rgba: $rgba)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RdpEvent_FrameUpdateImpl &&
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

  /// Create a copy of RdpEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RdpEvent_FrameUpdateImplCopyWith<_$RdpEvent_FrameUpdateImpl>
  get copyWith =>
      __$$RdpEvent_FrameUpdateImplCopyWithImpl<_$RdpEvent_FrameUpdateImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int sessionId) started,
    required TResult Function(
      RdpCertInfo cert,
      int desktopWidth,
      int desktopHeight,
    )
    connected,
    required TResult Function(String fingerprint) certMismatch,
    required TResult Function(
      int x,
      int y,
      int width,
      int height,
      Uint8List rgba,
    )
    frameUpdate,
    required TResult Function(String text) clipboardText,
    required TResult Function(String reason) disconnected,
    required TResult Function(String message) error,
  }) {
    return frameUpdate(x, y, width, height, rgba);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int sessionId)? started,
    TResult? Function(RdpCertInfo cert, int desktopWidth, int desktopHeight)?
    connected,
    TResult? Function(String fingerprint)? certMismatch,
    TResult? Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult? Function(String text)? clipboardText,
    TResult? Function(String reason)? disconnected,
    TResult? Function(String message)? error,
  }) {
    return frameUpdate?.call(x, y, width, height, rgba);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int sessionId)? started,
    TResult Function(RdpCertInfo cert, int desktopWidth, int desktopHeight)?
    connected,
    TResult Function(String fingerprint)? certMismatch,
    TResult Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult Function(String text)? clipboardText,
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
    required TResult Function(RdpEvent_Started value) started,
    required TResult Function(RdpEvent_Connected value) connected,
    required TResult Function(RdpEvent_CertMismatch value) certMismatch,
    required TResult Function(RdpEvent_FrameUpdate value) frameUpdate,
    required TResult Function(RdpEvent_ClipboardText value) clipboardText,
    required TResult Function(RdpEvent_Disconnected value) disconnected,
    required TResult Function(RdpEvent_Error value) error,
  }) {
    return frameUpdate(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RdpEvent_Started value)? started,
    TResult? Function(RdpEvent_Connected value)? connected,
    TResult? Function(RdpEvent_CertMismatch value)? certMismatch,
    TResult? Function(RdpEvent_FrameUpdate value)? frameUpdate,
    TResult? Function(RdpEvent_ClipboardText value)? clipboardText,
    TResult? Function(RdpEvent_Disconnected value)? disconnected,
    TResult? Function(RdpEvent_Error value)? error,
  }) {
    return frameUpdate?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RdpEvent_Started value)? started,
    TResult Function(RdpEvent_Connected value)? connected,
    TResult Function(RdpEvent_CertMismatch value)? certMismatch,
    TResult Function(RdpEvent_FrameUpdate value)? frameUpdate,
    TResult Function(RdpEvent_ClipboardText value)? clipboardText,
    TResult Function(RdpEvent_Disconnected value)? disconnected,
    TResult Function(RdpEvent_Error value)? error,
    required TResult orElse(),
  }) {
    if (frameUpdate != null) {
      return frameUpdate(this);
    }
    return orElse();
  }
}

abstract class RdpEvent_FrameUpdate extends RdpEvent {
  const factory RdpEvent_FrameUpdate({
    required final int x,
    required final int y,
    required final int width,
    required final int height,
    required final Uint8List rgba,
  }) = _$RdpEvent_FrameUpdateImpl;
  const RdpEvent_FrameUpdate._() : super._();

  int get x;
  int get y;
  int get width;
  int get height;
  Uint8List get rgba;

  /// Create a copy of RdpEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RdpEvent_FrameUpdateImplCopyWith<_$RdpEvent_FrameUpdateImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RdpEvent_ClipboardTextImplCopyWith<$Res> {
  factory _$$RdpEvent_ClipboardTextImplCopyWith(
    _$RdpEvent_ClipboardTextImpl value,
    $Res Function(_$RdpEvent_ClipboardTextImpl) then,
  ) = __$$RdpEvent_ClipboardTextImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String text});
}

/// @nodoc
class __$$RdpEvent_ClipboardTextImplCopyWithImpl<$Res>
    extends _$RdpEventCopyWithImpl<$Res, _$RdpEvent_ClipboardTextImpl>
    implements _$$RdpEvent_ClipboardTextImplCopyWith<$Res> {
  __$$RdpEvent_ClipboardTextImplCopyWithImpl(
    _$RdpEvent_ClipboardTextImpl _value,
    $Res Function(_$RdpEvent_ClipboardTextImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RdpEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? text = null}) {
    return _then(
      _$RdpEvent_ClipboardTextImpl(
        text: null == text
            ? _value.text
            : text // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$RdpEvent_ClipboardTextImpl extends RdpEvent_ClipboardText {
  const _$RdpEvent_ClipboardTextImpl({required this.text}) : super._();

  @override
  final String text;

  @override
  String toString() {
    return 'RdpEvent.clipboardText(text: $text)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RdpEvent_ClipboardTextImpl &&
            (identical(other.text, text) || other.text == text));
  }

  @override
  int get hashCode => Object.hash(runtimeType, text);

  /// Create a copy of RdpEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RdpEvent_ClipboardTextImplCopyWith<_$RdpEvent_ClipboardTextImpl>
  get copyWith =>
      __$$RdpEvent_ClipboardTextImplCopyWithImpl<_$RdpEvent_ClipboardTextImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int sessionId) started,
    required TResult Function(
      RdpCertInfo cert,
      int desktopWidth,
      int desktopHeight,
    )
    connected,
    required TResult Function(String fingerprint) certMismatch,
    required TResult Function(
      int x,
      int y,
      int width,
      int height,
      Uint8List rgba,
    )
    frameUpdate,
    required TResult Function(String text) clipboardText,
    required TResult Function(String reason) disconnected,
    required TResult Function(String message) error,
  }) {
    return clipboardText(text);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int sessionId)? started,
    TResult? Function(RdpCertInfo cert, int desktopWidth, int desktopHeight)?
    connected,
    TResult? Function(String fingerprint)? certMismatch,
    TResult? Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult? Function(String text)? clipboardText,
    TResult? Function(String reason)? disconnected,
    TResult? Function(String message)? error,
  }) {
    return clipboardText?.call(text);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int sessionId)? started,
    TResult Function(RdpCertInfo cert, int desktopWidth, int desktopHeight)?
    connected,
    TResult Function(String fingerprint)? certMismatch,
    TResult Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult Function(String text)? clipboardText,
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
    required TResult Function(RdpEvent_Started value) started,
    required TResult Function(RdpEvent_Connected value) connected,
    required TResult Function(RdpEvent_CertMismatch value) certMismatch,
    required TResult Function(RdpEvent_FrameUpdate value) frameUpdate,
    required TResult Function(RdpEvent_ClipboardText value) clipboardText,
    required TResult Function(RdpEvent_Disconnected value) disconnected,
    required TResult Function(RdpEvent_Error value) error,
  }) {
    return clipboardText(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RdpEvent_Started value)? started,
    TResult? Function(RdpEvent_Connected value)? connected,
    TResult? Function(RdpEvent_CertMismatch value)? certMismatch,
    TResult? Function(RdpEvent_FrameUpdate value)? frameUpdate,
    TResult? Function(RdpEvent_ClipboardText value)? clipboardText,
    TResult? Function(RdpEvent_Disconnected value)? disconnected,
    TResult? Function(RdpEvent_Error value)? error,
  }) {
    return clipboardText?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RdpEvent_Started value)? started,
    TResult Function(RdpEvent_Connected value)? connected,
    TResult Function(RdpEvent_CertMismatch value)? certMismatch,
    TResult Function(RdpEvent_FrameUpdate value)? frameUpdate,
    TResult Function(RdpEvent_ClipboardText value)? clipboardText,
    TResult Function(RdpEvent_Disconnected value)? disconnected,
    TResult Function(RdpEvent_Error value)? error,
    required TResult orElse(),
  }) {
    if (clipboardText != null) {
      return clipboardText(this);
    }
    return orElse();
  }
}

abstract class RdpEvent_ClipboardText extends RdpEvent {
  const factory RdpEvent_ClipboardText({required final String text}) =
      _$RdpEvent_ClipboardTextImpl;
  const RdpEvent_ClipboardText._() : super._();

  String get text;

  /// Create a copy of RdpEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RdpEvent_ClipboardTextImplCopyWith<_$RdpEvent_ClipboardTextImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RdpEvent_DisconnectedImplCopyWith<$Res> {
  factory _$$RdpEvent_DisconnectedImplCopyWith(
    _$RdpEvent_DisconnectedImpl value,
    $Res Function(_$RdpEvent_DisconnectedImpl) then,
  ) = __$$RdpEvent_DisconnectedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String reason});
}

/// @nodoc
class __$$RdpEvent_DisconnectedImplCopyWithImpl<$Res>
    extends _$RdpEventCopyWithImpl<$Res, _$RdpEvent_DisconnectedImpl>
    implements _$$RdpEvent_DisconnectedImplCopyWith<$Res> {
  __$$RdpEvent_DisconnectedImplCopyWithImpl(
    _$RdpEvent_DisconnectedImpl _value,
    $Res Function(_$RdpEvent_DisconnectedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RdpEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? reason = null}) {
    return _then(
      _$RdpEvent_DisconnectedImpl(
        reason: null == reason
            ? _value.reason
            : reason // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$RdpEvent_DisconnectedImpl extends RdpEvent_Disconnected {
  const _$RdpEvent_DisconnectedImpl({required this.reason}) : super._();

  @override
  final String reason;

  @override
  String toString() {
    return 'RdpEvent.disconnected(reason: $reason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RdpEvent_DisconnectedImpl &&
            (identical(other.reason, reason) || other.reason == reason));
  }

  @override
  int get hashCode => Object.hash(runtimeType, reason);

  /// Create a copy of RdpEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RdpEvent_DisconnectedImplCopyWith<_$RdpEvent_DisconnectedImpl>
  get copyWith =>
      __$$RdpEvent_DisconnectedImplCopyWithImpl<_$RdpEvent_DisconnectedImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int sessionId) started,
    required TResult Function(
      RdpCertInfo cert,
      int desktopWidth,
      int desktopHeight,
    )
    connected,
    required TResult Function(String fingerprint) certMismatch,
    required TResult Function(
      int x,
      int y,
      int width,
      int height,
      Uint8List rgba,
    )
    frameUpdate,
    required TResult Function(String text) clipboardText,
    required TResult Function(String reason) disconnected,
    required TResult Function(String message) error,
  }) {
    return disconnected(reason);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int sessionId)? started,
    TResult? Function(RdpCertInfo cert, int desktopWidth, int desktopHeight)?
    connected,
    TResult? Function(String fingerprint)? certMismatch,
    TResult? Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult? Function(String text)? clipboardText,
    TResult? Function(String reason)? disconnected,
    TResult? Function(String message)? error,
  }) {
    return disconnected?.call(reason);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int sessionId)? started,
    TResult Function(RdpCertInfo cert, int desktopWidth, int desktopHeight)?
    connected,
    TResult Function(String fingerprint)? certMismatch,
    TResult Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult Function(String text)? clipboardText,
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
    required TResult Function(RdpEvent_Started value) started,
    required TResult Function(RdpEvent_Connected value) connected,
    required TResult Function(RdpEvent_CertMismatch value) certMismatch,
    required TResult Function(RdpEvent_FrameUpdate value) frameUpdate,
    required TResult Function(RdpEvent_ClipboardText value) clipboardText,
    required TResult Function(RdpEvent_Disconnected value) disconnected,
    required TResult Function(RdpEvent_Error value) error,
  }) {
    return disconnected(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RdpEvent_Started value)? started,
    TResult? Function(RdpEvent_Connected value)? connected,
    TResult? Function(RdpEvent_CertMismatch value)? certMismatch,
    TResult? Function(RdpEvent_FrameUpdate value)? frameUpdate,
    TResult? Function(RdpEvent_ClipboardText value)? clipboardText,
    TResult? Function(RdpEvent_Disconnected value)? disconnected,
    TResult? Function(RdpEvent_Error value)? error,
  }) {
    return disconnected?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RdpEvent_Started value)? started,
    TResult Function(RdpEvent_Connected value)? connected,
    TResult Function(RdpEvent_CertMismatch value)? certMismatch,
    TResult Function(RdpEvent_FrameUpdate value)? frameUpdate,
    TResult Function(RdpEvent_ClipboardText value)? clipboardText,
    TResult Function(RdpEvent_Disconnected value)? disconnected,
    TResult Function(RdpEvent_Error value)? error,
    required TResult orElse(),
  }) {
    if (disconnected != null) {
      return disconnected(this);
    }
    return orElse();
  }
}

abstract class RdpEvent_Disconnected extends RdpEvent {
  const factory RdpEvent_Disconnected({required final String reason}) =
      _$RdpEvent_DisconnectedImpl;
  const RdpEvent_Disconnected._() : super._();

  String get reason;

  /// Create a copy of RdpEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RdpEvent_DisconnectedImplCopyWith<_$RdpEvent_DisconnectedImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RdpEvent_ErrorImplCopyWith<$Res> {
  factory _$$RdpEvent_ErrorImplCopyWith(
    _$RdpEvent_ErrorImpl value,
    $Res Function(_$RdpEvent_ErrorImpl) then,
  ) = __$$RdpEvent_ErrorImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$$RdpEvent_ErrorImplCopyWithImpl<$Res>
    extends _$RdpEventCopyWithImpl<$Res, _$RdpEvent_ErrorImpl>
    implements _$$RdpEvent_ErrorImplCopyWith<$Res> {
  __$$RdpEvent_ErrorImplCopyWithImpl(
    _$RdpEvent_ErrorImpl _value,
    $Res Function(_$RdpEvent_ErrorImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RdpEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? message = null}) {
    return _then(
      _$RdpEvent_ErrorImpl(
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$RdpEvent_ErrorImpl extends RdpEvent_Error {
  const _$RdpEvent_ErrorImpl({required this.message}) : super._();

  @override
  final String message;

  @override
  String toString() {
    return 'RdpEvent.error(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RdpEvent_ErrorImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of RdpEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RdpEvent_ErrorImplCopyWith<_$RdpEvent_ErrorImpl> get copyWith =>
      __$$RdpEvent_ErrorImplCopyWithImpl<_$RdpEvent_ErrorImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int sessionId) started,
    required TResult Function(
      RdpCertInfo cert,
      int desktopWidth,
      int desktopHeight,
    )
    connected,
    required TResult Function(String fingerprint) certMismatch,
    required TResult Function(
      int x,
      int y,
      int width,
      int height,
      Uint8List rgba,
    )
    frameUpdate,
    required TResult Function(String text) clipboardText,
    required TResult Function(String reason) disconnected,
    required TResult Function(String message) error,
  }) {
    return error(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int sessionId)? started,
    TResult? Function(RdpCertInfo cert, int desktopWidth, int desktopHeight)?
    connected,
    TResult? Function(String fingerprint)? certMismatch,
    TResult? Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult? Function(String text)? clipboardText,
    TResult? Function(String reason)? disconnected,
    TResult? Function(String message)? error,
  }) {
    return error?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int sessionId)? started,
    TResult Function(RdpCertInfo cert, int desktopWidth, int desktopHeight)?
    connected,
    TResult Function(String fingerprint)? certMismatch,
    TResult Function(int x, int y, int width, int height, Uint8List rgba)?
    frameUpdate,
    TResult Function(String text)? clipboardText,
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
    required TResult Function(RdpEvent_Started value) started,
    required TResult Function(RdpEvent_Connected value) connected,
    required TResult Function(RdpEvent_CertMismatch value) certMismatch,
    required TResult Function(RdpEvent_FrameUpdate value) frameUpdate,
    required TResult Function(RdpEvent_ClipboardText value) clipboardText,
    required TResult Function(RdpEvent_Disconnected value) disconnected,
    required TResult Function(RdpEvent_Error value) error,
  }) {
    return error(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RdpEvent_Started value)? started,
    TResult? Function(RdpEvent_Connected value)? connected,
    TResult? Function(RdpEvent_CertMismatch value)? certMismatch,
    TResult? Function(RdpEvent_FrameUpdate value)? frameUpdate,
    TResult? Function(RdpEvent_ClipboardText value)? clipboardText,
    TResult? Function(RdpEvent_Disconnected value)? disconnected,
    TResult? Function(RdpEvent_Error value)? error,
  }) {
    return error?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RdpEvent_Started value)? started,
    TResult Function(RdpEvent_Connected value)? connected,
    TResult Function(RdpEvent_CertMismatch value)? certMismatch,
    TResult Function(RdpEvent_FrameUpdate value)? frameUpdate,
    TResult Function(RdpEvent_ClipboardText value)? clipboardText,
    TResult Function(RdpEvent_Disconnected value)? disconnected,
    TResult Function(RdpEvent_Error value)? error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(this);
    }
    return orElse();
  }
}

abstract class RdpEvent_Error extends RdpEvent {
  const factory RdpEvent_Error({required final String message}) =
      _$RdpEvent_ErrorImpl;
  const RdpEvent_Error._() : super._();

  String get message;

  /// Create a copy of RdpEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RdpEvent_ErrorImplCopyWith<_$RdpEvent_ErrorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
