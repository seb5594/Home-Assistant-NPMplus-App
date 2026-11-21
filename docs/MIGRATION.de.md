# Umzug auf NPMplus

Diese Anleitung überträgt eine bestehende **Nginx-Proxy-Manager**-Installation auf die NPMplus-App:
Proxy-Hosts, Weiterleitungs- und 404-Hosts, Streams, Benutzer, Zugriffslisten, Zertifikate
(einschließlich des Let's-Encrypt-Kontos, es wird also nichts neu angefordert) und deine eigenen
nginx-Snippets.

[English version](MIGRATION.md)

## Bevor es losgeht

- **Erstelle ein Backup** (Einstellungen → System → Backups), das die alte App enthält. Ein Weg
  zurück zum Nginx Proxy Manager ist nicht möglich; mit dem Backup kannst du aber jederzeit zurück.
- **Die alten Daten werden nur gelesen, nie verändert.** Geht etwas schief, stoppst du NPMplus und
  startest die alte App wieder.
- Beide Apps wollen die Ports 80 und 443. Stoppe die alte App (und schalte *Beim Booten starten*
  aus), bevor du NPMplus startest.
- NPMplus lehnt eine Datenbank ab, die von einem **neueren** Nginx Proxy Manager geschrieben wurde,
  als es selbst enthält. Diese App liefert NPMplus auf Basis von Nginx Proxy Manager 2.15; Datenbanken
  von 2.16 (die aktuelle Community-App) funktionieren. Steht im Protokoll *„written by a newer Nginx
  Proxy Manager"*, wurde nichts importiert: warte auf ein App-Update oder starte ohne Import.
- Der Import passiert **einmalig**: Sobald NPMplus eigene Daten hat, wird die Einstellung ignoriert
  (das Protokoll weist darauf hin). Für einen erneuten Import deinstallierst du NPMplus (dabei
  werden dessen Daten gelöscht) und beginnst von vorn.

Welche App nutzt du?

| Deine bisherige App | Anleitung |
| --- | --- |
| **Nginx Proxy Manager** (Home Assistant Community Apps, stable oder Edge) | [A: automatisch](#a-nginx-proxy-manager-community-app) |
| **Nginx Proxy Manager + Static Web Server** (alexbelgium) | [B: aus der laufenden App](#b-alexbelgium-nginx-proxy-manager--static-web-server) |
| Docker, andere App, anderer Rechner | [C: manuell kopieren](#c-alles-andere) |

## A: Nginx Proxy Manager (Community-App)

Die Community-App legt ihre Daten in ihrem Konfigurationsordner ab. NPMplus kann diesen Ordner
direkt lesen, es muss also nichts kopiert werden.

Die Community Apps haben ein Stable- und ein Edge-Repository, und die App gibt es in beiden. Wähle
`community_app` für die stabile und `community_app_edge` für die Edge-Variante; jede liest nur ihre
eigenen Daten, beide können also installiert bleiben. Die Edge-Version folgt dem neuesten Nginx Proxy
Manager, ihre Datenbank kann daher neuer sein, als NPMplus unterstützt (siehe
[Bevor es losgeht](#bevor-es-losgeht)).

1. Installiere **NPMplus**, starte es aber noch nicht.
2. Öffne die **Konfiguration**, klappe **Migration** auf und setze **Importieren aus** auf
   `community_app` (`community_app_edge` für die Edge-Version). Stelle gleich alles ein, was du sonst noch willst (zum Beispiel die
   ACME-E-Mail-Adresse).
3. **Stoppe** die App Nginx Proxy Manager und schalte *Beim Booten starten* aus.
4. **Starte** NPMplus und sieh ins Protokoll. Dort steht:

   ```
   [INFO] Importing Nginx Proxy Manager data from /addon_configs/a0d7b954_nginxproxymanager
   [INFO] Imported access
   [INFO] Imported letsencrypt
   ...
   [INFO] Import finished. You can set migration.source to none now.
   ```

5. Öffne **NPMplus** in der Seitenleiste und melde dich mit deiner **alten E-Mail-Adresse und dem
   alten Passwort** an.
6. Stelle **Importieren aus** wieder auf `none` (sonst erinnert dich das Protokoll bei jedem Start).
7. Gehe [Nach dem Import](#nach-dem-import) durch. Lass die alte App einige Tage installiert (und
   gestoppt); entferne sie, wenn du sicher bist.

Hast du die Community-App mehrfach installiert oder wird der Ordner nicht gefunden, sagt dir das
Protokoll Bescheid; nimm dann [Anleitung C](#c-alles-andere).

## B: alexbelgium Nginx Proxy Manager + Static Web Server

Diese App legt ihre Daten im privaten App-Speicher von Home Assistant ab, den keine andere App
lesen kann. Die Daten müssen deshalb einmal herauskopiert werden. Am einfachsten geht das mit der
App **Advanced SSH & Web Terminal** bei ausgeschaltetem *Schutzmodus* (dann kann sie mit Docker
sprechen):

1. Installiere NPMplus, setze **Migration → Importieren aus** auf `import_folder` und starte es
   einmal. Es bricht mit *„No database.sqlite in .../import"* ab: das ist erwartet und hat den
   Import-Ordner angelegt. (Starte NPMplus nicht ohne diese Einstellung: es würde eine leere
   Datenbank anlegen, und NPMplus überschreibt eigene Daten nie.)
2. Öffne die Info-Seite der alten App und notiere ihren Slug aus der Adresse, zum Beispiel
   `db21ed7f_nginx_webserver_proxy`. Notiere auch den Ordnernamen von NPMplus unter
   `addon_configs`, zum Beispiel `4c7fee11_npmplus`.
3. **Lass die alte App laufen** und ändere nichts darin. Im Terminal:

   ```bash
   docker cp addon_db21ed7f_nginx_webserver_proxy:/data/. /addon_configs/4c7fee11_npmplus/import/
   ```

   (Eine gestoppte App hat keinen Container mehr, deshalb muss sie für diesen einen Schritt laufen.)
4. Prüfe, dass `import/database.sqlite` existiert. Die Kopie stammt aus der laufenden Datenbank;
   NPMplus prüft sie vor dem Import und lehnt eine beschädigte Kopie ab, ohne etwas zu verändern.
5. **Stoppe** die alte App, schalte *Beim Booten starten* aus und **starte** NPMplus. Weiter mit
   Schritt 5 aus [Anleitung A](#a-nginx-proxy-manager-community-app).

Der Webserver-Teil dieser App (ihre `static_site_*`-Optionen) gehört nicht zum Nginx Proxy Manager
und wird nicht importiert. NPMplus liefert statische Dateien selbst aus: lege einen Proxy-Host an
oder lege Dateien in den Ordner `html` für die Standardseite.

Ohne Docker-Zugriff kannst du den Ordner `data` auch aus einem Home-Assistant-Backup der alten App
holen (Backup herunterladen, darin das App-Archiv entpacken; verschlüsselte Backups brauchen dein
Notfall-Kit) und dessen Inhalt in den Ordner `import` legen.

## C: alles andere

Bei Docker-Installationen, anderen Apps oder einem anderen Rechner kopierst du deine
Nginx-Proxy-Manager-Ordner in den Ordner `import` von NPMplus
(`addon_configs/<Repository-ID>_npmplus/import`, erreichbar mit der Samba- oder File-editor-App), so
dass er so aussieht:

```
import/
├── database.sqlite        erforderlich
├── access/                optional: Passwörter der Zugriffslisten
├── custom_ssl/            optional: selbst hochgeladene Zertifikate
├── letsencrypt/           optional: der Inhalt deines /etc/letsencrypt
└── nginx/
    ├── custom/            optional: deine eigenen nginx-Snippets
    └── default_www/       optional: die Seite des Standard-Hosts
```

Bei der üblichen Docker-Installation ist `data/` dein eingebundener Ordner `/data` und `letsencrypt/`
dein eingebundener Ordner `/etc/letsencrypt`. Setze dann **Migration → Importieren aus** auf
`import_folder`, stoppe die alte Installation und starte NPMplus. (Existiert der Ordner noch nicht,
starte NPMplus zuerst einmal mit dieser Einstellung; siehe Anleitung B.)

## Was passiert

| Nginx Proxy Manager | In NPMplus |
| --- | --- |
| `database.sqlite` | Per SQLite-Sicherungsfunktion nach einer Integritätsprüfung kopiert |
| `access/`, `custom_ssl/` | Kopiert |
| `letsencrypt/` | Kopiert; die Pfade in den Erneuerungsdateien werden umgeschrieben, damit Erneuerungen weiter funktionieren |
| `nginx/custom/` | Nach `custom_nginx` kopiert, den du im Konfigurationsordner der App bearbeiten kannst |
| `nginx/default_www/` | Nach `html` kopiert |
| Host-Konfigurationen unter `nginx/` | Nicht kopiert; NPMplus schreibt sie aus der Datenbank neu |
| Protokolle, Anmelde-Sitzungen | Nicht kopiert; du musst dich neu anmelden |

## Nach dem Import

NPMplus hat viele Formulare gegenüber dem Nginx Proxy Manager geändert, gehe die Hosts also einmal
durch:

- Öffne jeden Proxy-Host und prüfe seine Einstellungen. Mit den alten Formularen angelegte Hosts
  müssen eventuell erneut gespeichert werden.
- Ein Host, der an einen anderen NPMplus oder Nginx Proxy Manager weiterleitet, muss **https** als
  Schema verwenden.
- Gravatar-Profilbilder laden wieder, wenn jeder Benutzer sein Profil öffnet und speichert.
- Deine **eigenen nginx-Snippets** laufen jetzt auf einem neueren nginx. Startet NPMplus nicht und
  nennt das Protokoll eine Datei in `custom_nginx`, korrigiere oder entferne diese Datei.
- Prüfe, ob die Zertifikatserneuerung funktioniert: erneuere in der Zertifikatsliste ein
  Zertifikat von Hand.

Die Hinweise von NPMplus zur Migration stehen im
[NPMplus-README](https://github.com/ZoeyVid/NPMplus#migration-from-upstreamvanilla-nginx-proxy-manager).

## Probleme

| Meldung im Protokoll | Bedeutung |
| --- | --- |
| `No data of the Nginx Proxy Manager app found` | Die gewählte Variante ist nicht installiert oder ihre Daten fehlen. Existiert die andere Variante, nennt die Meldung deren Ordner; sonst nimm Anleitung C. |
| `No database.sqlite in .../import` | Der Import-Ordner ist leer oder die Daten liegen eine Ebene zu tief. |
| `written by a newer Nginx Proxy Manager` | Siehe [Bevor es losgeht](#bevor-es-losgeht). Es wurde nichts verändert. |
| `NPMplus already has data, so the import ... is skipped` | Der Import ist erledigt oder nicht nötig; stelle **Importieren aus** auf `none`. |
