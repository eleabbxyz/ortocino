# OrtoVicino — mini progetto v0.2

Prototipo full-stack con **Vue 3, Leaflet 1.9, Elixir/Plug, Ecto e SQLite**. Aspetto mobile: verde naturale, bianco crema, angoli morbidi. Tutti i dati geografici demo sono indicativi nell'area di Montemurlo (PO).

## Funzioni

- Creazione account con email, nome, password di almeno 12 caratteri, tipo privato/professionista.
- Password conservate come **hash bcrypt con salt**, mai in chiaro.
- Login con cookie di sessione **HttpOnly / SameSite=Lax**, scadenza di 7 giorni, logout, token CSRF per modifiche.
- Pubblicazione annunci solo da utente autenticato, nome e tipo venditore assegnati dal server.
- Mappa Leaflet con base CARTO e attribuzione OpenStreetMap. Serve Internet per visualizzare i tasselli geografici.
- Posizioni dei privati **arrotondate lato server a 2 decimali** (~1 km), anche sulle risposte di vecchi annunci.
- Chat privata per annuncio tra l'acquirente che apre la conversazione e il proprietario dell'annuncio. Tutti i controlli avvengono sul backend.
- Aggiornamento immediato dei messaggi tramite **SSE / EventSource**, con riconnessione automatica. Non è una chat via polling.
- Recensioni con autore autenticato, massimo una per autore e annuncio, non consentite al proprietario.
- Regole di limitazione per login, registrazioni e invio di messaggi (rudimentali, in memoria).

## Avvia sul PC

Prerequisiti: **Elixir >= 1.16**, Erlang/OTP supportato, **Node.js >= 20**, npm, un compilatore C per bcrypt, e connessione internet alla prima installazione.

**Terminale 1**

```bash
cd ortovicino-mini/backend
mix local.hex --force
mix local.rebar --force
mix deps.get
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs
mix run --no-halt
```

**Terminale 2**

```bash
cd ortovicino-mini/frontend
npm install
npm run dev
```

Apri **http://localhost:5173**. La porta 4000 espone l'API Elixir solo su localhost. Durante lo sviluppo Vite instrada `/api` al backend.

### Test della chat in tempo reale

1. In una finestra normale, registra **Alice** e pubblica un annuncio.
2. Apri una finestra **in incognito**, registra **Bob** con una email diversa.
3. Bob apre l'annuncio di Alice e sceglie **Chat privata**.
4. Alice apre **Messaggi** e la conversazione (aggiorna la lista conversazioni entrando in Messaggi).
5. Scrivi da una finestra: il messaggio deve comparire anche nell'altra senza aggiornare la chat.
6. Bob può lasciare una recensione dell'annuncio; Alice non può recensire il proprio annuncio.
7. Un terzo account non deve poter leggere una conversazione cui non partecipa.

**Gli annunci demo iniziali non hanno un proprietario reale e non permettono la chat privata:** usa un annuncio creato dopo il login.

## Attenzione al database esistente

La migrazione `20261013000001_security_upgrade.exs` **cancella le vecchie chat e recensioni pubbliche di prova** (non compatibili con la sicurezza del nuovo modello) e crea tabelle protette. Prima di migrare un database esistente esegui un backup del file `backend/ortovicino.sqlite3`. Se avevi solo dati demo puoi anche ricreare un nuovo database.

## Prima di aprirlo su Internet

Questa è una **base locale di sviluppo**, non un servizio pronto per il pubblico. Mancano: verifica email, recupero password, gestione consensi e cancellazione account/dati, moderazione e segnalazioni, protezione anti-abuso distribuita, supervisione/limiti delle connessioni SSE, test end-to-end e audit di sicurezza. Per un server accessibile pubblicamente usa TLS/HTTPS, `COOKIE_SECURE=true`, reverse proxy, controllo CORS/origini, backup e aggiornamenti delle dipendenze. La geolocalizzazione approssimata non garantisce da sola l'anonimato: evita anche di inserire l'indirizzo nelle descrizioni o nei messaggi.

Per mantenere il progetto leggibile non vengono usati Phoenix o sistemi di account più pesanti. Per il rilascio pubblico è consigliabile passare a un'autenticazione consolidata (es. Phoenix generators) e a Phoenix Channels per le chat.

## Nota sui test

Il codice viene fornito come sorgente da compilare localmente. In questo ambiente non è disponibile l'eseguibile Elixir, quindi **non è stato possibile eseguire la compilazione o i test server**. La versione non è certificata come pronta per la produzione.
