# Obiettivo

Trasformare 5.000–8.000 survey/giorno, in lingue diverse, in segnalazioni azionabili verso i team competenti (Jira), **senza** richiedere la lettura umana di ogni singola survey, ma mantenendo un livello di supervisione sufficiente a garantire qualità, fiducia dei team riceventi e capacità di individuare problemi nuovi o critici.

La soluzione propone un utilizzo dei dati non strutturati provenienti dalle survey (utilizzati ad oggi? Da chiedere) tramite un processo di valutazione **per eccezione**: l'automazione gestisce il volume, l'umano interviene solo dove il suo giudizio aggiunge valore reale.

L’obiettivo provare a creare una ulteriore forma di valore tramite una automazione arricchita dall’AI, dove rimane presente il fattore “human in the loop” per validare il risultato finale.

In poche parole → L'umano non deve vedere ogni survey. Deve vedere solo ciò che è incerto, anomalo o ad alto impatto. Tutto il resto scorre automaticamente, con un controllo a campione al posto di una revisione esaustiva.



# Componenti

- sistema di classificazione → Traduce, classifica per categoria (la classificazione è più efficiace pre o post traduzione?), assegna uno score di confidence sulla classificazione e uno score di severità/impatto a ogni survey
- motore di aggregazione → Raggruppa le survey in cluster di problema (stesso tema, stessa causa) invece di trattarle come eventi singoli
- motore di routing → decide, in base a regole di business, se un cluster va:
    - (a) a ticket automatico, (b) a revisione umana mirata, (c) ad archiviazione
- team di revisione → Piccolo team riceve tabella via mail contenente solo i cluster incerti/critici + un campione di QA giornaliero
- team riceventi Jira → Prodotto, supporto, logistica ecc. — ricevono i ticket generati e ne sono i "clienti interni”
- owner della pipeline → Responsabile della calibrazione delle soglie, delle metriche di qualità, dell'evoluzione del processo



# Script end to end

- **Ingestion**: le survey arrivano continuamente durante la giornata.
- **Traduzione e classificazione**: ogni survey viene tradotta (se necessario) e classificata su una tassonomia di categorie definita, con uno score di confidence associato.
- **Aggregazione in cluster**: le survey vengono raggruppate per problema simile (stessa categoria + similarità semantica del contenuto), non trattate una per una. L'unità di lavoro da qui in poi è il **cluster**, non la singola survey.
- **Scoring del cluster**: ogni cluster riceve uno score composito basato su:
    - **volume** (quante survey nel cluster)
    - **confidence media** della classificazione
    - **severità stimata** (presenza di segnali critici: sentiment molto negativo, parole chiave ad alto rischio — es. sicurezza, reso, danno, frode)
    - **novità** (è un pattern mai visto prima o un problema ricorrente noto)
- **Routing automatico** in base allo score:
    - **Auto-ticket**: confidence alta + nessun segnale critico + pattern noto → ticket Jira creato senza intervento umano.
    - **Revisione mirata**: confidence bassa, o segnale critico presente, o pattern nuovo mai visto → il cluster entra nella coda di revisione umana.
    - **Archiviazione automatica**: volume irrisorio e nessun segnale di rilievo → non genera ticket, resta solo a fini statistici.
- **Revisione mirata (umano)**: il team di revisione vede solo i cluster instradati qui (un numero gestibile). Per ciascuno decide: approva (ticket parte), corregge la categoria/priorità e approva, oppure scarta. → maschera streamlit?
- **Creazione ticket**: per i cluster auto-approvati o approvati dall'umano, viene generato un ticket Jira per cluster (non per singola survey), con conteggio delle survey incluse e link/riferimento alle survey originali per contesto.
- **Campionamento QA giornaliero**: indipendentemente dal routing, un campione statistico casuale (es. 50–100 survey/giorno) tra quelle instradate in auto-ticket o auto-archiviazione viene rivisto a posteriori dal team, per stimare il tasso di errore reale del sistema di classificazione e routing.
- **Analytics/dashboard**: tutte le survey (indipendentemente dal routing) alimentano una vista aggregata di trend, usata sia dal team di revisione per calibrare le soglie sia dai team di business per decisioni (es. prodotto, qualità).

# Regole di business da definire per il comportamento del sistema

- **Soglia di confidence per l'auto-ticket**: valore minimo sopra cui il sistema si fida della classificazione senza revisione. Va calibrata sui dati reali, non fissata a priori, e rivista periodicamente.
- **Lista dei segnali critici che forzano sempre la revisione umana**, indipendentemente dalla confidence (es. menzione di sicurezza, rischio legale, cliente enterprise, frode sospetta).
- **Definizione di "pattern nuovo"**: come il sistema riconosce che un cluster non è mai stato visto prima (nuova categoria emergente, nuova causa within una categoria nota).
- **Criterio di aggregazione in cluster**: quanto deve essere simile il contenuto di due survey per finire nello stesso cluster, e ogni quanto viene ricalcolato l'aggregazione durante la giornata.
- **Granularità del ticket**: un ticket per cluster è la baseline, ma va definita una soglia oltre la quale un cluster molto grande genera comunque più ticket (es. per evitare un singolo ticket con 3.000 survey allegate, poco utile a chi lo riceve).
- **Dimensione e criterio del campione di QA**: fisso (es. 100/giorno) o proporzionale al volume totale della giornata.
- **SLA di revisione per i cluster in coda mirata**: entro quante ore/giorni un cluster ad alta severità deve essere guardato, e cosa succede se nessuno lo guarda in tempo (escalation, notifica a un secondo responsabile).

# Requisiti funzionali per componente

**Classificazione**

- Deve produrre categoria, score di confidence, e indicatori di severità per ogni survey.
- Deve gestire multi-lingua in input e restituire un output leggibile in inglese/italiano per chi fa revisione.

**Aggregazione**

- Deve raggruppare survey simili in cluster senza perdere la tracciabilità verso le survey originali (ogni ticket deve poter risalire alle survey che lo hanno generato).
- Deve aggiornarsi durante la giornata (non solo a fine giornata), così un cluster critico non aspetta ore per essere visibile.

**Routing**

- Deve applicare le regole di assegnazione in modo deterministico e verificabile (per ogni cluster deve essere chiaro *perché* è finito in auto-ticket, revisione o archiviazione — non una decisione opaca).
- Deve essere ricalibrabile senza dover ridisegnare il sistema (le soglie sono parametri, non logica hardcoded nel processo).

**Revisione mirata**

- Deve mostrare al revisore solo l'informazione necessaria a decidere velocemente: cluster, volume, severità, esempio rappresentativo di survey, perché è finito in revisione.
- Deve permettere correzione della categoria prima dell'approvazione.
- Deve tracciare chi ha deciso cosa e quando, per responsabilità e per alimentare le metriche di qualità.

**Campionamento QA**

- Deve selezionare il campione in modo casuale e rappresentativo

**Analytics**

- Deve mostrare trend per categoria nel tempo, non solo lo snapshot del giorno.
- Deve essere il luogo dove si vede l'effetto delle ricalibrazioni delle soglie (es. il volume di cluster instradati a revisione umana sta scendendo o salendo).
- Non sostituisce il ciclo di ticketing: è supervisione, non l'unico output del sistema.

# Reportistica

- componente descrittiva per orientata al management
- metriche di successo del processo
    
    
    | Famiglia | Metrica | Cosa indica |
    | --- | --- | --- |
    | Efficienza | % survey da gestire |  |
    | Efficienza | % survey gestite senza intervento umano | Quanto il modello a eccezione sta effettivamente scalando |
    | Efficienza | Tempo medio cluster → ticket | Velocità end-to-end |
    | Qualità | Tasso di correzione categoria in revisione mirata | Affidabilità della classificazione sui casi incerti |
    | Qualità | Tasso di errore stimato dal campione QA | Affidabilità della classificazione sui casi automatizzati — la metrica più critica |
    | Qualità | % ticket poi effettivamente lavorati dal team ricevente (non scartati) | Fiducia a valle nella pipeline |
    | Copertura | % cluster critici gestiti entro SLA | Tenuta del processo sui casi ad alto impatto |
