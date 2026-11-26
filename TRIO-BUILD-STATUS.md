# Trio per iPhone — verifica tecnica della release 1.0.2

## Sorgente e compilazione

- Sorgente originale: [nightscout/Trio v1.0.2](https://github.com/nightscout/Trio/releases/tag/v1.0.2).
- Commit fissato: `0b29cd53415e7f0e668677749cad8daf81c68c2f`.
- Build e log: [GitHub Actions](https://github.com/albertostab/haylou-cgm-ios/actions/runs/45726346192).
- Test `AlgorithmPackage`: **226 test in 32 suite passati** con Xcode 26.5.
- Archivio per dispositivo iPhone: **compilazione riuscita**, Xcode 26.5 (17F42).
- Nessun algoritmo, driver o parametro terapeutico personalizzato viene modificato.
- Nessun token Nightscout o credenziale Apple viene richiesto dalla compilazione.

Il branch `trio-unsigned-v1.0.2` contiene soltanto il controllo di compilazione:
il runner scarica la release ufficiale e i suoi submodule originali. Il repository
Haylou viene usato come contenitore CI, senza modificare la sua app o il protocollo BLE.

IPA ottenuta: `Trio-1.0.2-unsigned.ipa`, 54.625.871 byte, piattaforma iPhoneOS,
architettura arm64, versione 1.0.2 build 1, iOS minimo del binario 17.6.
SHA-256: `75472743fdaa89622507b031102e0bb828d4d0c941e16ccefa288f3622383e4e`.
Il download, l'integrità ZIP/IPA e la corrispondenza con il manifest sono stati
verificati sul PC. Nell'IPA sono presenti OmnipodKit e G7SensorKit.
Non ci sono firma o provisioning profile del bundle principale.

[Download artefatto GitHub (ZIP)](https://github.com/albertostab/haylou-cgm-ios/actions/runs/45726346192/artifacts/15074962532).
Il file è disponibile anche nella cartella locale `Diabete/Trio-output/`.
Gli identificativi sono ancora `org.nightscout.TRIOUNSIGN.trio` e
`group.org.nightscout.TRIOUNSIGN.trio.trio-app-group`: non sono quelli dell'utente.

## Omnipod 5 e Dexcom G7

La release 1.0.2 include il submodule OmnipodKit al commit
`043b91dbf1958d26c55d927a6a8d651bc91f208d`. Il [README di quella revisione](https://github.com/loopandlearn/OmnipodKit/blob/043b91dbf1958d26c55d927a6a8d651bc91f208d/README.md)
documenta esplicitamente Omnipod 5, DASH ed Eros. La nota delle FAQ Trio sul ramo
dedicato Omnipod 5 non corrisponde quindi al codice della release attuale.
Il [G7 è documentato come sorgente compatibile](https://triodocs.org/install/build/requirements/devices/cgm/#dexcom-g7-one).

Con Trio, l'algoritmo sull'iPhone controlla il Pod al posto di SmartAdjust.
Questo cambia il sistema terapeutico e la dipendenza dal telefono: non è una
semplice installazione alternativa dell'app ufficiale Omnipod 5.

## Stato della firma gratuita

La compilazione non usa certificati Apple. Il Team ID reale non è ancora disponibile:
`TRIOUNSIGN` è soltanto un identificativo temporaneo per il controllo di compilazione.
L'IPA e il relativo `provenance.json` lo dichiarano esplicitamente.

Per l'installazione vanno verificati il Team ID, la firma, gli App Groups e gli
identificativi effettivi. I permessi non si possono dedurre dal solo successo della
compilazione o dalla comparsa dell'icona sul telefono. Non sono stati rimossi
entitlement, estensioni o controlli per forzare l'installazione.

Sideloadly può firmare IPA con Apple ID gratuito; la firma dura 7 giorni.
Il [percorso gratuito documentato da Trio](https://triodocs.org/install/build/mac/build/#free-apple-developer-account-build)
usa Xcode su Mac e descrive le capability da disabilitare. Il percorso Browser Build
con TestFlight richiede Apple Developer Program a pagamento. Questa build Windows +
Sideloadly deve ancora essere verificata come percorso di installazione per Trio.

## Prove non eseguite

Il telefono non è attualmente collegabile. Non sono quindi verificati:

- Installazione e firma sull'iPhone 17 Pro Max con iOS 27.2.1.
- Avvio e persistenza dei dati dopo chiusura/riavvio/aggiornamento della firma.
- Ricezione reale del G7, allarmi, riconnessione e funzionamento in background.
- Associazione del Pod e ciclo di erogazione.

La build è destinata alla verifica tecnica. Nessun Pod deve essere associato
semplicemente per verificare se l'app si apre. La compilazione e i test software
non attestano l'affidabilità terapeutica sul dispositivo reale.
