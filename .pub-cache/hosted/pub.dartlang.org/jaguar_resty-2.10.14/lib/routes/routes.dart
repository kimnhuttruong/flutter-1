import 'dart:async';
import 'package:http/http.dart' as ht;
import 'dart:convert' as codec;
import 'package:jaguar_resty/expect/expect.dart';
import 'package:jaguar_resty/response/response.dart';
import 'package:http_parser/http_parser.dart';
import 'package:client_cookie/client_cookie.dart';
import 'package:auth_header/auth_header.dart';

typedef FutureOr<void> Before(RouteBase route);

Route route(String url) => Route(url);

Get get(String url) => Get(url);

Patch patch(String url) => Patch(url);

Post post(String url) => Post(url);

Put put(String url) => Put(url);

Delete delete(String url) => Delete(url);

OptionsMethod options(String url) => OptionsMethod(url);

ht.BaseClient globalClient;

class RouteBase {
  final metadataMap = <String, dynamic>{};

  final _paths = <String>[];

  final _pathParams = <String, String>{};

  String _origin;

  final getQuery = <String,
      dynamic /* String | Iterable<String | dynamic | Iterable<dynamic> */ >{};

  final getHeaders = <String, String>{};

  final getAuthHeaders = <String, String>{};

  final getCookies = <ClientCookie>[];

  final getBefore = <Before>[];
  final getAfter = <After>[];

  ht.BaseClient getClient;

  RouteBase();

  /// Set the [client] used to make HTTP requests
  RouteBase withClient(ht.BaseClient client) {
    getClient = client;
    return this;
  }

  RouteBase http(String origin, [String path]) {
    _origin = 'http://${origin}';
    if (path != null) this.path(path);
    return this;
  }

  RouteBase https(String origin, [String path]) {
    _origin = 'https://${origin}';
    if (path != null) this.path(path);
    return this;
  }

  /// Set origin of the URL
  RouteBase origin(String origin, [String path]) {
    _origin = origin;
    if (path != null) this.path(path);
    return this;
  }

  /// Append path segments to the URL
  RouteBase path(String path) {
    if (path.isEmpty) return this;
    final parts = path.split('/').where((p) => p.isNotEmpty);
    _paths.addAll(parts);
    return this;
  }

  RouteBase pathParams(String name, dynamic value) {
    if (value != null) _pathParams[name] = value?.toString();
    return this;
  }

  /// Add query parameters
  RouteBase query(String key, value) {
    if (value is String || value is Iterable<String>) {
      getQuery[key] = value;
    } else if (value is Iterable) {
      getQuery[key] = value.map((v) => v?.toString() ?? '');
    } else if (value != null) {
      getQuery[key] = value?.toString();
    }
    return this;
  }

  /// Add query parameters
  RouteBase queries(Map<String, dynamic> value) {
    value.forEach(query);
    return this;
  }

  /// Add headers
  RouteBase header(String key, String value) {
    getHeaders[key.toLowerCase()] = value;
    return this;
  }

  /// Add headers
  RouteBase headers(Map<String, String> values) {
    getHeaders.addAll(values.map((k, v) => MapEntry(k.toLowerCase(), v)));
    return this;
  }

  RouteBase mimeType(String mimeType) {
    final mt = MediaType.parse(getHeaders['content-type'] ?? 'text/plain');
    header('content-type', mt.change(mimeType: mimeType).toString());
    return this;
  }

  RouteBase charset(String charset) {
    final mt = MediaType.parse(getHeaders['content-type'] ?? 'text/plain');
    header(
        'content-type', mt.change(parameters: {'charset': charset}).toString());
    return this;
  }

  RouteBase contentType(String mimeType, String charset) {
    final mt = MediaType.parse(getHeaders['content-type'] ?? 'text/plain');
    header(
        'content-type',
        mt.change(
            mimeType: mimeType, parameters: {'charset': charset}).toString());
    return this;
  }

  RouteBase authHeader(String scheme, String credentials) {
    getAuthHeaders[scheme] = credentials;
    return this;
  }

  RouteBase authToken(String credentials) {
    getAuthHeaders['Bearer'] = credentials;
    return this;
  }

  RouteBase basicAuth(String username, String password) {
    getAuthHeaders['Basic'] = const codec.Base64Codec.urlSafe()
        .encode('${username}:${password}'.codeUnits);
    return this;
  }

  RouteBase cookie(ClientCookie cookie) {
    getCookies.add(cookie);
    return this;
  }

  RouteBase cookies(List<ClientCookie> cookie) {
    getCookies.addAll(cookie);
    return this;
  }

  RouteBase before(Before interceptor) {
    getBefore.add(interceptor);
    return this;
  }

  RouteBase after(After interceptor) {
    getAfter.add(interceptor);
    return this;
  }

  RouteBase metadata(Map<String, dynamic> value) {
    metadataMap.addAll(value);
    return this;
  }

  RouteBase hookHeader(String key, ValueCallback<String> getter) {
    if (getter != null) getAfter.add((r) => getter(r.headers[key]));
    return this;
  }

  RouteBase url(String value) {
    final purl = Uri.parse(value);
    if (purl.hasAuthority) origin(purl.origin);
    path(purl.pathSegments.join('/'));
    queries(purl.queryParametersAll);
    return this;
  }

  /// URL
  String get getUrl {
    String path = _paths
        .map((ps) => ps.startsWith(':') ? _pathParams[ps.substring(1)] : ps)
        .join('/');

    path = Uri.encodeFull(path);

    if (_origin == null && getQuery == null) return path;

    final sb = StringBuffer();
    if (_origin != null) sb.write(_origin);
    if (_origin == null || !_origin.endsWith('/')) sb.write('/');
    sb.write(path);
    if (getQuery == null) return sb.toString();
    _makeQueryParams(sb, getQuery);
    return sb.toString();
  }

  static void _makeQueryParams(StringBuffer sb, Map<String, dynamic> query) {
    if (query.length == 0) return;
    sb.write('?');

    void writeQuery(String key, String value, [bool isFirst = false]) {
      if (!isFirst) sb.write('&');
      sb.write(Uri.encodeQueryComponent(key));
      if (value != null && value.isNotEmpty) {
        sb.write("=");
        sb.write(Uri.encodeQueryComponent(value));
      }
    }

    void writeQueries(String key, value, [bool isFirst = false]) {
      if (value is Iterable) {
        for (int i = 0; i < value.length; i++) {
          if (i == 0) {
            writeQuery(key, value.elementAt(i)?.toString() ?? '', isFirst);
          } else {
            writeQuery(key, value.elementAt(i)?.toString() ?? '', false);
          }
        }
        return;
      }
      writeQuery(key, value?.toString() ?? '', isFirst);
    }

    for (int i = 0; i < query.length; i++) {
      String key = query.keys.elementAt(i);
      if (i == 0) {
        writeQueries(key, query[key], true);
      } else {
        writeQueries(key, query[key], false);
      }
    }
  }
}

/// Build fluent REST APIs routes
///
/// Example:
///     route('/book')
///       .query('count', '10')
///       .get.fetchList((m) => Book.fromMap(m));
class Route extends RouteBase {
  /// Construct [Route] object with [path]
  Route(String url) {
    this.url(url);
  }

  /// Converts to [Get] requester
  Get get get => Get.copy(this);

  /// Converts to [Post] requester
  Post get post => Post.copy(this);

  /// Converts to [Put] requester
  Put get put => Put.copy(this);

  /// Converts to [Patch] requester
  Patch get patch => Patch.copy(this);

  /// Converts to [Delete] requester
  Delete get delete => Delete.copy(this);

  OptionsMethod get options => OptionsMethod.copy(this);
}

void _prepare(RouteBase route) {
  if (route.getCookies.length != 0)
    route.getHeaders['Cookie'] = ClientCookie.toSetCookie(route.getCookies);
  if (route.getAuthHeaders.isNotEmpty) {
    final auth = AuthHeaders.fromHeaderStr(route.getHeaders['authorization']);
    for (String scheme in route.getAuthHeaders.keys) {
      auth.addItem(AuthHeaderItem(scheme, route.getAuthHeaders[scheme]));
    }
    route.getHeaders['authorization'] = auth.toString();
  }
}

abstract class RouteFetch {
  /// Issues the request and returns the response
  AsyncStringResponse go(
      {ResponseHook<String> onSuccess,
      ResponseHook<String> onFailure,
      ResponseHook<String> then,
      bool throwOnErr});

  /// Fetches json response and returns the decoded result
  Future<T> one<T>(
      {T convert(Map d),
      FutureOr<dynamic> onError(StringResponse resp)}) async {
    StringResponse resp = await go();
    if (resp.statusCode >= 200 && resp.statusCode < 300)
      return resp.decodeJson<T>(convert);

    if (onError == null) throw ErrorResponse(resp);
    var err = await onError(resp);
    if (err != null) throw err;
    return null;
  }

  /// Fetches json response and returns the decoded result
  Future<List<T>> list<T>(
      {T convert(Map d),
      FutureOr<dynamic> onError(StringResponse resp)}) async {
    StringResponse resp = await go();
    if (resp.statusCode >= 200 && resp.statusCode < 300)
      return resp.decodeJsonList<T>(convert);
    if (onError == null) throw ErrorResponse(resp);
    var err = await onError(resp);
    if (err != null) throw err;
    return null;
  }
}

/// Build fluent REST GET APIs
///
/// Example:
///     get('/book')
///       .query('count', '10')
///       .fetchList((m) => Book.fromMap(m));
class Get extends RouteBase with RouteFetch {
  Get(String url) {
    this.url(url);
  }

  Get.copy(Route route) {
    _origin = route._origin;
    _paths.addAll(route._paths);
    _pathParams.addAll(route._pathParams);
    getQuery.addAll(route.getQuery);
    getHeaders.addAll(route.getHeaders);
    getAuthHeaders.addAll(route.getAuthHeaders);
    getCookies.addAll(route.getCookies);
    metadataMap.addAll(route.metadataMap);
    getClient = route.getClient;
    getBefore.addAll(route.getBefore);
    getAfter.addAll(route.getAfter);
  }

  Get.clone(Get route) {
    _origin = route._origin;
    _paths.addAll(route._paths);
    _pathParams.addAll(route._pathParams);
    getQuery.addAll(route.getQuery);
    getHeaders.addAll(route.getHeaders);
    getAuthHeaders.addAll(route.getAuthHeaders);
    getCookies.addAll(route.getCookies);
    metadataMap.addAll(route.metadataMap);
    getClient = route.getClient;
    getBefore.addAll(route.getBefore);
    getAfter.addAll(route.getAfter);
  }

  Get withClient(ht.BaseClient client) => super.withClient(client);

  Get http(String origin, [String path]) => super.http(origin, path);

  Get https(String origin, [String path]) => super.https(origin, path);

  Get origin(String origin, [String path]) => super.origin(origin, path);

  Get path(String path) => super.path(path);

  Get pathParams(String name, dynamic value) => super.pathParams(name, value);

  Get query(String key, value) => super.query(key, value);

  Get metadata(Map<String, dynamic> metaData) => super.metadata(metaData);

  Get hookHeader(String key, ValueCallback<String> getter) =>
      super.hookHeader(key, getter);

  Get queries(Map<String, dynamic> value) => super.queries(value);

  Get header(String key, String value) => super.header(key, value);

  Get headers(Map<String, String> values) => super.headers(values);

  Get mimeType(String mimeType) => super.mimeType(mimeType);

  Get charset(String charset) => super.charset(charset);

  Get contentType(String mimeType, String charset) =>
      super.contentType(mimeType, charset);

  Get authHeader(String scheme, String credentials) =>
      super.authHeader(scheme, credentials);

  Get authToken(String credentials) => super.authToken(credentials);

  Get basicAuth(String username, String password) =>
      super.basicAuth(username, password);

  Get cookie(ClientCookie cookie) => super.cookie(cookie);

  Get cookies(List<ClientCookie> cookies) => super.cookies(cookies);

  Get before(Before interceptor) => super.before(interceptor);

  Get after(After interceptor) => super.after(interceptor);

  Get url(String url) => super.url(url);

  Future<ht.Response> _send() async {
    for (Before mod in getBefore) await mod(this);
    _prepare(this);
    return (getClient ?? globalClient).get(getUrl, headers: getHeaders);
  }

  AsyncStringResponse go(
      {ResponseHook<String> onSuccess,
      ResponseHook<String> onFailure,
      ResponseHook<String> then,
      bool throwOnErr}) {
    Get cloned = Get.clone(this);
    AsyncStringResponse resp = AsyncStringResponse(
        AsyncStringResponse.from(cloned._send(), sender: this, sent: cloned)
            .then((StringResponse r) async {
      StringResponse ret = r;
      for (After func in cloned.getAfter) {
        var res = await func(r);
        if (res is StringResponse) ret = res;
      }
      return ret;
    }));
    if (onSuccess != null) resp = resp.onSuccess(onSuccess);
    if (onFailure != null) resp = resp.onFailure(onFailure);
    if (then != null) resp = resp.run(then);
    if (throwOnErr == true) resp = resp.onFailure((r) => throw r);
    return resp;
  }

  AsyncStringResponse expect(List<Checker<Response>> conditions) =>
      go().expect(conditions);

  AsyncStringResponse exact(
          {int statusCode,
          String body,
          List<int> bytes,
          String mimeType,
          String encoding,
          Map<String, String> headers,
          int contentLength}) =>
      go().exact(
          statusCode: statusCode,
          body: body,
          bytes: bytes,
          mimeType: mimeType,
          encoding: encoding,
          headers: headers,
          contentLength: contentLength);
}

abstract class RouteWithBody implements RouteBase {
  dynamic getBody();
}

abstract class _RouteWithBodyMixin implements RouteWithBody {
  set _body(dynamic value);
  dynamic get _body;

  RouteWithBody body(dynamic body) {
    if (body is List<int>) {
      _body = body;
    } else {
      _body = body?.toString();
    }
    return this;
  }

  RouteWithBody json(body, {bool setHeaders: true}) {
    _body = codec.json.encode(body);
    if (setHeaders) {
      mimeType('application/json');
      header('Accept', 'application/json');
    }
    return this;
  }

  RouteWithBody multipart(Map<String, dynamic> values) {
    if (_body is! Map<String, Multipart>) _body = <String, Multipart>{};
    for (String field in values.keys) {
      dynamic value = values[field];
      if (value is List<int>)
        multipartFile(field, value);
      else if (value is Multipart)
        _body[field] = value;
      else
        multipartField(field, value);
    }
    return this;
  }

  RouteWithBody multipartField(String field, value) {
    if (_body is! Map<String, Multipart>) _body = <String, Multipart>{};
    if (value != null) {
      _body[field] = MultipartString(value?.toString());
    }
    return this;
  }

  RouteWithBody multipartFile(String field, List<int> value,
      {String filename, MediaType contentType}) {
    if (_body is! Map<String, Multipart>) _body = <String, Multipart>{};
    if (value != null) {
      _body[field] =
          MultipartFile(value, filename: filename, contentType: contentType);
    }
    return this;
  }

  RouteWithBody multipartStringFile(String field, String value,
      {String filename, MediaType contentType}) {
    if (_body is! Map<String, Multipart>) _body = <String, Multipart>{};
    if (value != null) {
      _body[field] = MultipartStringFile(value,
          filename: filename, contentType: contentType);
    }
    return this;
  }

  RouteWithBody urlEncodedForm(Map<String, dynamic> values) {
    if (_body is! Map<String, String>) _body = <String, String>{};
    for (String field in values.keys) {
      if (values[field] != null) {
        _body[field] = values[field]?.toString();
      }
    }
    return this;
  }

  RouteWithBody urlEncodedFormField(String name, value) {
    if (_body is! Map<String, String>) _body = <String, String>{};
    if (value != null) {
      _body[name] = value?.toString();
    }
    return this;
  }
}

/// Build fluent REST POST APIs
///
/// Example:
///     post('/book/${id}')
///       .json(book.toMap)
///       .fetch((m) => Book.fromMap(m));
class Post extends RouteBase
    with _RouteWithBodyMixin, RouteFetch
    implements RouteWithBody {
  dynamic _body;

  Post(String url) {
    this.url(url);
  }

  Post.copy(Route route) {
    _origin = route._origin;
    _paths.addAll(route._paths);
    _pathParams.addAll(route._pathParams);
    getQuery.addAll(route.getQuery);
    getHeaders.addAll(route.getHeaders);
    getAuthHeaders.addAll(route.getAuthHeaders);
    getCookies.addAll(route.getCookies);
    metadataMap.addAll(route.metadataMap);
    getClient = route.getClient;
    getBefore.addAll(route.getBefore);
    getAfter.addAll(route.getAfter);
  }

  Post.clone(Post route) {
    _body = route._body; // TODO deep copy
    _origin = route._origin;
    _paths.addAll(route._paths);
    _pathParams.addAll(route._pathParams);
    getQuery.addAll(route.getQuery);
    getHeaders.addAll(route.getHeaders);
    getAuthHeaders.addAll(route.getAuthHeaders);
    getCookies.addAll(route.getCookies);
    metadataMap.addAll(route.metadataMap);
    getClient = route.getClient;
    getBefore.addAll(route.getBefore);
    getAfter.addAll(route.getAfter);
  }

  dynamic getBody() => _body;

  Post withClient(ht.BaseClient client) => super.withClient(client);

  Post http(String origin, [String path]) => super.http(origin, path);

  Post https(String origin, [String path]) => super.https(origin, path);

  Post origin(String origin, [String path]) => super.origin(origin, path);

  Post path(String path) => super.path(path);

  Post pathParams(String name, dynamic value) => super.pathParams(name, value);

  Post query(String key, value) => super.query(key, value);

  Post metadata(Map<String, dynamic> metaData) => super.metadata(metaData);

  Post hookHeader(String key, ValueCallback<String> getter) =>
      super.hookHeader(key, getter);

  Post queries(Map<String, dynamic> value) => super.queries(value);

  Post header(String key, String value) => super.header(key, value);

  Post headers(Map<String, String> values) => super.headers(values);

  Post mimeType(String mimeType) => super.mimeType(mimeType);

  Post charset(String charset) => super.charset(charset);

  Post contentType(String mimeType, String charset) =>
      super.contentType(mimeType, charset);

  Post authHeader(String scheme, String credentials) =>
      super.authHeader(scheme, credentials);

  Post authToken(String credentials) => super.authToken(credentials);

  Post basicAuth(String username, String password) =>
      super.basicAuth(username, password);

  Post cookie(ClientCookie cookie) => super.cookie(cookie);

  Post cookies(List<ClientCookie> cookies) => super.cookies(cookies);

  Post body(dynamic body) => super.body(body);

  Post json(body, {bool setHeaders: true}) =>
      super.json(body, setHeaders: setHeaders);

  Post multipart(Map<String, dynamic> values) => super.multipart(values);

  Post multipartField(String field, value) =>
      super.multipartField(field, value);

  Post multipartFile(String field, List<int> value,
          {String filename, MediaType contentType}) =>
      super.multipartFile(field, value,
          filename: filename, contentType: contentType);

  Post multipartStringFile(String field, String value,
          {String filename, MediaType contentType}) =>
      super.multipartStringFile(field, value,
          filename: filename, contentType: contentType);

  Post urlEncodedForm(Map<String, dynamic> values) =>
      super.urlEncodedForm(values);

  Post urlEncodedFormField(String name, value) =>
      super.urlEncodedFormField(name, value);

  Post before(Before interceptor) => super.before(interceptor);

  Post after(After interceptor) => super.after(interceptor);

  Post url(String value) => super.url(value);

  Future<ht.Response> _send() async {
    for (Before mod in getBefore) await mod(this);

    _prepare(this);

    if (_body is String ||
        _body is List<int> ||
        _body is Map<String, String> ||
        _body == null) {
      return (getClient ?? globalClient)
          .post(getUrl, headers: getHeaders, body: _body);
    } else if (_body is Map<String, Multipart>) {
      final body = _body as Map<String, Multipart>;
      final r = ht.MultipartRequest('POST', Uri.parse(getUrl));
      for (final String field in body.keys) {
        final Multipart value = body[field];
        if (value is MultipartString) {
          r.fields[field] = value.value;
        } else if (value is MultipartStreamFile) {
          r.files.add(ht.MultipartFile(field, value.value, value.length,
              filename: value.filename, contentType: value.contentType));
        } else if (value is MultipartFile) {
          r.files.add(ht.MultipartFile.fromBytes(field, value.value,
              filename: value.filename, contentType: value.contentType));
        } else if (value is MultipartStringFile) {
          r.files.add(ht.MultipartFile.fromString(field, value.value,
              filename: value.filename, contentType: value.contentType));
        }
      }
      r.headers.addAll(getHeaders);
      return r.send().then((r) => ht.Response.fromStream(r));
    } else {
      throw Exception('Invalid body!');
    }
  }

  AsyncStringResponse go(
      {ResponseHook<String> onSuccess,
      ResponseHook<String> onFailure,
      ResponseHook<String> then,
      bool throwOnErr}) {
    Post cloned = Post.clone(this);
    AsyncStringResponse resp = AsyncStringResponse(
        AsyncStringResponse.from(cloned._send(), sender: this, sent: cloned)
            .then((StringResponse r) async {
      StringResponse ret = r;
      for (After func in cloned.getAfter) {
        var res = await func(r);
        if (res is StringResponse) ret = res;
      }
      return ret;
    }));
    if (onSuccess != null) resp = resp.onSuccess(onSuccess);
    if (onFailure != null) resp = resp.onFailure(onFailure);
    if (throwOnErr == true) resp = resp.onFailure((r) => throw r);
    if (then != null) resp = resp.run(then);
    return resp;
  }

  AsyncStringResponse expect(List<Checker<Response>> conditions) =>
      go().expect(conditions);

  AsyncStringResponse exact(
          {int statusCode,
          String body,
          List<int> bytes,
          String mimeType,
          String encoding,
          Map<String, String> headers,
          int contentLength}) =>
      go().exact(
          statusCode: statusCode,
          body: body,
          bytes: bytes,
          mimeType: mimeType,
          encoding: encoding,
          headers: headers,
          contentLength: contentLength);
}

/// Build fluent REST PATCH APIs
///
/// Example:
///     patch('/book/${id}')
///       .json(book.toMap)
///       .fetch((m) => Book.fromMap(m));
class Patch extends RouteBase
    with _RouteWithBodyMixin, RouteFetch
    implements RouteWithBody {
  dynamic _body;

  Patch(String url) {
    this.url(url);
  }

  Patch.copy(Route route) {
    _origin = route._origin;
    _paths.addAll(route._paths);
    _pathParams.addAll(route._pathParams);
    getQuery.addAll(route.getQuery);
    getHeaders.addAll(route.getHeaders);
    getAuthHeaders.addAll(route.getAuthHeaders);
    getCookies.addAll(route.getCookies);
    metadataMap.addAll(route.metadataMap);
    getClient = route.getClient;
    getBefore.addAll(route.getBefore);
    getAfter.addAll(route.getAfter);
  }

  Patch.clone(Patch route) {
    _body = route._body; // TODO deep copy
    _origin = route._origin;
    _paths.addAll(route._paths);
    _pathParams.addAll(route._pathParams);
    getQuery.addAll(route.getQuery);
    getHeaders.addAll(route.getHeaders);
    getAuthHeaders.addAll(route.getAuthHeaders);
    getCookies.addAll(route.getCookies);
    metadataMap.addAll(route.metadataMap);
    getClient = route.getClient;
    getBefore.addAll(route.getBefore);
    getAfter.addAll(route.getAfter);
  }

  dynamic getBody() => _body;

  Patch withClient(ht.BaseClient client) => super.withClient(client);

  Patch http(String origin, [String path]) => super.http(origin, path);

  Patch https(String origin, [String path]) => super.https(origin, path);

  Patch origin(String origin, [String path]) => super.origin(origin, path);

  Patch path(String path) => super.path(path);

  Patch pathParams(String name, dynamic value) => super.pathParams(name, value);

  Patch query(String key, value) => super.query(key, value);

  Patch metadata(Map<String, dynamic> metaData) => super.metadata(metaData);

  Patch hookHeader(String key, ValueCallback<String> getter) =>
      super.hookHeader(key, getter);

  Patch queries(Map<String, dynamic> value) => super.queries(value);

  Patch header(String key, String value) => super.header(key, value);

  Patch headers(Map<String, String> values) => super.headers(values);

  Patch mimeType(String mimeType) => super.mimeType(mimeType);

  Patch charset(String charset) => super.charset(charset);

  Patch contentType(String mimeType, String charset) =>
      super.contentType(mimeType, charset);

  Patch authHeader(String scheme, String credentials) =>
      super.authHeader(scheme, credentials);

  Patch authToken(String credentials) => super.authToken(credentials);

  Patch basicAuth(String username, String password) =>
      super.basicAuth(username, password);

  Patch cookie(ClientCookie cookie) => super.cookie(cookie);

  Patch cookies(List<ClientCookie> cookies) => super.cookies(cookies);

  Patch body(dynamic body) => super.body(body);

  Patch json(body, {bool setHeaders: true}) =>
      super.json(body, setHeaders: setHeaders);

  Patch multipart(Map<String, dynamic> values) => super.multipart(values);

  Patch multipartField(String field, value) =>
      super.multipartField(field, value);

  Patch multipartFile(String field, List<int> value,
          {String filename, MediaType contentType}) =>
      super.multipartFile(field, value,
          filename: filename, contentType: contentType);

  Patch multipartStringFile(String field, String value,
          {String filename, MediaType contentType}) =>
      super.multipartStringFile(field, value,
          filename: filename, contentType: contentType);

  Patch urlEncodedForm(Map<String, dynamic> values) =>
      super.urlEncodedForm(values);

  Patch urlEncodedFormField(String name, value) =>
      super.urlEncodedFormField(name, value);

  Patch before(Before interceptor) => super.before(interceptor);

  Patch after(After interceptor) => super.after(interceptor);

  Patch url(String value) => super.url(value);

  Future<ht.Response> _send() async {
    for (Before mod in getBefore) await mod(this);

    _prepare(this);

    if (_body is String ||
        _body is List<int> ||
        _body is Map<String, String> ||
        _body == null) {
      return (getClient ?? globalClient)
          .patch(getUrl, headers: getHeaders, body: _body);
    } else if (_body is Map<String, Multipart>) {
      final body = _body as Map<String, Multipart>;
      final r = ht.MultipartRequest('PATCH', Uri.parse(getUrl));
      for (final String field in body.keys) {
        final Multipart value = body[field];
        if (value is MultipartString) {
          r.fields[field] = value.value;
        } else if (value is MultipartStreamFile) {
          r.files.add(ht.MultipartFile(field, value.value, value.length,
              filename: value.filename, contentType: value.contentType));
        } else if (value is MultipartFile) {
          r.files.add(ht.MultipartFile.fromBytes(field, value.value,
              filename: value.filename, contentType: value.contentType));
        } else if (value is MultipartStringFile) {
          r.files.add(ht.MultipartFile.fromString(field, value.value,
              filename: value.filename, contentType: value.contentType));
        }
      }
      r.headers.addAll(getHeaders);
      return r.send().then((r) => ht.Response.fromStream(r));
    } else {
      throw Exception('Invalid body!');
    }
  }

  AsyncStringResponse go(
      {ResponseHook<String> onSuccess,
      ResponseHook<String> onFailure,
      ResponseHook<String> then,
      bool throwOnErr}) {
    Patch cloned = Patch.clone(this);
    AsyncStringResponse resp = AsyncStringResponse(
        AsyncStringResponse.from(cloned._send(), sender: this, sent: cloned)
            .then((StringResponse r) async {
      StringResponse ret = r;
      for (After func in cloned.getAfter) {
        var res = await func(r);
        if (res is StringResponse) ret = res;
      }
      return ret;
    }));
    if (onSuccess != null) resp = resp.onSuccess(onSuccess);
    if (onFailure != null) resp = resp.onFailure(onFailure);
    if (throwOnErr == true) resp = resp.onFailure((r) => throw r);
    if (then != null) resp = resp.run(then);
    return resp;
  }

  AsyncStringResponse expect(List<Checker<Response>> conditions) =>
      go().expect(conditions);

  AsyncStringResponse exact(
          {int statusCode,
          String body,
          List<int> bytes,
          String mimeType,
          String encoding,
          Map<String, String> headers,
          int contentLength}) =>
      go().exact(
          statusCode: statusCode,
          body: body,
          bytes: bytes,
          mimeType: mimeType,
          encoding: encoding,
          headers: headers,
          contentLength: contentLength);
}

/// Build fluent REST PUT APIs
///
/// Example:
///     put('/book/${id}')
///       .json(book.toMap)
///       .fetch((m) => Book.fromMap(m));
class Put extends RouteBase
    with _RouteWithBodyMixin, RouteFetch
    implements RouteWithBody {
  dynamic _body;

  Put(String url) {
    this.url(url);
  }

  Put.copy(Route route) {
    _origin = route._origin;
    _paths.addAll(route._paths);
    _pathParams.addAll(route._pathParams);
    getQuery.addAll(route.getQuery);
    getHeaders.addAll(route.getHeaders);
    getAuthHeaders.addAll(route.getAuthHeaders);
    getCookies.addAll(route.getCookies);
    metadataMap.addAll(route.metadataMap);
    getClient = route.getClient;
    getBefore.addAll(route.getBefore);
    getAfter.addAll(route.getAfter);
  }

  Put.clone(Put route) {
    _body = route._body; // TODO deep copy
    _origin = route._origin;
    _paths.addAll(route._paths);
    _pathParams.addAll(route._pathParams);
    getQuery.addAll(route.getQuery);
    getHeaders.addAll(route.getHeaders);
    getAuthHeaders.addAll(route.getAuthHeaders);
    getCookies.addAll(route.getCookies);
    metadataMap.addAll(route.metadataMap);
    getClient = route.getClient;
    getBefore.addAll(route.getBefore);
    getAfter.addAll(route.getAfter);
  }

  dynamic getBody() => _body;

  Put withClient(ht.BaseClient client) => super.withClient(client);

  Put http(String origin, [String path]) => super.http(origin, path);

  Put https(String origin, [String path]) => super.https(origin, path);

  Put origin(String origin, [String path]) => super.origin(origin, path);

  Put path(String path) => super.path(path);

  Put pathParams(String name, dynamic value) => super.pathParams(name, value);

  Put query(String key, value) => super.query(key, value);

  Put metadata(Map<String, dynamic> metaData) => super.metadata(metaData);

  Put hookHeader(String key, ValueCallback<String> getter) =>
      super.hookHeader(key, getter);

  Put queries(Map<String, dynamic> value) => super.queries(value);

  Put header(String key, String value) => super.header(key, value);

  Put headers(Map<String, String> values) => super.headers(values);

  Put mimeType(String mimeType) => super.mimeType(mimeType);

  Put charset(String charset) => super.charset(charset);

  Put contentType(String mimeType, String charset) =>
      super.contentType(mimeType, charset);

  Put authHeader(String scheme, String credentials) =>
      super.authHeader(scheme, credentials);

  Put authToken(String credentials) => super.authToken(credentials);

  Put basicAuth(String username, String password) =>
      super.basicAuth(username, password);

  Put cookie(ClientCookie cookie) => super.cookie(cookie);

  Put cookies(List<ClientCookie> cookies) => super.cookies(cookies);

  Put body(dynamic body) => super.body(body);

  Put json(body, {bool setHeaders: true}) =>
      super.json(body, setHeaders: setHeaders);

  Put multipart(Map<String, dynamic> values) => super.multipart(values);

  Put multipartField(String field, value) => super.multipartField(field, value);

  Put multipartFile(String field, List<int> value,
          {String filename, MediaType contentType}) =>
      super.multipartFile(field, value,
          filename: filename, contentType: contentType);

  Put multipartStringFile(String field, String value,
          {String filename, MediaType contentType}) =>
      super.multipartStringFile(field, value,
          filename: filename, contentType: contentType);

  Put urlEncodedForm(Map<String, dynamic> values) =>
      super.urlEncodedForm(values);

  Put urlEncodedFormField(String name, value) =>
      super.urlEncodedFormField(name, value);

  Put before(Before interceptor) => super.before(interceptor);

  Put after(After interceptor) => super.after(interceptor);

  Put url(String value) => super.url(value);

  Future<ht.Response> _send() async {
    for (Before mod in getBefore) await mod(this);

    _prepare(this);

    if (_body is String ||
        _body is List<int> ||
        _body is Map<String, String> ||
        _body == null) {
      return (getClient ?? globalClient)
          .put(getUrl, headers: getHeaders, body: _body);
    } else if (_body is Map<String, Multipart>) {
      final body = _body as Map<String, Multipart>;
      final r = ht.MultipartRequest('PUT', Uri.parse(getUrl));
      for (final String field in body.keys) {
        final Multipart value = body[field];
        if (value is MultipartString) {
          r.fields[field] = value.value;
        } else if (value is MultipartStreamFile) {
          r.files.add(ht.MultipartFile(field, value.value, value.length,
              filename: value.filename, contentType: value.contentType));
        } else if (value is MultipartFile) {
          r.files.add(ht.MultipartFile.fromBytes(field, value.value,
              filename: value.filename, contentType: value.contentType));
        } else if (value is MultipartStringFile) {
          r.files.add(ht.MultipartFile.fromString(field, value.value,
              filename: value.filename, contentType: value.contentType));
        }
      }
      r.headers.addAll(getHeaders);
      return r.send().then((r) => ht.Response.fromStream(r));
    } else {
      throw Exception('Invalid body!');
    }
  }

  AsyncStringResponse go(
      {ResponseHook<String> onSuccess,
      ResponseHook<String> onFailure,
      ResponseHook<String> then,
      bool throwOnErr}) {
    Put cloned = Put.clone(this);
    AsyncStringResponse resp = AsyncStringResponse(
        AsyncStringResponse.from(cloned._send(), sender: this, sent: cloned)
            .then((StringResponse r) async {
      StringResponse ret = r;
      for (After func in cloned.getAfter) {
        var res = await func(r);
        if (res is StringResponse) ret = res;
      }
      return ret;
    }));
    if (onSuccess != null) resp = resp.onSuccess(onSuccess);
    if (onFailure != null) resp = resp.onFailure(onFailure);
    if (throwOnErr == true) resp = resp.onFailure((r) => throw r);
    if (then != null) resp = resp.run(then);
    return resp;
  }

  AsyncStringResponse expect(List<Checker<Response>> conditions) =>
      go().expect(conditions);

  AsyncStringResponse exact(
          {int statusCode,
          String body,
          List<int> bytes,
          String mimeType,
          String encoding,
          Map<String, String> headers,
          int contentLength}) =>
      go().exact(
          statusCode: statusCode,
          body: body,
          bytes: bytes,
          mimeType: mimeType,
          encoding: encoding,
          headers: headers,
          contentLength: contentLength);
}

/// Build fluent REST DELETE APIs
///
/// Example:
///     delete('/book/${id}')
///       .fetchList((m) => Book.fromMap(m));
class Delete extends RouteBase with RouteFetch {
  Delete(String url) {
    this.url(url);
  }

  Delete.copy(Route route) {
    _origin = route._origin;
    _paths.addAll(route._paths);
    _pathParams.addAll(route._pathParams);
    getQuery.addAll(route.getQuery);
    getHeaders.addAll(route.getHeaders);
    getAuthHeaders.addAll(route.getAuthHeaders);
    getCookies.addAll(route.getCookies);
    metadataMap.addAll(route.metadataMap);
    getClient = route.getClient;
    getBefore.addAll(route.getBefore);
    getAfter.addAll(route.getAfter.toList());
  }

  Delete.clone(Delete route) {
    _origin = route._origin;
    _paths.addAll(route._paths);
    _pathParams.addAll(route._pathParams);
    getQuery.addAll(route.getQuery);
    getHeaders.addAll(route.getHeaders);
    getAuthHeaders.addAll(route.getAuthHeaders);
    getCookies.addAll(route.getCookies);
    metadataMap.addAll(route.metadataMap);
    getClient = route.getClient;
    getBefore.addAll(route.getBefore);
    getAfter.addAll(route.getAfter.toList());
  }

  Delete withClient(ht.BaseClient client) => super.withClient(client);

  Delete http(String origin, [String path]) => super.http(origin, path);

  Delete https(String origin, [String path]) => super.https(origin, path);

  Delete origin(String origin, [String path]) => super.origin(origin, path);

  Delete path(String path) => super.path(path);

  Delete pathParams(String name, dynamic value) =>
      super.pathParams(name, value);

  Delete query(String key, value) => super.query(key, value);

  Delete metadata(Map<String, dynamic> metaData) => super.metadata(metaData);

  Delete hookHeader(String key, ValueCallback<String> getter) =>
      super.hookHeader(key, getter);

  Delete queries(Map<String, dynamic> value) => super.queries(value);

  Delete header(String key, String value) => super.header(key, value);

  Delete headers(Map<String, String> values) => super.headers(values);

  Delete mimeType(String mimeType) => super.mimeType(mimeType);

  Delete charset(String charset) => super.charset(charset);

  Delete contentType(String mimeType, String charset) =>
      super.contentType(mimeType, charset);

  Delete authHeader(String scheme, String credentials) =>
      super.authHeader(scheme, credentials);

  Delete authToken(String credentials) => super.authToken(credentials);

  Delete basicAuth(String username, String password) =>
      super.basicAuth(username, password);

  Delete cookie(ClientCookie cookie) => super.cookie(cookie);

  Delete cookies(List<ClientCookie> cookies) => super.cookies(cookies);

  Delete before(Before interceptor) => super.before(interceptor);

  Delete after(After interceptor) => super.after(interceptor);

  Delete url(String value) => super.url(value);

  Future<ht.Response> _send() async {
    for (Before mod in getBefore) await mod(this);
    _prepare(this);
    return (getClient ?? globalClient).delete(getUrl, headers: getHeaders);
  }

  AsyncStringResponse go(
      {ResponseHook<String> onSuccess,
      ResponseHook<String> onFailure,
      ResponseHook<String> then,
      bool throwOnErr}) {
    Delete cloned = Delete.clone(this);
    AsyncStringResponse resp = AsyncStringResponse(
        AsyncStringResponse.from(cloned._send(), sender: this, sent: cloned)
            .then((StringResponse r) async {
      StringResponse ret = r;
      for (After func in cloned.getAfter) {
        var res = await func(r);
        if (res is StringResponse) ret = res;
      }
      return ret;
    }));
    if (onSuccess != null) resp = resp.onSuccess(onSuccess);
    if (onFailure != null) resp = resp.onFailure(onFailure);
    if (throwOnErr == true) resp = resp.onFailure((r) => throw r);
    if (then != null) resp = resp.run(then);
    return resp;
  }

  AsyncStringResponse expect(List<Checker<Response>> conditions) =>
      go().expect(conditions);

  AsyncStringResponse exact(
          {int statusCode,
          String body,
          List<int> bytes,
          String mimeType,
          String encoding,
          Map<String, String> headers,
          int contentLength}) =>
      go().exact(
          statusCode: statusCode,
          body: body,
          bytes: bytes,
          mimeType: mimeType,
          encoding: encoding,
          headers: headers,
          contentLength: contentLength);
}

/// Build fluent REST DELETE APIs
///
/// Example:
///     options('/book/${id}').go();
class OptionsMethod extends RouteBase with RouteFetch {
  OptionsMethod(String url) {
    this.url(url);
  }

  OptionsMethod.copy(Route route) {
    _origin = route._origin;
    _paths.addAll(route._paths);
    _pathParams.addAll(route._pathParams);
    getQuery.addAll(route.getQuery);
    getHeaders.addAll(route.getHeaders);
    getAuthHeaders.addAll(route.getAuthHeaders);
    getCookies.addAll(route.getCookies);
    metadataMap.addAll(route.metadataMap);
    getClient = route.getClient;
    getBefore.addAll(route.getBefore);
    getAfter.addAll(route.getAfter.toList());
  }

  OptionsMethod.clone(OptionsMethod route) {
    _origin = route._origin;
    _paths.addAll(route._paths);
    _pathParams.addAll(route._pathParams);
    getQuery.addAll(route.getQuery);
    getHeaders.addAll(route.getHeaders);
    getAuthHeaders.addAll(route.getAuthHeaders);
    getCookies.addAll(route.getCookies);
    metadataMap.addAll(route.metadataMap);
    getClient = route.getClient;
    getBefore.addAll(route.getBefore);
    getAfter.addAll(route.getAfter.toList());
  }

  OptionsMethod withClient(ht.BaseClient client) => super.withClient(client);

  OptionsMethod http(String origin, [String path]) => super.http(origin, path);

  OptionsMethod https(String origin, [String path]) =>
      super.https(origin, path);

  OptionsMethod origin(String origin, [String path]) =>
      super.origin(origin, path);

  OptionsMethod path(String path) => super.path(path);

  OptionsMethod pathParams(String name, dynamic value) =>
      super.pathParams(name, value);

  OptionsMethod query(String key, value) => super.query(key, value);

  OptionsMethod metadata(Map<String, dynamic> metaData) =>
      super.metadata(metaData);

  OptionsMethod hookHeader(String key, ValueCallback<String> getter) =>
      super.hookHeader(key, getter);

  OptionsMethod queries(Map<String, dynamic> value) => super.queries(value);

  OptionsMethod header(String key, String value) => super.header(key, value);

  OptionsMethod headers(Map<String, String> values) => super.headers(values);

  OptionsMethod mimeType(String mimeType) => super.mimeType(mimeType);

  OptionsMethod charset(String charset) => super.charset(charset);

  OptionsMethod contentType(String mimeType, String charset) =>
      super.contentType(mimeType, charset);

  OptionsMethod authHeader(String scheme, String credentials) =>
      super.authHeader(scheme, credentials);

  OptionsMethod authToken(String credentials) => super.authToken(credentials);

  OptionsMethod basicAuth(String username, String password) =>
      super.basicAuth(username, password);

  OptionsMethod cookie(ClientCookie cookie) => super.cookie(cookie);

  OptionsMethod cookies(List<ClientCookie> cookies) => super.cookies(cookies);

  OptionsMethod before(Before interceptor) => super.before(interceptor);

  OptionsMethod after(After interceptor) => super.after(interceptor);

  OptionsMethod url(String value) => super.url(value);

  Future<ht.Response> _send() async {
    for (Before mod in getBefore) await mod(this);
    _prepare(this);
    final req = ht.Request('OPTIONS', Uri.parse(getUrl));
    req.headers.addAll(getHeaders);
    return (getClient ?? globalClient)
        .send(req)
        .then((r) => ht.Response.fromStream(r));
  }

  AsyncStringResponse go(
      {ResponseHook<String> onSuccess,
      ResponseHook<String> onFailure,
      ResponseHook<String> then,
      bool throwOnErr}) {
    OptionsMethod cloned = OptionsMethod.clone(this);
    AsyncStringResponse resp = AsyncStringResponse(
        AsyncStringResponse.from(cloned._send(), sender: this, sent: cloned)
            .then((StringResponse r) async {
      StringResponse ret = r;
      for (After func in cloned.getAfter) {
        var res = await func(r);
        if (res is StringResponse) ret = res;
      }
      return ret;
    }));
    if (onSuccess != null) resp = resp.onSuccess(onSuccess);
    if (onFailure != null) resp = resp.onFailure(onFailure);
    if (throwOnErr == true) resp = resp.onFailure((r) => throw r);
    if (then != null) resp = resp.run(then);
    return resp;
  }

  AsyncStringResponse expect(List<Checker<Response>> conditions) =>
      go().expect(conditions);

  AsyncStringResponse exact(
          {int statusCode,
          String body,
          List<int> bytes,
          String mimeType,
          String encoding,
          Map<String, String> headers,
          int contentLength}) =>
      go().exact(
          statusCode: statusCode,
          body: body,
          bytes: bytes,
          mimeType: mimeType,
          encoding: encoding,
          headers: headers,
          contentLength: contentLength);
}

abstract class Multipart {}

class MultipartString implements Multipart {
  final String value;

  MultipartString(this.value);
}

class MultipartFile implements Multipart {
  final String filename;

  final MediaType contentType;

  final List<int> value;

  MultipartFile(this.value, {this.filename, this.contentType});
}

class MultipartStreamFile implements Multipart {
  final String filename;

  final MediaType contentType;

  final Stream<List<int>> value;

  final int length;

  MultipartStreamFile(this.value, this.length,
      {this.filename, this.contentType});
}

class MultipartStringFile implements Multipart {
  final String filename;

  final MediaType contentType;

  final String value;

  MultipartStringFile(this.value, {this.filename, this.contentType});
}

class ErrorResponse {
  final Response response;

  ErrorResponse(this.response);

  int get statusCode => response.statusCode;

  String get body => response.body;

  String toString() => 'Http error! Status code: $statusCode body: $body';
}

typedef ValueCallback<T> = void Function(T value);
