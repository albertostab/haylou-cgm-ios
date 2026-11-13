# Haylou CGM – app nativa iPhone, senza Mac personale

**Stato:** prototipo sperimentale compilabile tramite GitHub Actions, **non ancora compilato su un runner macOS né provato su iPhone**. Non è un dispositivo medico, non sostituisce il sensore FreeStyle/LibreLink né i suoi allarmi.

## Cosa c'è già

- App nativa SwiftUI per iPhone, niente Bluefy né scheda web da lasciare aperta.
- API Nightscout `GET /api/v1/entries/sgv.json?count=3`, URL configurabile e token `readable` salvato **solo nel portachiavi del telefono**. Nessun token o indirizzo personale nel repository.
- Connessione Haylou RT2 LS10 tramite `CoreBluetooth`: ricerca, connessione, ripristino del dispositivo noto, riconnessione, servizi `000001FF`, `000002FF` e ascolto risposte `000003FF` / `000005FF`.
- Encoder meteo a quattro giorni con CRC16-XMODEM e checksum: **test offline contro il pacchetto esatto che ha mostrato 25 °C sul RT2 il 13/11/2026**.
- Trasmissione (solo dopo attivazione dall'utente) di ogni lettura valida e nuova. Blocco glicemie <40 o >260 mg/dL, letture più vecchie di 12 minuti, MTU insufficiente e differenza di visualizzazione >1.
- Conversione °F **approssimata e non univoca**; un test reale ha mostrato 179 °F per 82 °C. I dati non devono essere interpretati come valori medici esatti.
- Controllo ogni 60 secondi **solo mentre l'app esegue**. Modalità CoreBluetooth `bluetooth-central`, state restoration e richiesta `BGAppRefreshTask` per opportunità di aggiornamento quando iOS lo consente. **Nessuna garanzia di 60 secondi con iPhone bloccato.**
- Diagnostica che distingue **scrittura richiesta** da **ricezione/visualizzazione confermata**. La scrittura GATT `.withoutResponse` non ha conferma di consegna.

## Preparazione gratuita

1. Apri `https://github.com/new` e crea un repository denominato `haylou-cgm-ios`. Mettilo **Public** per usare gratuitamente i runner macOS di GitHub Actions. Non caricare mai token, password, log CGM o screenshot contenenti segreti.
2. Carica nel repository **il contenuto** di questo pacchetto, preservando `.github/workflows/build-ios.yml`. Se usi l'integrazione GitHub di ChatGPT, dopo aver creato il repository ChatGPT può aggiungere i file direttamente.
3. Vai nella scheda **Actions** del repository. Il workflow `Compila Haylou CGM IPA (senza Mac personale)` si avvia automaticamente dopo il push su `main`; puoi anche premere `Run workflow`.
4. Attendi che la build finisca. In fondo alla pagina del job scarica l'artefatto `HaylouCGM-unsigned-IPA` (un archivio ZIP di GitHub contenente `HaylouCGM-unsigned.ipa`). La firma avverrà sul PC Windows; **non usare l'IPA direttamente senza firmarlo**.
5. Su Windows installa **Sideloadly** da `https://sideloadly.io/` e i componenti Apple richiesti dalle sue istruzioni. Collega l'iPhone con cavo USB; abilita la fiducia nel PC e, se richiesto dal sistema, la Modalità sviluppatore. Seleziona il file IPA, inserisci un Apple ID con autenticazione a due fattori e installa.
6. Con un account Apple gratuito l'app scade normalmente dopo **7 giorni**. Sideloadly offre il rinnovo automatico dal PC se configurato e se l'iPhone è raggiungibile tramite USB/Wi-Fi. L'app non è disponibile pubblicamente sull'App Store.

> **Nota:** non ho accesso a Xcode in questo ambiente. Ho testato la sintassi Swift e il codec con Swift su Linux; la prima compilazione reale della app SwiftUI + CoreBluetooth sarà il job GitHub. Se segnala errori, incolla il log del job per correggerli.

## Primo avvio dell'app

1. Lascia Haylou Fun disconnessa dal Bluetooth durante il test e mantieni il watch in °F.
2. Inserisci URL HTTPS del tuo Nightscout e **un nuovo token** con ruolo `readable` (reimposta quello condiviso in precedenza). Tocca **Salva** e **Verifica lettura**.
3. Premi **Cerca orologio** e seleziona **Haylou RT2**. Se l'orologio non appare, controlla i permessi Bluetooth, scollega nRF Connect / Haylou Fun e riprova; evita reset o pairing non richiesti.
4. Verifica che la schermata mostri una glicemia recente e che sia nell'intervallo rappresentabile.
5. Attiva **Invia automaticamente nuove letture**. Il primo invio usa solo la lettura più recente; poi, mentre l'app è attiva, riprova il controllo ogni 60 secondi.
6. Fai i test di cambio app e schermo bloccato. Confronta l'orario dell'ultimo tentativo BLE con l'orario di aggiornamento realmente visto sull'RT2, **prima** di aprire nuovamente l'app.

## Sicurezza e limiti

- Il display dell'RT2 usa **°F al posto di mg/dL**. Può rappresentare solo circa 40–260 mg/dL e approssima/salta alcuni numeri. Non usare la lettura per insulina o per gestire ipo: affidati al Libre.
- Se l'app è sospesa, non può garantire l'eliminazione del numero precedente dal quadrante. Considera il dato sul watch **potenzialmente obsoleto in ogni momento**.
- `BGAppRefreshTask` usa un periodo minimo suggerito di 15 minuti, ma **iOS decide se/quando** eseguire; non si deve promettere una sincronizzazione periodica continua. `bluetooth-central` può risvegliare l'app per **eventi** BLE, non per nuove glicemie Nightscout a intervalli fissati.
- L'API Nightscout è HTTPS e il token è nell'URL della sola richiesta verso il tuo server. Evita di copiare URL autenticati o log con segreti.

## Struttura

- `HaylouCGM/WeatherCodec.swift`: encoder Protobuf/CRC, testato sui byte confermati dal watch.
- `HaylouCGM/BridgeModel.swift`: Nightscout, deduplica, Core Bluetooth, diagnostica.
- `HaylouCGM/KeychainStore.swift`: token Keychain.
- `HaylouCGM/HaylouCGMApp.swift`: interfaccia SwiftUI e background refresh.
- `HaylouCGM/Info.plist`: permessi e background modes.
- `project.yml`: progetto XcodeGen.
- `.github/workflows/build-ios.yml`: build macOS gratuita, IPA unsigned.
- `Tests/CodecSelfTest.swift`: test regressione contro frame realmente visualizzato.
