# EVA-Apps

Ricos eigene iOS-Apps für iPhone und iPad, je Modul des EGIS-Datenbankarchivs eine App. Sie laufen am App Store vorbei:
gebaut als unsignierte IPA auf einem macOS-Läufer bei GitHub, signiert beim Aufspielen über SideStore, ausgeführt in
LiveContainer mit einer kostenlosen Apple-ID.

Quelle der Wahrheit ist der Ordner `apps/` im Repository des Archivs. Das öffentliche Repository `eva-apps` ist ein
Spiegel davon (`server/apps_spiegeln.sh`); dort wird nie von Hand geändert.

| Ordner | Inhalt |
|---|---|
| `_gemeinsam/` | Swift-Paket EVAGemeinsam: Archiv-Client, Anmeldung, Ablage |
| `weather/` | EVA WEATHER, Fenster auf das Modul WETTER |
| `_ci/` | Workflow des Bau-Läufers (im Spiegel unter `.github/workflows/`) |

Keine Geheimnisse, keine Analyse-Dienste, keine Fremd-Server. Das Token einer App kommt per QR-Code aufs Gerät und
liegt nur in dessen Schlüsselbund.
