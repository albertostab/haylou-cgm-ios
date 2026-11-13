# Haylou CGM · prototipo quadrante RT2 (LS10)

## Stato verificato

- Il modello **Haylou RT2 LS10** è pubblicizzato con schermo **360×360 px** (vedere scheda RT2 haylou.info e manuale LS10); il background allegato ha questa dimensione. Ho incluso un'alternativa 240×240 solo per eventuali interfacce che richiedano quella risoluzione.
- Hello Haylou documenta supporto ai quadranti `.tbwf` per RT2 LS10 e offre **editor e upload su Android**. Non è un editor iOS.
- Haylou Fun ufficiale su iOS documenta il quadrante personalizzato tramite **foto/immagine**, che è una prima prova possibile direttamente dal tuo iPhone.
- **Nessun file `.tbwf` è stato generato né caricato sul RT2** in questa versione: i PNG sono fondi grafici da usare nel custom dial ufficiale. Il PNG non trasmette dati glicemici e non cambia da solo con Nightscout.
- I campi meteo del firmware e la home watchface sono due superfici diverse. I quadranti `.tbwf` documentati NON offrono il caricamento libero di icone meteo come i vecchi `.bin`; non promettere che sostituire l'icona comporti la comparsa della glicemia sulla home.

## Prova prudente con iPhone (senza Android)

1. Salva `HaylouCGM_RT2_sfondodial_360.png` nell'app Foto dell'iPhone.
2. **Interrompi temporaneamente la sessione Bluetooth in Haylou CGM Native**, per evitare due app connesse contemporaneamente.
3. Apri l'app ufficiale Haylou Fun e connetti l'RT2; apri le impostazioni del dispositivo, sezione **Quadranti / Dial setting → Quadrante personalizzato / Custom dial**.
4. Seleziona il PNG come sfondo, regola la posizione dell'**orologio nativo** evitando di coprire le scritte e sincronizza. Non caricare firmware o file sconosciuti.
5. Riconnetti Haylou CGM Native e verifica il meteo come in precedenza.

**Non aspettarti la glicemia in home con questo sfondo**: nella versione attuale il valore sperimentale continua a comparire soltanto nell'area meteo dell'orologio, con l'etichetta °F e con possibili ritardi.

## Percorso per un quadrante con dati dinamici

1. Procurarsi un file **`.tbwf` già funzionante** sull'RT2, preferibilmente uno con temperatura meteorologica dinamica nel quadrante.
2. Aprirlo in **Hello Haylou su un dispositivo Android fisico** e verificare cosa si possa modificare: posizione del numero, icone, testo delle unità.
3. Verificare che il numero meteo ricevuto via BLE dalla nostra app si mostri effettivamente sul quadrante personalizzato, non solo nel pannello meteo dell'RT2.
4. Solo dopo questa prova, investigare l'upload `.tbwf` dal nostro client iOS mediante catture BLE di un upload ufficiale, senza indovinare comandi di flash. Il formato `.tbwf` e la scrittura a chunk non sono equivalenti alla scrittura meteo CMD 26 già verificata.

## Link documentati

- Hello Haylou elenco modelli: https://hello-haylou.web.app/page/watch-faces
- Funzionalità editor: https://hello-haylou.web.app/page/features
- Upload TBWF da Android: https://www.watchfacebook.com/how-to-install-tbwf-file-on-watch/
- Limitazione icone meteo BIN vs TBWF: https://www.watchfacebook.com/forum/viewtopic.php?t=9
- Specifiche RT2 (360 × 360): https://haylou.info/rt2.html

**Sicurezza:** nessun display sperimentale dell'RT2 sostituisce FreeStyle Libre e i suoi allarmi; un valore vecchio può rimanere visibile anche quando l'app si interrompe. Non usare il quadrante per decidere dosi insuliniche.
