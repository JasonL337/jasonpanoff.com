// CloudFront Function — VIEWER REQUEST trigger.
// Deployed to distribution E2OWGQLWY22666 (jasonpanoff.com).
//
// Two jobs:
//   1. 301 www.jasonpanoff.com -> jasonpanoff.com  (apex is canonical)
//   2. Rewrite directory-style URIs to index.html, because the S3 REST
//      endpoint has no concept of a directory index.
//
// Runtime is not full Node — no require, no fetch, ES5-safe style used
// deliberately so it runs on either cloudfront-js-1.0 or 2.0.
//
// NOTE: requests to the raw *.cloudfront.net domain are intentionally NOT
// redirected, so the distribution stays directly testable.

var CANONICAL_HOST = 'jasonpanoff.com';
var REDIRECT_HOSTS = { 'www.jasonpanoff.com': true };

function buildQueryString(qs) {
    var parts = [];
    for (var key in qs) {
        if (!Object.prototype.hasOwnProperty.call(qs, key)) continue;
        var entry = qs[key];
        if (entry.multiValue) {
            for (var i = 0; i < entry.multiValue.length; i++) {
                parts.push(key + '=' + entry.multiValue[i].value);
            }
        } else if (entry.value) {
            parts.push(key + '=' + entry.value);
        } else {
            parts.push(key);
        }
    }
    return parts.length ? '?' + parts.join('&') : '';
}

function handler(event) {
    var request = event.request;
    var host = request.headers.host ? request.headers.host.value : '';

    if (REDIRECT_HOSTS[host]) {
        return {
            statusCode: 301,
            statusDescription: 'Moved Permanently',
            headers: {
                location: {
                    value: 'https://' + CANONICAL_HOST + request.uri +
                           buildQueryString(request.querystring)
                }
            }
        };
    }

    var uri = request.uri;

    // "/projects/" -> "/projects/index.html"
    if (uri.charAt(uri.length - 1) === '/') {
        request.uri = uri + 'index.html';
        return request;
    }

    // "/projects" -> "/projects/index.html", but leave "/css/style.css" alone.
    // A dot in the last path segment means it is a file, not a directory.
    var lastSegment = uri.substring(uri.lastIndexOf('/') + 1);
    if (lastSegment.indexOf('.') === -1) {
        request.uri = uri + '/index.html';
    }

    return request;
}
