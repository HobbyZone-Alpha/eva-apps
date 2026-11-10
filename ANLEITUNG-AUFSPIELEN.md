# EVA-Apps aufs iPhone bringen: Schritt für Schritt

Stand 2026-11-10. Gilt für das iPhone 16 Pro und genauso für das iPad.

## Worum es geht, in drei Sätzen

Apple lässt Apps eigentlich nur aus dem App Store zu. Mit einer normalen, kostenlosen Apple-ID darf man aber eigene
Apps für sich selbst aufspielen, allerdings höchstens drei und jeweils nur für sieben Tage. Damit das reicht, kommt
ein einziges Hilfsprogramm aufs iPhone (**LiveContainer**, mit eingebautem **SideStore**), und alle EVA-Apps laufen
darin; SideStore verlängert die sieben Tage danach selbst, ohne Computer.

Einmal brauchst du den Windows-Rechner, danach nie wieder.

## Was du brauchst

- den Windows-11-Rechner und das USB-Kabel vom iPhone
- deine Apple-ID mit Passwort (dieselbe wie im App Store reicht; das Passwort genau so tippen, Groß- und Kleinschreibung zählt)
- rund 30 Minuten

Die Knöpfe in den Hilfsprogrammen heißen auf Englisch. Ich schreibe sie so, wie sie dort stehen, in »Anführungszeichen«.

## Teil 1: Vorbereitung am iPhone (2 Minuten)

1. App Store öffnen, **LocalDevVPN** suchen und laden:
   https://apps.apple.com/app/localdevvpn/id6755608044
   Das ist ein VPN, das nur mit dem eigenen iPhone spricht und keine Daten nach draußen schickt. SideStore braucht
   es zum Aufspielen und Verlängern.
2. Noch nicht öffnen, das kommt später.

## Teil 2: Vorbereitung am Rechner (10 Minuten)

1. **iTunes von Apple** laden und installieren (es liefert den Treiber für das iPhone):
   https://www.apple.com/itunes/download/win64
   Klappt das nicht, geht stattdessen die App **Apple Devices** aus dem Microsoft Store.
2. **iloader** laden und installieren (das Programm, das LiveContainer aufs iPhone bringt):
   https://github.com/nab138/iloader/releases/latest/download/iloader-windows-x64.msi
3. iPhone mit dem Kabel an den Rechner. Auf dem iPhone erscheint »Diesem Computer vertrauen?«: **Vertrauen** tippen,
   Code eingeben.

## Teil 3: LiveContainer aufspielen (5 Minuten)

1. Am Rechner **iloader** öffnen.
2. Mit deiner Apple-ID anmelden.
3. Dein iPhone in der Liste auswählen.
4. **»LiveContainer+SideStore«** wählen und warten, bis iloader fertig meldet. Das iPhone bleibt so lange am Kabel.

Danach liegt auf dem iPhone ein neues Symbol **LiveContainer**. Es startet noch nicht, das ist richtig so.

## Teil 4: Dem iPhone sagen, dass es dir vertrauen darf (5 Minuten)

1. **Einstellungen → Allgemein → VPN & Geräteverwaltung**.
2. Unter »Entwickler-App« (englisch »Developer App«) deine Apple-ID antippen.
3. **»Erlauben & Neustarten«** (»Allow & Restart«) tippen, Code eingeben. Das iPhone startet neu.
4. Nach dem Neustart: **Einstellungen → Datenschutz & Sicherheit**, ganz nach unten scrollen, **Entwicklermodus**
   einschalten. Das iPhone startet noch einmal neu und fragt danach, ob der Entwicklermodus an bleiben soll:
   **Einschalten** tippen, Code eingeben.

Den Rechner und das Kabel brauchst du ab jetzt nicht mehr.

## Teil 5: SideStore einmal einrichten (5 Minuten)

1. **LocalDevVPN** öffnen und **»Connect«** tippen. Fragt das iPhone nach »VPN-Konfigurationen hinzufügen«:
   **Erlauben**, Code eingeben.
2. **LiveContainer** öffnen. Oben links **»SideStore«** antippen.
3. In SideStore unten **Einstellungen** öffnen und dort mit deiner Apple-ID anmelden. Auch wenn sie schon angemeldet
   wirkt: einmal abmelden und neu anmelden.
4. In SideStore **»My Apps«** öffnen und **»Refresh All«** tippen. Kurz warten.
5. SideStore schließen (vom unteren Rand nach oben wischen) und **LiveContainer** wieder öffnen.
6. In LiveContainer **Einstellungen → »Import Certificate from SideStore«** tippen, dann **»OK«**.
   Steht danach dort **»Remove Certificate«**, hat es geklappt.

## Teil 6: EVA WEATHER holen und starten (2 Minuten)

1. Auf dem iPhone in **Safari** diesen Link öffnen und den Download erlauben:
   https://github.com/HobbyZone-Alpha/eva-apps/releases/download/weather-latest/EVAWeather.ipa
   Die Datei landet in der App **Dateien**, Ordner **Downloads**.
2. **LiveContainer** öffnen, oben rechts auf **+** tippen, **EVAWeather.ipa** aus den Downloads wählen.
3. In der Liste erscheint **EVA WEATHER**. Antippen, dann **»Run«**.

## Alle sieben Tage

SideStore verlängert von allein im Hintergrund, solange **LocalDevVPN** verbunden ist. Wenn eine App nicht mehr startet
oder sich SideStore meldet: LocalDevVPN öffnen, »Connect«, dann in LiveContainer oben links »SideStore«, »My Apps«,
»Refresh All«. Das ist alles.

## Eine neue Fassung einer EVA-App

Neuer Bau heißt: denselben Link aus Teil 6 noch einmal laden und in LiveContainer wieder mit **+** einspielen. Die
Anmeldung der App bleibt erhalten.

## Was ich von dir zurück brauche

Schreib mir einfach, wie weit du gekommen bist. Am meisten hilft:

1. Welche iOS-Version zeigt **Einstellungen → Allgemein → Info**?
2. Hat iloader »LiveContainer+SideStore« ohne Fehler aufgespielt? Wenn nicht: die Fehlermeldung abfotografieren.
3. Steht in LiveContainer nach Teil 5 »Remove Certificate«?
4. Startet EVA WEATHER in LiveContainer?
5. Ab der Fassung mit Anmeldung (P3): Öffnet »Code scannen« die Kamera?
6. Nach einer Woche: Startet EVA WEATHER noch, ohne dass du etwas getan hast?

## Was ich nicht gemessen habe

- Die Anleitungen von SideStore nennen ausdrücklich nur iOS bis 18. Ob auf iOS 26 alles genau so heißt, zeigt erst dein
  Versuch. Hakt ein Schritt, schick mir ein Foto vom Bildschirm.
- Ob die Kamera in LiveContainer funktioniert, ist offen. Dafür hat EVA WEATHER zusätzlich den Knopf »Code aus der
  Zwischenablage«.

Quellen: https://docs.sidestore.io/docs/installation/install, https://docs.sidestore.io/docs/faq,
https://livecontainer.github.io/docs/installation/lc_sidestore
