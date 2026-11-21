# Migrating to NPMplus

This guide moves an existing **Nginx Proxy Manager** setup to the NPMplus app: proxy hosts,
redirection and 404 hosts, streams, users, access lists, certificates (including the Let's Encrypt
account, so nothing is requested again) and your custom nginx snippets.

[Deutsche Version](MIGRATION.de.md)

## Before you start

- **Make a backup** (Settings → System → Backups) that includes the old app. A migration back to
  Nginx Proxy Manager is not possible; with the backup you can always return.
- **The old data is only read, never changed.** If something goes wrong, stop NPMplus and start the
  old app again.
- Both apps want ports 80 and 443. Stop (and disable *Start on boot* of) the old app before you
  start NPMplus.
- NPMplus refuses a database written by a **newer** Nginx Proxy Manager than it contains.
  This app ships NPMplus based on Nginx Proxy Manager 2.15; databases of 2.16 (the current
  Community App) work. If you see *"written by a newer Nginx Proxy Manager"* in the log, nothing
  was imported: wait for an app update, or start without an import.
- The import happens **once**: as soon as NPMplus has data of its own, the setting is ignored
  (the log says so). To import again, uninstall NPMplus (this deletes its data) and start over.

Which app do you have?

| Your current app | Guide |
| --- | --- |
| **Nginx Proxy Manager** (Home Assistant Community Apps, stable or edge) | [A: automatic](#a-nginx-proxy-manager-community-app) |
| **Nginx Proxy Manager + Static Web Server** (alexbelgium) | [B: from the running app](#b-alexbelgium-nginx-proxy-manager--static-web-server) |
| Docker, another app, another machine | [C: manual copy](#c-anything-else) |

## A: Nginx Proxy Manager (Community App)

The Community App keeps its data in its configuration folder. NPMplus can read that folder
directly, so there is nothing to copy.

The Community Apps have a stable and an edge repository, and the app exists in both. Choose
`community_app` for the stable one and `community_app_edge` for the edge one; each reads only its own
data, so both can stay installed. The edge version follows the newest Nginx Proxy Manager, so its
database may be newer than NPMplus supports (see [Before you start](#before-you-start)).

1. Install **NPMplus** but do not start it yet.
2. Open its **Configuration**, expand **Migration** and set **Import from** to `community_app`
   (`community_app_edge` for the edge version).
   Set anything else you want while you are here (for example the ACME email address).
3. **Stop** the Nginx Proxy Manager app and turn off *Start on boot*.
4. **Start** NPMplus and read its log. You should see:

   ```
   [INFO] Importing Nginx Proxy Manager data from /addon_configs/a0d7b954_nginxproxymanager
   [INFO] Imported access
   [INFO] Imported letsencrypt
   ...
   [INFO] Import finished. You can set migration.source to none now.
   ```

5. Open **NPMplus** in the sidebar and log in with your **old email and password**.
6. Set **Import from** back to `none` (otherwise the log reminds you on every start).
7. Work through [After the import](#after-the-import). Keep the old app installed (stopped) for a
   few days; remove it when you are sure.

If you installed the Community App more than once, or the folder is not found, the log tells you;
use [guide C](#c-anything-else) then.

## B: alexbelgium Nginx Proxy Manager + Static Web Server

This app keeps its data in Home Assistant's private app storage, which no other app can read. The
data has to be copied out once. The simplest way is the **Advanced SSH & Web Terminal** app with
*Protection mode* switched off (it can then talk to Docker):

1. Install NPMplus, set **Migration → Import from** to `import_folder` and start it once. It stops
   with *"No database.sqlite in .../import"*: that is expected, and it created the import folder.
   (Do not start NPMplus without this setting first: it would create an empty database, and
   NPMplus never overwrites its own data.)
2. Open the Info page of the old app and note its slug in the address, for example
   `db21ed7f_nginx_webserver_proxy`. Note the folder name of NPMplus in `addon_configs`, for
   example `4c7fee11_npmplus`.
3. **Leave the old app running** and do not change anything in it. In the terminal:

   ```bash
   docker cp addon_db21ed7f_nginx_webserver_proxy:/data/. /addon_configs/4c7fee11_npmplus/import/
   ```

   (A stopped app has no container left, which is why it has to run for this one step.)
4. Check that `import/database.sqlite` exists. The copy is taken from the live database; NPMplus
   verifies it before importing and refuses a damaged copy without changing anything.
5. **Stop** the old app, turn off *Start on boot* and **start** NPMplus. Continue with step 5 of
   [guide A](#a-nginx-proxy-manager-community-app).

The static web server part of that app (its `static_site_*` options) is not part of Nginx Proxy
Manager and is not imported. NPMplus serves static files itself: create a proxy host, or put files
into the `html` folder for the default page.

Without Docker access you can also take the folder `data` out of a Home Assistant backup of the
old app (download the backup, unpack the app archive inside it; encrypted backups need your
emergency kit) and place its content in the `import` folder.

## C: anything else

For Docker installations, other apps or another machine, copy your Nginx Proxy Manager folders into
the `import` folder of NPMplus (`addon_configs/<repository id>_npmplus/import`, reachable with the
Samba or File editor app) so that it looks like this:

```
import/
├── database.sqlite        required
├── access/                optional: access list passwords
├── custom_ssl/            optional: certificates you uploaded
├── letsencrypt/           optional: the content of your /etc/letsencrypt
└── nginx/
    ├── custom/            optional: your custom nginx snippets
    └── default_www/       optional: the default site page
```

With the usual Docker setup, `data/` is your mounted `/data` folder and `letsencrypt/` your mounted
`/etc/letsencrypt` folder. Then set **Migration → Import from** to `import_folder`, stop the old
installation and start NPMplus. (If the folder does not exist yet, start NPMplus once with that
setting first; see guide B.)

## What happens

| Nginx Proxy Manager | In NPMplus |
| --- | --- |
| `database.sqlite` | Copied through SQLite's backup function after an integrity check |
| `access/`, `custom_ssl/` | Copied |
| `letsencrypt/` | Copied; the paths in the renewal files are rewritten so renewals keep working |
| `nginx/custom/` | Copied to `custom_nginx`, which you can edit in the app's configuration folder |
| `nginx/default_www/` | Copied to `html` |
| host configs below `nginx/` | Not copied; NPMplus writes them again from the database |
| logs, login sessions | Not copied; you have to log in again |

## After the import

NPMplus changed many forms compared to Nginx Proxy Manager, so go through the hosts once:

- Open each proxy host and check its settings. Hosts that were created with the old forms may
  need to be saved again.
- A host that forwards to another NPMplus or Nginx Proxy Manager must use **https** as the scheme.
- Profile pictures from Gravatar load again after each user opens their profile and saves it.
- Your **custom nginx snippets** now run on a newer nginx. If NPMplus does not start and the log
  names a file in `custom_nginx`, fix or remove that file.
- Check that certificate renewal works: in the certificate list, renew one certificate by hand.

The upstream notes on the migration are in the
[NPMplus README](https://github.com/ZoeyVid/NPMplus#migration-from-upstreamvanilla-nginx-proxy-manager).

## Problems

| Message in the log | Meaning |
| --- | --- |
| `No data of the Nginx Proxy Manager app found` | The chosen variant is not installed, or its data is not there. The message names a folder of the other variant if that exists; otherwise use guide C. |
| `No database.sqlite in .../import` | The import folder is empty or has the data one level too deep. |
| `written by a newer Nginx Proxy Manager` | See [Before you start](#before-you-start). Nothing was changed. |
| `NPMplus already has data, so the import ... is skipped` | The import is done or not needed; set **Import from** to `none`. |
