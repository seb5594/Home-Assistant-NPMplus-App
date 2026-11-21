# NPMplus

[NPMplus](https://github.com/ZoeyVid/NPMplus) is a reverse proxy with a web interface: you point
domain names at your services (Home Assistant, a NAS, a Docker container, ...), and NPMplus takes
care of HTTPS with free certificates. It is a fork of Nginx Proxy Manager with a newer nginx,
HTTP/3, more security by default and many extra features.

## First steps

1. Start the app and open **NPMplus** in the sidebar.
2. Create the administrator account when asked. (To skip the wizard, set the initial administrator
   under **Accounts and sessions** before the first start.)
3. Forward ports **80** and **443** (TCP, and 443 UDP for HTTP/3) from your router to your Home
   Assistant machine.
4. Add a proxy host in NPMplus and request a certificate for it.

Coming from Nginx Proxy Manager? Your hosts, users and certificates can be taken over, see
[Migration](#migration).

## The admin interface

The sidebar entry shows the NPMplus interface through Home Assistant's ingress: it needs no
extra port and is protected by your Home Assistant login. The interface starts in dark mode; the
switch in its header changes that, and the choice is remembered.

Optionally the interface is also reachable over HTTPS on port 81, with a self-signed certificate.
That port is off by default; enable it under **Network** in the app configuration if you want
it, for example to use the API or OpenID Connect login.

## Ports

| Port | Purpose |
| --- | --- |
| `80/tcp` | HTTP, also used by certificate validation (HTTP-01) |
| `443/tcp` | HTTPS |
| `443/udp` | HTTP/3 (QUIC) |
| `81/tcp` | Admin interface over HTTPS, off by default |

The host side of each port can be changed under **Network** in the app configuration.

## Configuration

Every option has a description in the app configuration. They follow the environment variables
of the NPMplus `compose.yaml` and are grouped: certificates, network, nginx, logs, accounts,
OpenID Connect, forward authentication and the interface. Options you leave empty keep the
NPMplus default.

### Any other variable

NPMplus knows more settings than this app has options for. **Advanced → Additional environment
variables** takes any number of them, one `NAME=value` per entry, for example:

```yaml
advanced:
  extra_environment:
    # Let the admin interface listen on localhost only: reachable through the sidebar entry,
    # but no longer from other apps or over port 81.
    - NPM_LISTEN_LOCALHOST=true
```

They are applied last and override the options above. The variables are listed in the
[`compose.yaml`](https://github.com/ZoeyVid/NPMplus/blob/develop/compose.yaml) of NPMplus.

## Storage

Everything NPMplus stores (hosts, users, certificates, logs) is kept in the app's private data
and is part of every Home Assistant backup of this app. Only the following folders are visible,
because you may want to edit them. Open them with the Samba or File editor app in
`addon_configs/<repository id>_npmplus`:

| Folder | Content |
| --- | --- |
| `custom_nginx` | Your own nginx snippets (`http.conf`, `server_proxy.conf`, ...), see the NPMplus README |
| `html` | Files of the built-in default web page |
| `import` | Data of an old installation to import, see below |

## Migration

NPMplus can take over an existing Nginx Proxy Manager setup once: proxy hosts, redirections,
streams, users, access lists, certificates (also the Let's Encrypt account) and your custom nginx
snippets. The step by step guide is in the
[migration guide](https://github.com/seb5594/Home-Assistant-NPMplus-App/blob/dev/docs/MIGRATION.md);
in short:

1. Make a backup. A migration back to Nginx Proxy Manager is not possible.
2. Set **Migration → Import from** to `community_app` (the Home Assistant Community App),
   `community_app_edge` (its edge version) or `import_folder` (anything else).
3. Stop the old app and start NPMplus.

The old data is only read, never changed. Nothing is imported once NPMplus has data of its own.

> **Note on access:** to read the Community App's data, this app has read-only access to the
> configuration folders of all apps (the `all_addon_configs` mapping). It touches them only while a migration is
> configured.

## Home Assistant behind NPMplus

Add a proxy host that forwards to `homeassistant` on port `8123` (scheme `http`) with websockets
enabled, and tell Home Assistant to trust the proxy in `configuration.yaml`:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 172.30.33.0/24
```

## See your proxy hosts in Home Assistant

The community integration [ha-npmplus](https://github.com/metaathron/ha-npmplus) shows your proxy
hosts, streams and certificates as devices and lets you switch hosts on and off from Home
Assistant. When you set it up, enter:

- **Host:** the hostname of this app, shown on its Info page (for example `4c7fee11-npmplus`),
- **Port:** `81`,
- the email and password of an NPMplus user, and turn off the verification of the SSL
  certificate: port 81 uses a self-signed one.

Port 81 does not have to be enabled for this; Home Assistant reaches it over the internal network.

## Limitations

- OpenID Connect login and GoAccess statistics need the direct HTTPS port, not the sidebar entry.
- Starting with a database written by a newer Nginx Proxy Manager than NPMplus supports is not
  possible; the import stops with a message instead of damaging anything.

## Credits

NPMplus is made by [ZoeyVid](https://github.com/ZoeyVid) on top of Nginx Proxy Manager by
[jc21](https://github.com/NginxProxyManager/nginx-proxy-manager). This app only packages it for
Home Assistant. The app is made by Sebastian Schmidt.
