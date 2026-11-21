# Home Assistant ingress front of the NPMplus admin UI.
# Rendered at every start from nginx.conf.tpl by the NPMplus app; edit the template, not this file.
#
# It mirrors the routes of the UI virtual host of NPMplus (static files, the gravatar folder and the
# API behind a unix socket), minus TLS, so a request is answered by one nginx without any detour.

upstream npmplus_app_backend {
  server unix:/run/npmplus.sock;
  keepalive 8;
}

# The backend rejects requests whose Origin differs from the address it believes it is reached at
# (scheme from X-Forwarded-Proto, host from X-Forwarded-Host). Behind ingress that address is Home
# Assistant's, which the browser states in Origin, so both values are taken from it. Requests from
# other sites are still refused by the backend through their Sec-Fetch-Site header.
map $http_origin $npmplus_app_scheme {
  "~^(?<origin_scheme>https?)://" $origin_scheme;
  default                         https;
}

map $http_origin $npmplus_app_host {
  "~^https?://(?<origin_host>[^/]+)" $origin_host;
  default                            $http_host;
}

# Only the Supervisor (ingress gateway and watchdog) may talk to this server. The address of the
# connection itself counts: NPMplus replaces $remote_addr with the client address from
# X-Forwarded-For (realip module), which for ingress is the browser's, never the Supervisor's.
geo $realip_remote_addr $npmplus_app_from_supervisor {
  default     0;
  @SUPERVISOR_ADDRESS@ 1;
}

server {
  # The app shares the network of the host, so the server listens on the address of the Supervisor's
  # network only and is out of reach for the LAN.
  listen @INGRESS_ADDRESS@:@INGRESS_PORT@ default_server;
  server_name _;

  if ($npmplus_app_from_supervisor = 0) {
    return 403;
  }

  access_log off;
  root @UI_ROOT@;
  more_set_headers "X-Content-Type-Options: nosniff";

  # The set of files is small and changes only with an update.
  open_file_cache max=64 inactive=5m;
  open_file_cache_valid 1m;

  # Settings of every request that goes to the backend.
  proxy_http_version 1.1;
  proxy_set_header Connection "";
  proxy_set_header Host $http_host;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-Proto $npmplus_app_scheme;
  proxy_set_header X-Forwarded-Host $npmplus_app_host;
  # nginx compresses the answers itself; the backend should not.
  proxy_set_header Accept-Encoding "";

  # Health probe of the Supervisor watchdog: answers 200 only while the NPMplus API is up.
  location = /healthz {
    proxy_pass http://npmplus_app_backend/api;
  }

  # Browser-side helpers of the ingress integration (see assets/shim.js).
  location /_npmplus_app/ {
    alias @SHARE_DIR@/assets/;
    more_set_headers "Cache-Control: no-cache";
  }

  # The file names of the bundles contain a hash of their content, so they never change.
  # The image ships them precompressed (gzip, brotli, zstd), which nginx serves as they are.
  location /assets/ {
    more_set_headers "Cache-Control: public, max-age=31536000, immutable";
  }

  location /images/ {
    more_set_headers "Cache-Control: public, max-age=86400";
  }

  location /images/gravatar/ {
    more_set_headers "Content-Security-Policy: @CSP_GRAVATAR@";
    more_set_headers "Cache-Control: no-cache";
    alias /data/npmplus/gravatar/;
  }

  location /api {
    more_set_headers "Content-Security-Policy: @CSP_API@";
    proxy_pass http://npmplus_app_backend;
  }

  location /api/docs {
    more_set_headers "Content-Security-Policy: @CSP_DOCS@";
    proxy_pass http://npmplus_app_backend;
  }

  # The page itself. Ingress serves the UI below /api/hassio_ingress/<token>. The path arrives in
  # X-Ingress-Path; the page's own root-relative links are moved below it, and the shim is added as
  # first script. Every other path is a route of the single page application.
  location / {
    more_set_headers "Content-Security-Policy: @CSP_ROOT@";
    more_set_headers "Cache-Control: no-cache";
    try_files $uri /index.html;

    sub_filter_once off;
    sub_filter '<head>' '<head><script src="$http_x_ingress_path/_npmplus_app/shim.js" data-version="@APP_VERSION@"></script>';
    sub_filter 'src="/' 'src="$http_x_ingress_path/';
    sub_filter 'href="/' 'href="$http_x_ingress_path/';
    sub_filter 'content="/' 'content="$http_x_ingress_path/';
  }
}
