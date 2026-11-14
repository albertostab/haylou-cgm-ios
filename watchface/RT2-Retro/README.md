# RT2 Retro — riferimento dell'utente

Ricostruzione del riferimento ricevuto il 14 novembre: fondo nero con bordo
caldo, bande turchese/arancio/rosso, ora crema grande e inclinata, capsula
glicemia con goccia e freccia, tre indicatori con icone per passi, battiti e calorie.

## Anteprime

- `RT2-Retro-design-360-DEMO.png`: design alla risoluzione reale del display.
- `RT2-Retro-design-DEMO.png`: stesso design ingrandito per osservarlo.
- `RT2-Retro-animation-DEMO.gif`: bozzetto del punto dei secondi sul bordo,
  un giro al minuto. Non è un file da caricare sul watch.
- `RT2-Retro-base-DEMO.png`: rendering dei soli campi nativi del progetto base.

**Tutti i valori nelle anteprime sono dimostrativi.** L'immagine di sfondo non
contiene numeri, data, valore glicemico o freccia fissi. Gli anelli sono
decorativi; non rappresentano progressi, soglie o una frequenza cardiaca misurata.

Il font dell'ora deriva da Russo One con una trasformazione dei contorni
(`xScale=0.74`, `shearX=0.24`), subset dei caratteri necessari e nome nuovo
`RT2 Retro Time Block`. Header e statistiche derivano da Barlow Condensed
con subset Latin-1 e nomi nuovi; l'header visualizza lettere maiuscole.
Licenze SIL OFL incluse. I caratteri rimangono separati dallo sfondo.

## File TBWF e stato reale

| File | Contenuto | Stato |
|---|---|---|
| `RT2-Retro.tbwf` | Ora/data/temperatura/passi/battiti/calorie come campi nativi dinamici | Archivio, JSON, PNG e font verificati; import e watch non provati |
| `RT2-Retro-Arrows-EDITOR-PROBE.tbwf` | Stesso design, più strip di frecce meteo e risorsa per lancetta dei secondi | **Prova da importare nell'editor: compatibilità e comportamento non verificati** |

`validation.json` separa i controlli effettuati dalle prove mancanti.
Lo script non apre Bluetooth, non invia comandi e non installa quadranti.
Il file compatto TBWF è il progetto; il binario che Hello Haylou compila per
il watch avrà una dimensione diversa, ancora da misurare.

La prova frecce usa `resourceImage` con `sections=16` per `weatherResource`.
Questa combinazione **non è documentata come supportata**: la documentazione
dell'editor TBWF dice che l'importazione libera delle icone meteo non è
disponibile. L'editor potrebbe rifiutare o ignorare la strip. Anche il pivot
della lancetta deve essere controllato. La validità dello ZIP non prova
che questi elementi siano compilati o aggiornati dal firmware.

Il bozzetto segue il riferimento con `NOV` e `8.542`. Il progetto base usa
il mese numerico e i passi nativi senza formattazione aggiuntiva: le opzioni
per mese testuale e separatore delle migliaia non sono state verificate.
Non sono stati introdotti nomi di elementi o comandi BLE inventati per simularle.

## Importazione e installazione

1. Su Android, usa [Hello Haylou di Tibor Borsos](https://play.google.com/store/apps/details?id=hu.tiborsosdevs.haylou.hello),
   impostato in italiano per localizzare il giorno della settimana.
2. Apri **Altro → Quadranti → Editor → NEW .tbwf** e seleziona il progetto.
   Usa la scheda Editor per i TBWF. Se il download diventa `.zip`, ripristina
   `.tbwf` senza scompattare il file.
3. Per `EDITOR-PROBE`, controlla prima nell'editor la risorsa meteo e quella
   dei secondi. **Non procedere all'upload se mostra icone meteo, una strip
   deformata, un punto fuori posto o un errore.** Riesporta il progetto per
   controllare che riferimenti, risorse e sezioni siano conservati.
   Una singola freccia in anteprima non dimostra la selezione dinamica dei frame.
4. Dopo una verifica positiva, interrompi temporaneamente le connessioni
   Haylou CGM iOS/Haylou Fun e connetti Hello Haylou **solo al tuo RT2 LS10**.
   Seleziona il quadrante nell'editor e usa **Upload Watch Face**.
   Non resettare o dissociare il watch come primo tentativo.
5. Termina la connessione Android, riconnetti il client iOS e confronta il
   valore nel pannello meteo e nella home. Va provato che il campo del
   quadrante usi la stessa temperatura aggiornata dal comando 26.

L'Android non era disponibile per questa prova: importazione e installazione
**non sono state eseguite**. Non è stato acquistato alcun componente dell'app.

## Limiti dati, frecce e colore

- Il protocollo iOS, gli UUID, il framing/CRC e il comando 26 restano invariati.
  Il valore è la rappresentazione approssimata Celsius → Fahrenheit già usata
  dall'app, con possibile scarto di 1. Usare la modalità Fahrenheit già verificata.
- I codici proposti mantengono il mapping esistente: `0=assente`, `1=→`,
  `2=↗`, `3=↑`, `4=↘`, `5=↓`, `6=↓↓`, gli altri frame mostrano indisponibile.
  L'ordine dei frame del compilatore è ancora da verificare; i codici oltre
  `1` sono provvisori anche nel mittente. `DoubleUp` condivide il codice 3 con
  `SingleUp`. Nessuna freccia è ancora confermata sul display.
- Il rosso fuori range sul numero **non è implementato nel quadrante**:
  il colore del campo temperatura nativo è statico. Il rosso dell'icona cuore
  e della banda è decorativo e non è un allarme glicemico.
- Il quadrante non riceve l'età del dato CGM. Un dato vecchio può restare visibile.
  Il cambio di watchface non risolve la sospensione del polling Nightscout su iOS.

## Riproduzione

Richiede Python 3.10+ e Pillow; font e sfondo sono inclusi.

```powershell
python watchface/RT2-Retro/tools/build_retro.py
```

Il canvas del progetto è 454×454 secondo il formato TBWF, mentre le anteprime
per RT2 sono 360×360. I pacchetti sono riproducibili; lo script verifica risorse,
font, integrità ZIP e schema. Questi controlli non sostituiscono Hello Haylou o
la prova del display fisico.

## Provenienza

- Sfondo ricavato dal riferimento con il tool integrato `image_gen`.
  Metodo e prompt completo: [PROMPT.md](PROMPT.md).
- Schema/layout: [haylou-rt-tools](https://github.com/jvitorcosta/haylou-rt-tools),
  revisione `cfb4c22ccd55f533853d4c2e3bef86e633b9b695`, licenza MIT in
  `licenses/` e `../tools/LICENSE-MIT.txt`. Anche l'autore dichiara non ancora
  confermati sul display i propri quadranti generati.
- [Russo One](https://github.com/google/fonts/tree/main/ofl/russoone) e
  [Barlow Condensed](https://github.com/google/fonts/tree/main/ofl/barlowcondensed).
- [Compatibilità RT2 TBWF](https://hello-haylou.web.app/page/watch-faces),
  [funzioni dell'editor](https://hello-haylou.web.app/page/features),
  [limiti BIN/TBWF](https://www.watchfacebook.com/forum/viewtopic.php?t=9).

Il progetto non contiene token, URL Nightscout o valori clinici reali.
