# OrtoVicino — Sicurezza e pubblicazione (versione sperimentale)

## Novità
- Attivazione account tramite link email monouso valido 24 ore. Prima della verifica non è possibile accedere.
- Recupero password tramite link monouso valido 30 minuti; le sessioni esistenti vengono revocate.
- Segnalazione di annunci e recensioni (e messaggi, tramite API). Moderazione via endpoint amministrativi.
- Cookie HttpOnly SameSite=Lax, protezione CSRF, limitazioni richieste basilari, autorizzazioni per chat privata.
- File `Caddyfile.example` per TLS automatico con Caddy quando hai un dominio pubblico e porte 80/443 raggiungibili.
- Primi test ExUnit (`cd backend && mix test`). **Non equivalgono a un audit.**

## Come configurare la posta
Per inviare email reali usa Resend con dominio verificato. Imposta nel servizio backend:
`RESEND_API_KEY`, `MAIL_FROM` (es. `OrtoVicino <noreply@tuodominio.it>`), `PUBLIC_URL` (es. `https://ortovicino.tuodominio.it`).
In locale, senza servizio email, puoi impostare `DEV_EMAIL_LINKS=true` e `MIX_ENV=dev`: i link di verifica e recupero verranno stampati SOLO nel terminale backend. **Non abilitare mai questo flag in produzione.**

## Amministrazione
Imposta `ADMIN_EMAIL` all'indirizzo di un account **verificato**. API disponibili:
- `GET /api/admin/reports` elenca le segnalazioni (max 100).
- `POST /api/admin/reports/:id/close` chiude una segnalazione.
- `POST /api/admin/users/:id/suspend` sospende l'account e revoca le sessioni.
L'accesso usa lo stesso cookie di sessione e le richieste POST richiedono `X-CSRF-Token` restituito da `/api/me`.
Non è ancora presente una dashboard admin visuale. Per moderare devi usare le API.

## HTTPS con Caddy
1. Compila il frontend: `cd frontend && npm install && npm run build`.
2. Installa Caddy sul server e copia `Caddyfile.example` come `/etc/caddy/Caddyfile`, sostituendo dominio e percorso dist.
3. Mantieni Elixir su `127.0.0.1:4000`.
4. Imposta `COOKIE_SECURE=true` sul backend, assieme a `PUBLIC_URL=https://...`.
5. Avvia Caddy; gestirà certificati TLS se DNS e porte sono configurati correttamente.
6. Metti il database fuori da una directory web, usa backup cifrati, proteggi chiavi e variabili d'ambiente.

## Test
`cd backend && mix deps.get && mix ecto.migrate && mix test`
Test manuale obbligatorio: registrazione ➝ ricezione link ➝ verifica ➝ login; password dimenticata ➝ reset ➝ logout di vecchie sessioni; report utente ➝ chiusura admin; tentativi di aprire chat di terzi ➝ 404; prova due utenti in finestre separate; HTTPS e certificato.

## Limitazioni IMPORTANTI, prima di andare online
Questa è ancora una base di sviluppo **non certificata né sottoposta a test d'intrusione**. Servono: test d'integrazione ripetibili, audit OWASP ASVS, politiche GDPR (informativa, consenso ove richiesto, minimizzazione, cancellazione/esportazione dati), hardening firewall/OS, rate limiting distribuito e persistente, protezioni antispam, pagina amministrativa con log delle azioni, controlli sui contenuti e procedure di risposta agli incidenti. La verifica email non garantisce l'identità di una persona. Non pubblicare un servizio reale senza controlli aggiuntivi e consulenza privacy appropriata.
