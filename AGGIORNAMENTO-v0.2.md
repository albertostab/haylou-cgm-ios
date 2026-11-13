# Haylou CGM Native v0.2 · Diagnostica risvegli BLE

**Stato:** preparato e validato con il parser Swift e con il test offline del codec, non ancora compilato con Xcode né verificato su iPhone.

## Cambiamenti

- Nessuna modifica al protocollo meteo Haylou RT2, al CRC o all'accesso Nightscout.
- Le caratteristiche NOTIFY/INDICATE erano già sottoscritte nella v0.1; la v0.2 sfrutta anche i callback per **tentare un controllo Nightscout** quando una notifica BLE arriva in background.
- Un massimo di un controllo guidato da BLE ogni 75 secondi e almeno 55 secondi dopo l'ultimo tentativo: evita polling incontrollato e loop di eco.
- Controllo in background con timeout HTTP di 8 secondi, adatto alla breve finestra di esecuzione concessa da iOS dopo gli eventi BLE.
- Registro locale degli ultimi 40 eventi (app, collegamento/disconnessione, BLE, tentativi Nightscout, richieste di scrittura), con ultimi 15 visibili nella diagnostica.
- Timestamp distinti per ultimo tentativo Nightscout, ultima risposta, ultima notifica BLE e ultima scrittura Bluetooth richiesta.
- Protezione da doppia chiamata `BGAppRefreshTask.setTaskCompleted` quando scade il task prima della risposta HTTP.
- Versione applicazione aumentata a 0.2.0.

## LIMITI importanti

- **Non ci sono garanzie di un evento BLE spontaneo**: se il watch non ne invia, non ci saranno risvegli guidati dal BLE. Un ACK del watch in risposta a un nostro invio non equivale a un evento BLE periodico autonomo.
- iOS non concede `Timer` ogni 60 secondi quando l'app è sospesa. `BGAppRefreshTask` viene eseguito quando decide il sistema, non ogni 15 minuti.
- Dopo una chiusura manuale dell'app dal multitasking l'eventuale risveglio dipende anche dalle regole di iOS 26 e dai framework usati; non fare affidamento sul riavvio automatico.
- La scrittura `withoutResponse` è una **richiesta**, non prova che il display mostri una lettura aggiornata.
- La glicemia sul RT2 è **approssimata con °F** e può rimanere vecchia: non utilizzarla per decisioni terapeutiche o al posto degli allarmi Libre.

## Prova sul telefono

1. Aggiorna l'app con una IPA compilata dal codice v0.2, mantenendo lo stesso bundle ID; prima conserva eventuali impostazioni personali.
2. Apri la app e verifica la lettura Nightscout e la connessione RT2. Attiva l'invio automatico.
3. Controlla che nel registro compaiano `notifiche attive` per le caratteristiche disponibili.
4. Blocca l'iPhone per 20–30 minuti senza forzare la chiusura dell'app.
5. Guarda il numero sulla home meteo del RT2 **prima** di sbloccare l'iPhone.
6. All'apertura controlla i timestamp nel registro: `Risveglio BLE in background` e `Nightscout: controllo (notifica BLE background)` sono prove di un tentativo; `BLE: scrittura richiesta` prova l'invio richiesto, non la visualizzazione.
7. Se mancano eventi spontanei, valutare trigger lato Nightscout/notifiche push (richiede una infrastruttura e vincoli iOS diversi) oppure accettare aggiornamenti solo opportunistici.

La directory `watchface/` contiene uno sfondo 360 px per custom dial ufficiale e la documentazione dell'ipotesi TBWF. Non include un TBWF validato.
