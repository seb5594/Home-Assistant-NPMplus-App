# NPMplus für Home Assistant

[🇬🇧 English](README.md) · **🇩🇪 Deutsch**

> **Experimentell.** Die App ist neu. Die Ingress-Anbindung und der Import anderer
> Nginx-Proxy-Manager-Installationen wurden bisher nur mit Testdaten geprüft, mach also vor einer Migration
> ein Backup.

[NPMplus](https://github.com/ZoeyVid/NPMplus) als Home-Assistant-App: ein Reverse Proxy, der deine
Dienste mit kostenlosen Zertifikaten hinter HTTPS stellt. Verwaltet wird er in einer Weboberfläche,
die direkt in der Home-Assistant-Seitenleiste öffnet.

NPMplus ist ein Fork des Nginx Proxy Managers mit aktuellem nginx, HTTP/3, strengeren Voreinstellungen
und vielen Erweiterungen (Anmeldung per OpenID Connect, vorgeschaltete Authentifizierung, ...). Dieses
Repository verpackt es nur für Home Assistant; der Proxy selbst ist das unveränderte Upstream-Release auf
dem gemeinsamen [Home-Assistant-Base-Image](https://github.com/seb5594/home-assistant-base-multi-arch).

## Das bekommst du

- Die Admin-Oberfläche in der **Seitenleiste** über Ingress: kein zusätzlicher Port, geschützt durch
  deine Home-Assistant-Anmeldung, standardmäßig dunkel.
- **amd64 und aarch64** (Raspberry Pi 4/5, Home Assistant Green, Mini-PCs).
- Jede NPMplus-Einstellung aus der `compose.yaml` als geprüfte **App-Option**, gruppiert und
  beschrieben, dazu eine freie Liste für **beliebige weitere Umgebungsvariablen**.
- Einen **einmaligen Import deiner bestehenden Nginx-Proxy-Manager-Installation**, damit du nicht alles
  neu einrichten musst. Anleitungen für die [Community-App](docs/MIGRATION.de.md#a-nginx-proxy-manager-community-app)
  und für die [App von alexbelgium](docs/MIGRATION.de.md#b-alexbelgium-nginx-proxy-manager--static-web-server).
- Eigene nginx-Snippets und die Standardseite in einem **Ordner, den du erreichst**, per Samba oder
  File editor.
- Die Upstream-Version ist festgelegt und wird von Renovate aktuell gehalten.

## Installation

1. Füge dieses App-Repository mit dem Button in der englischen README zu Home Assistant hinzu und
   installiere **NPMplus**.
2. Starte die App, öffne **NPMplus** in der Seitenleiste und lege deinen Administrator an.
3. Leite die Ports 80 und 443 (TCP, und 443 UDP für HTTP/3) am Router auf Home Assistant weiter.
4. Lege deinen ersten Proxy-Host an.

Du kommst vom Nginx Proxy Manager? Lies die [Migrationsanleitung](docs/MIGRATION.de.md) **vor** dem
ersten Start.

## Umzug vom Nginx Proxy Manager

| Du nutzt | So geht's |
| --- | --- |
| **Nginx Proxy Manager** (Community Apps, stable oder Edge) | *Migration → Importieren aus* auf `community_app` (`community_app_edge` für Edge) setzen, die alte App stoppen, NPMplus starten. Die alten Daten werden direkt gelesen und nie verändert. |
| **Nginx Proxy Manager + Static Web Server** (alexbelgium) | Seine Daten liegen im privaten App-Speicher und werden einmal herauskopiert. Siehe [Anleitung B](docs/MIGRATION.de.md#b-alexbelgium-nginx-proxy-manager--static-web-server). |
| Docker oder etwas anderes | Die Daten in den Ordner `import` kopieren, siehe [Anleitung C](docs/MIGRATION.de.md#c-alles-andere). |

Hosts, Weiterleitungen, Streams, Benutzer, Zugriffslisten, Zertifikate, das Let's-Encrypt-Konto und
eigene nginx-Snippets ziehen mit um. Einen Weg zurück zum Nginx Proxy Manager gibt es nicht, mach also
vorher ein Backup.

## Proxy-Hosts in Home Assistant sehen

Die Community-Integration **[ha-npmplus](https://github.com/metaathron/ha-npmplus)** passt zu dieser
App: Sie macht deine Proxy-Hosts, Streams und Zertifikate zu Geräten und Entitäten, sodass du einen
Host ein- oder ausschalten oder das Ablaufdatum von Zertifikaten in Home Assistant verfolgen kannst.
Trage den Hostnamen der App ein (steht auf ihrer Info-Seite), Port `81`, einen NPMplus-Benutzer und
lass die SSL-Prüfung aus, weil Port 81 ein selbstsigniertes Zertifikat nutzt. Port 81 muss dafür nicht
veröffentlicht sein.

## Gut zu wissen

- **Netzwerk.** Die App läuft im Home-Assistant-Netzwerk, die Ports 80, 443 und 443/udp sind
  veröffentlicht. Proxy-Hosts können `homeassistant:8123` oder jede andere App über ihren Hostnamen
  ansprechen.
- **Port 81** (Admin-Oberfläche über HTTPS) ist standardmäßig aus. Der Seitenleisten-Eintrag braucht
  ihn nicht. OpenID-Connect-Anmeldung und GoAccess brauchen ihn.
- **Zugriff auf die Konfiguration anderer Apps.** Um die Daten der Community-App direkt zu
  importieren, darf diese App die Konfigurationsordner aller Apps lesen (nur lesend). Sie tut das nur,
  solange eine Migration eingestellt ist, und schreibt nie hinein. Die Zuordnung nutzt die alten `addon_config`-Typen, die jede
  Supervisor-Version akzeptiert. Sie gehört fest zur App und lässt sich nicht pro Installation abschalten; der Code, der sie nutzt, steht in
  [`migration.sh`](npmplus/rootfs/usr/local/lib/npmplus-app/migration.sh).
- **Architekturen.** amd64 und aarch64, die Plattformen, für die NPMplus selbst gebaut wird. armv7, armhf und
  i386 (die Legacy-Plattformen des Base-Images) gibt es nicht: NPMplus liefert dafür keine Binärdateien.
- **Eine App-Fußzeile** unter der Fußzeile der Admin-Oberfläche mit App-Version und Support-Links. Sie ist
  standardmäßig an; *Oberfläche → App-Fußzeile anzeigen* schaltet sie ab.
- **Ein schneller Seitenleisten-Eintrag.** Der nginx der App liefert die Dateien der Admin-Oberfläche selbst
  aus und reicht nur die API über den Unix-Socket an das NPMplus-Backend weiter. Die Dateien werden beim
  Bauen des Images einmal komprimiert, ein Request kostet also fast nichts.
- **Zwei kleine Änderungen an der Admin-Oberfläche** passieren beim Bau des Images: Ihr Router lernt den
  Ingress-Pfad kennen, und sie startet im dunklen Modus statt dem Browser zu folgen. Der Bau schlägt
  fehl, wenn ein Upstream-Update den Code verschiebt, auf den sich die Änderungen stützen. Sie können
  also nie unbemerkt wegfallen.

## Updates und Entwicklung

- Die NPMplus-Version ist das Build-Argument `NPMPLUS_VERSION` in
  [`npmplus/Dockerfile`](npmplus/Dockerfile). Renovate schlägt neue Versionen vor, auch neue Tags des
  Base-Images. Die Alpine-Pakete, die NPMplus braucht, sind bewusst nicht festgelegt; sie folgen der
  Alpine-Version des Base-Images.
- Optionen leben an drei Stellen, die [`options_consistency.py`](.github/checks/options_consistency.py)
  im Gleichschritt hält: das Schema in der `config.yaml`, die Übersetzungen und
  [`option-env.map`](npmplus/rootfs/usr/local/share/npmplus-app/option-env.map).
- [`runtime.sh`](.github/tests/runtime.sh) läuft im gebauten Image: Optionszuordnung (einschließlich
  der Prüfung, dass jede Variable im ausgelieferten NPMplus vorkommt), Speicher, die Migration mit
  Beispieldaten, die Ingress-Konfiguration und die Änderungen an der Oberfläche.

## Danksagung

NPMplus stammt von [ZoeyVid](https://github.com/ZoeyVid) und baut auf dem
[Nginx Proxy Manager](https://github.com/NginxProxyManager/nginx-proxy-manager) von jc21 auf; Lizenz
AGPL-3.0 und MIT. Das Logo ist das NPMplus-Logo.
