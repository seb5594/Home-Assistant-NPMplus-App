# Home Assistant ingress front of the NPMplus admin UI.
# Rendered at every start from nginx.conf.tpl by the NPMplus app; edit the template, not this file.

upstream npmplus_app_ui {
  server 127.0.0.1:@UI_PORT@;
  keepalive 4;
}

# The UI rejects requests whose Origin differs from the address it is reached at. Behind ingress
# the browser's Origin is Home Assistant's own, so an Origin that is present is restated for this
# hop. Requests from other sites are still refused by the UI through their Sec-Fetch-Site header.
map $http_origin $npmplus_app_origin {
  ""      "";
  default "https://$http_host";
}

server {
  listen @INGRESS_PORT@ default_server;
  server_name _;

  # Only the Supervisor (ingress gateway and watchdog) may talk to this server.
  allow 172.30.32.2;
  deny all;

  access_log off;

  # How every request reaches the real UI: TLS with its self-signed certificate on the loopback.
  proxy_http_version 1.1;
  proxy_set_header Connection "";
  proxy_ssl_server_name on;
  proxy_ssl_name npmplus-ingress;
  proxy_ssl_verify off;
  proxy_set_header Host $http_host;
  proxy_set_header Origin $npmplus_app_origin;
  # The UI redirects plain-HTTP clients to HTTPS; the hop in front of it is HTTPS already.
  proxy_set_header X-Forwarded-Proto https;
  # sub_filter cannot rewrite compressed responses.
  proxy_set_header Accept-Encoding "";

  # Health probe of the Supervisor watchdog: answers 200 only while the NPMplus API is up.
  location = /healthz {
    proxy_pass https://npmplus_app_ui/api;
  }

  # Browser-side helper of the ingress integration (see assets/shim.js).
  location /_npmplus_app/ {
    alias @SHARE_DIR@/assets/;
    add_header Cache-Control "no-cache";
  }

  location / {
    proxy_pass https://npmplus_app_ui;

    # Allow the UI to be shown inside the Home Assistant frame.
    proxy_hide_header X-Frame-Options;
    proxy_hide_header Cross-Origin-Embedder-Policy;
    proxy_hide_header Cross-Origin-Opener-Policy;
    proxy_hide_header Cross-Origin-Resource-Policy;
    # Keep the UI's content security policy, minus what breaks under ingress: the frame ban and
    # the forced upgrade to HTTPS (Home Assistant itself is often served over plain HTTP).
    header_filter_by_lua_block {
      local policy = ngx.header["Content-Security-Policy"]
      if policy then
        policy = policy:gsub("frame%-ancestors 'none'", "frame-ancestors 'self'")
        policy = policy:gsub("upgrade%-insecure%-requests;?%s*", "")
        ngx.header["Content-Security-Policy"] = policy
      end
    }

    # Ingress serves the UI below /api/hassio_ingress/<token>. The path arrives in X-Ingress-Path;
    # the page's own root-relative links are moved below it, and the shim is added as first script.
    sub_filter_once off;
    sub_filter '<head>' '<head><script src="$http_x_ingress_path/_npmplus_app/shim.js"></script>';
    sub_filter 'src="/' 'src="$http_x_ingress_path/';
    sub_filter 'href="/' 'href="$http_x_ingress_path/';
    sub_filter 'content="/' 'content="$http_x_ingress_path/';
  }
}
