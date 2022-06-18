// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:http/src/utils.dart';
import 'package:test/test.dart';

export '../utils.dart';

/// The current server instance.
HttpServer _server;

/// The URL for the current server instance.
Uri get serverUrl => Uri.parse('http://localhost:${_server.port}');

/// Starts a new HTTP server.
Future startServer() {
  return HttpServer.bind("localhost", 0).then((s) {
    _server = s;
    s.listen((request) {
      var path = request.uri.path;
      var response = request.response;

      if (path == '/error') {
        response.statusCode = 400;
        response.contentLength = 0;
        response.close();
        return;
      }

      if (path == '/loop') {
        var n = int.parse(request.uri.query);
        response.statusCode = 302;
        response.headers
            .set('location', serverUrl.resolve('/loop?${n + 1}').toString());
        response.contentLength = 0;
        response.close();
        return;
      }

      if (path == '/redirect') {
        response.statusCode = 302;
        response.headers.set('location', serverUrl.resolve('/').toString());
        response.contentLength = 0;
        response.close();
        return;
      }

      if (path == '/no-content-length') {
        response.statusCode = 200;
        response.contentLength = -1;
        response.write('body');
        response.close();
        return;
      }

      new ByteStream(request).toBytes().then((requestBodyBytes) {
        var outputEncoding;
        var encodingName = request.uri.queryParameters['response-encoding'];
        if (encodingName != null) {
          outputEncoding = requiredEncodingForCharset(encodingName);
        } else {
          outputEncoding = ascii;
        }

        response.headers.contentType = new ContentType("application", "json",
            charset: outputEncoding.name);
        response.headers.set('single', 'value');

        var requestBody;
        if (requestBodyBytes.isEmpty) {
          requestBody = null;
        } else if (request.headers.contentType != null &&
            request.headers.contentType.charset != null) {
          var encoding =
              requiredEncodingForCharset(request.headers.contentType.charset);
          requestBody = encoding.decode(requestBodyBytes);
        } else {
          requestBody = requestBodyBytes;
        }

        var content = <String, dynamic>{
          'method': request.method,
          'path': request.uri.path,
          'headers': {}
        };
        if (requestBody != null) content['body'] = requestBody;
        request.headers.forEach((name, values) {
          // These headers are automatically generated by dart:io, so we don't
          // want to test them here.
          if (name == 'cookie' || name == 'host') return;

          content['headers'][name] = values;
        });

        var body = json.encode(content);
        response.contentLength = body.length;
        response.write(body);
        response.close();
      });
    });
  });
}

/// Stops the current HTTP server.
void stopServer() {
  if (_server != null) {
    _server.close();
    _server = null;
  }
}

/// A matcher for functions that throw HttpException.
Matcher get throwsClientException =>
    throwsA(new TypeMatcher<ClientException>());

/// A matcher for RedirectLimitExceededExceptions.
final isRedirectLimitExceededException = const TypeMatcher<RedirectException>()
    .having((e) => e.message, 'message', 'Redirect limit exceeded');

/// A matcher for functions that throw RedirectLimitExceededException.
final Matcher throwsRedirectLimitExceededException =
    throwsA(isRedirectLimitExceededException);

/// A matcher for functions that throw SocketException.
final Matcher throwsSocketException =
    throwsA(const TypeMatcher<SocketException>());
