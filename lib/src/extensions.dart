extension ObjectExtensions<T extends Object> on T? {
  R? ifIs<R extends Object>() => switch (this) {
    final R value => value,
    _ => null,
  };
}
