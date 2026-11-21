<!-- header:begin (generated from project metadata) -->
<h1 align="center">
  <img src="https://raw.githubusercontent.com/seb5594/Home-Assistant-NPMplus-App/dev/npmplus/logo.png" alt="NPMplus" width="360" height="90">
  <br>
  NPMplus
</h1>

<p align="center">
  <a href="https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fseb5594%2FHome-Assistant-Apps"><img src="https://img.shields.io/static/v1?label=Home%20Assistant&amp;message=Add%20app%20repository&amp;color=18BCF2&amp;logo=homeassistant&amp;logoColor=white&amp;style=for-the-badge" alt="Home Assistant" height="28"></a><br>
  <a href="https://github.com/seb5594/Home-Assistant-NPMplus-App/releases/tag/2026.11.21.1"><img src="https://img.shields.io/static/v1?label=app%20version&amp;message=2026.11.21.1&amp;color=1877A5&amp;style=for-the-badge" alt="app version" height="28"></a>
  <img src="https://img.shields.io/static/v1?label=image%20pulls&amp;message=8&amp;color=1877A5&amp;style=for-the-badge" alt="image pulls" height="28"><br>
  <img src="https://img.shields.io/static/v1?label=stage&amp;message=stable&amp;color=2F855A&amp;style=flat" alt="stage" height="20">
  <img src="https://img.shields.io/static/v1?label=ingress&amp;message=enabled&amp;color=7C3AED&amp;style=flat" alt="ingress" height="20">
  <img src="https://img.shields.io/static/v1?label=arch%20%26%20size&amp;message=amd64%2089.6%20%C2%B7%20aarch64%2089.2%20MiB&amp;color=157F71&amp;style=flat" alt="arch &amp; size" height="20">
  <a href="https://github.com/seb5594/home-assistant-base-multi-arch"><img src="https://img.shields.io/static/v1?label=base%20image&amp;message=3.24-2026.11.0&amp;color=1877A5&amp;style=flat" alt="base image" height="20"></a>
  <img src="https://img.shields.io/static/v1?label=mounts&amp;message=addon_config%20%28rw%29%20%C2%B7%20app%20configs&amp;color=B45309&amp;style=flat" alt="mounts" height="20"><br>
  <a href="https://github.com/seb5594/Home-Assistant-NPMplus-App/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/seb5594/Home-Assistant-NPMplus-App/ci.yml?branch=dev&amp;label=checks&amp;style=flat" alt="checks" height="20"></a>
  <img src="https://img.shields.io/static/v1?label=runtime%20tests&amp;message=17%20passed&amp;color=2F855A&amp;style=flat" alt="runtime tests" height="20">
  <a href="https://github.com/seb5594/Home-Assistant-Apps/issues"><img src="https://img.shields.io/github/issues/seb5594/Home-Assistant-NPMplus-App?label=issues&amp;style=flat" alt="issues" height="20"></a><br>
  <a href="https://paypal.me/seb5594"><img src="https://img.shields.io/static/v1?label=Support&amp;message=PayPal&amp;color=0070BA&amp;logo=paypal&amp;logoColor=white&amp;style=for-the-badge" alt="PayPal" height="24"></a>
  <a href="https://buymeacoffee.com/seb5594"><img src="https://raw.githubusercontent.com/seb5594/Home-Assistant-Apps/473dc258f963096745aac327df54950eb9b59066/.github/assets/support-beer.svg" alt="Buy me a beer" height="24"></a><br>
  <a href="https://github.com/seb5594/Home-Assistant-Apps#license"><img src="https://img.shields.io/github/license/seb5594/Home-Assistant-NPMplus-App?label=license&amp;style=flat" alt="license" height="20"></a>
</p>
<!-- header:end -->

**🇬🇧 English** · [🇩🇪 Deutsch](README.de.md)

[NPMplus](https://github.com/ZoeyVid/NPMplus) as a Home Assistant app: a reverse proxy that puts your
services behind HTTPS with free certificates, managed in a web interface that opens right in the
Home Assistant sidebar.

NPMplus is a fork of Nginx Proxy Manager with a current nginx, HTTP/3, stricter defaults and plenty of
additions (OpenID Connect login, forward authentication, ...). This repository only packages it for
Home Assistant; the proxy itself is the unchanged upstream release, put on the shared
[Home Assistant base image](https://github.com/seb5594/home-assistant-base-multi-arch).

## What you get

- The admin interface in the **sidebar**, through ingress: no extra port, protected by your Home
  Assistant login, dark by default.
- **amd64 and aarch64** (Raspberry Pi 4/5, Home Assistant Green, mini PCs).
- Every NPMplus setting from the upstream `compose.yaml` as a validated **app option**, grouped and
  described, plus a free-form list that takes **any other environment variable**.
- A **one-time import of your existing Nginx Proxy Manager setup**, so you do not configure
  everything again. Guides for the [Community App](docs/MIGRATION.md#a-nginx-proxy-manager-community-app)
  and for [alexbelgium's app](docs/MIGRATION.md#b-alexbelgium-nginx-proxy-manager--static-web-server).
- Custom nginx snippets and the default web page in a **folder you can reach** with Samba or the File
  editor.
- The upstream version is pinned and kept current by Renovate.

## Install

1. Add this app repository to Home Assistant with the button above and install **NPMplus**.
2. Start it, open **NPMplus** in the sidebar and create your administrator.
3. Forward ports 80 and 443 (TCP, and 443 UDP for HTTP/3) from your router to Home Assistant.
4. Add your first proxy host.

Coming from Nginx Proxy Manager? Read the [migration guide](docs/MIGRATION.md) **before** the first
start.

## Migrating from Nginx Proxy Manager

| You use | How |
| --- | --- |
| **Nginx Proxy Manager** (Community Apps) | Set *Migration → Import from* to `community_app`, stop the old app, start NPMplus. The old data is read directly and never changed. |
| **Nginx Proxy Manager + Static Web Server** (alexbelgium) | Its data lives in private app storage, so it is copied out once. See [guide B](docs/MIGRATION.md#b-alexbelgium-nginx-proxy-manager--static-web-server). |
| Docker or anything else | Copy the data into the `import` folder, see [guide C](docs/MIGRATION.md#c-anything-else). |

Hosts, redirections, streams, users, access lists, certificates, the Let's Encrypt account and custom
nginx snippets come along. There is no way back to Nginx Proxy Manager, so take a backup first.

## See your proxy hosts in Home Assistant

The community integration **[ha-npmplus](https://github.com/metaathron/ha-npmplus)** matches this app:
it turns your proxy hosts, streams and certificates into devices and entities, so you can switch a
host on or off or watch certificate expiry from Home Assistant. Use the app's hostname (shown on its
Info page), port `81`, an NPMplus user, and leave the SSL verification off because port 81 uses a
self-signed certificate. Port 81 does not need to be published for this.

## Good to know

- **Network.** The app runs in the Home Assistant network with ports 80, 443 and 443/udp published.
  Proxy hosts can target `homeassistant:8123` or any other app by its hostname.
- **Port 81** (admin interface over HTTPS) is off by default. The sidebar entry does not need it.
  OpenID Connect login and GoAccess need it.
- **Access to other apps' configuration.** To import the Community App's data directly, this app has
  read-only access to the configuration folders of all apps. It reads them only while a migration
  is configured and never writes to them. The mapping uses the legacy `addon_config` types, which every Supervisor
  version accepts. It is part of the app and cannot be switched off per installation; the code that uses it is in
  [`migration.sh`](npmplus/rootfs/usr/local/lib/npmplus-app/migration.sh).
- **Architectures.** amd64 and aarch64, the platforms NPMplus itself is built for. armv7, armhf and
  i386 (the legacy platforms of the base image) are not offered: NPMplus ships no binaries for them.
- **Two small changes to the admin interface** are made when the image is built: its router learns
  about the ingress path and it starts in dark mode instead of following the browser. The build
  fails if an upstream update moves the code these changes rely on, so they can never be skipped
  silently.

## Updates and development

- The NPMplus version is the `NPMPLUS_VERSION` build argument in
  [`npmplus/Dockerfile`](npmplus/Dockerfile). Renovate proposes new releases, and also new tags of the
  base image. The Alpine packages NPMplus needs are deliberately not pinned; they follow the base
  image's Alpine release.
- Options live in three places that [`options_consistency.py`](.github/checks/options_consistency.py)
  keeps in step: the schema in `config.yaml`, the translations and
  [`option-env.map`](npmplus/rootfs/usr/local/share/npmplus-app/option-env.map).
- [`runtime.sh`](.github/tests/runtime.sh) runs inside the built image: option mapping (including a
  check that every variable exists in the shipped NPMplus), storage, the migration with sample data,
  the ingress configuration and the interface patches.

## Credits

NPMplus is made by [ZoeyVid](https://github.com/ZoeyVid) on top of
[Nginx Proxy Manager](https://github.com/NginxProxyManager/nginx-proxy-manager) by jc21 and licensed
under AGPL-3.0 and MIT. The logo is the NPMplus logo.

<!-- support:begin (generated, shared text) -->
## Say thanks

All my projects are built in my spare time, just for the fun of it. Still, they take a lot of time and care, and many of the smart home gadgets I buy end up here because I want to make them cloud-free and smart-home ready. Every bit of support means a lot to me.

If my work helped you or turned out to be useful, show your appreciation with a hot drink for my next sleepless night.

[![PayPal](https://img.shields.io/static/v1?label=Support&message=PayPal&color=0070BA&logo=paypal&logoColor=white&style=for-the-badge)](https://paypal.me/seb5594) [![Buy me a beer](https://raw.githubusercontent.com/seb5594/Home-Assistant-Apps/473dc258f963096745aac327df54950eb9b59066/.github/assets/support-beer.svg)](https://buymeacoffee.com/seb5594)
<!-- support:end -->

<!-- license:begin (generated from the license file) -->
## License

[![license](https://img.shields.io/static/v1?label=license&message=Apache-2.0&color=5B6770&style=flat)](LICENSE)

Published under the [Apache License 2.0](LICENSE).
<!-- license:end -->
