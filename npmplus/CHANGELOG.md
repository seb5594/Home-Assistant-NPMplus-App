# Changelog

## 2026.11.21.5

* The app is marked as experimental. It is new, and the ingress integration and the import of other Nginx Proxy Manager installations have only been exercised with test data so far.

## 2026.11.21.4

* The footer below the admin interface is back, as an option: *Interface → Show app footer*, on by default. It shows the app version, "Made with ❤️ in Germany 🇩🇪" and the links "Support my work ☕🍺" and PayPal.

## 2026.11.21.3

* The data of the edge version of the Community App for Nginx Proxy Manager can be imported as well (Migration → Import from → community_app_edge). Each variant is looked up by its own repository, so both may be installed at the same time.

## 2026.11.21.2

* The sidebar entry is faster: the app's nginx now serves the admin interface itself instead of forwarding to the TLS port, and the interface files ship precompressed (brotli, gzip and zstd at the highest level) with long-lived caching. The main bundle is sent in 0.4 ms instead of 12 ms and is a third smaller.

## 2026.11.21.1

* Removed the support footer from the admin interface and the base image digest from the Dockerfile.

## 2026.11.21

* First release: NPMplus 2026-11-18-r1 as a Home Assistant app for amd64 and aarch64. The admin UI opens in the sidebar through ingress and starts in dark mode, the NPMplus settings are options of the app, and the data of an existing Nginx Proxy Manager installation can be imported once.
