---
name: "Task Workflow Orchestration Analysis"
description: "Deep research report on AI agent workflow orchestration patterns, retry policies, parallelism, and LLM-specific risks"
type: research
date: 2026-02-22
---

# Аналіз та оптимізація workflow оркестрації AI-агентів для інженерних задач

## Рамка оцінювання та релевантні еталони production-рівня

Описаний вами orchestrator — це **довгоживуча workflow-система** з керованими ретраями, паралельним виконанням, накопиченням знань та обов’язковою валідацією. Для порівняння з “індустріальними” практиками найточнішими референсами є системи оркестрації/планування робіт (workflow engines) на кшталт entity["company","Temporal","workflow orchestration"], entity["organization","Apache Airflow","workflow scheduler"], entity["company","Prefect","workflow orchestration"] та entity["organization","Argo Workflows","kubernetes workflow engine"], які мають формалізовані моделі станів, retry-політики, тайм-аути, семантику скасування та обмеження паралельності. citeturn4search0turn4search3turn4search1turn4search14turn17search2

Окремо, оскільки у вас “виконавці” — LLM-агенти, важливо врахувати **LLM-специфічні системні ризики**, яких класичні workflow engines не мають у такій формі:  
- **обмеження корисного використання довгого контексту** (“lost in the middle” ефект), що прямо підсилює цінність вашого правила “one-task-per-cycle” і загалом дисципліни контексту; citeturn12search0  
- **галюцинації** як системний клас помилок (помилкові твердження з високою впевненістю), для яких потрібні retrieval/grounding, незалежна валідація, політики невпевненості та ескалації; citeturn12search5turn12search25turn12search17  
- **недетермінізм інференсу** (навіть у “детермінованих” налаштуваннях), що робить повторюваність і дебаг складнішими та підвищує важливість журналювання середовища/версій та “re-run на тому ж контексті”; citeturn12search6turn12search2  
- **вартість токенів** і компроміс “довгий контекст vs RAG”, де retrieval часто знижує вхідну довжину і витрати; citeturn12search11turn12search27  

Ця рамка підказує ключову тезу порівняння: ваші “залізні правила” виглядають як **спроба перенести дисципліну розподілених систем** (timeouts/retries/idempotency/контроль паралельності) у **недетермінований LLM-виконавчий контур** — що загалом відповідає реальним напрямам “production agentic” 2024–2026. citeturn14search3turn14search4turn11search0turn3academia40

## Станова машина задач і семантика переходів

Ваш ланцюжок `pending → in_progress → completed → tested → validated` із поверненням на `pending` при фейлі та окремим `stopped` (перманентне скасування) є близьким до практики workflow-рушіїв: **running + набори terminal states** (succeeded/failed/canceled/terminated/timedout/…); різниця в тому, що ви вбудували “tested/validated” як окремі доменні стадії, а не як етапи pipeline/job. У entity["company","Temporal","workflow orchestration"], наприклад, Workflow Execution має статуси на кшталт Running/Completed/Failed/Canceled/Terminated/TimedOut/ContinuedAsNew. citeturn4search0turn4search8

У entity["organization","Apache Airflow","workflow scheduler"] набір станів детальніший на рівні TaskInstance: є проміжні (scheduled/queued/running) та спеціальні “retry-ish” (up_for_retry, up_for_reschedule, deferred) плюс terminal-ish (success, failed, skipped, upstream_failed). citeturn4search3turn4search7turn4search11  
У entity["company","Prefect","workflow orchestration"] стани ще багатші (Scheduled, Pending, Running, Completed, Failed, Crashed, Cancelling, Cancelled, Paused, Suspended, AwaitingRetry, Retrying, Late тощо), тобто “paused/suspended/cancelling” формалізовані як first-class стани. citeturn4search1turn4search5  
У entity["organization","Argo Workflows","kubernetes workflow engine"] на рівні node phase є Pending/Running і terminal (Succeeded/Skipped/Failed/Error/Omitted), а retry-логіка часто сприймається як частина життєвого циклу template/step. citeturn4search14turn17search2turn17search10

Формально, ваша модель добре лягає на інтуїцію **statecharts** (ієрархія/паралельність/комунікація як проблеми складних дискретних систем), але зараз у вас модель “пласка” — без явної ієрархії/ортогональних регіонів (на кшталт “execution state” × “validation state” × “human gate state”). У statecharts саме це і є ключовою перевагою для складних систем: підтримка ієрархії та concurrency в моделі станів. citeturn8search3turn8search7

image_group{"layout":"carousel","aspect_ratio":"16:9","query":["state machine workflow lifecycle diagram","workflow engine retry state diagram","temporal workflow execution status diagram"],"num_per_query":1}

### Потенційно відсутні стани/переходи, які характерні для production

Ваша система свідомо мінімізує стани, але production-рушії часто вводять кілька “потрібних для керованості” проміжних/службових станів:

- **queued/scheduled/assigned**: “завдання прийняте оркестратором і поставлене в чергу” ≠ “робота реально почалась”. У Airflow/Prefect/Argo це розділено (scheduled/queued/pending). citeturn4search7turn4search1turn4search14  
- **cancelling/cancelled**: ви маєте `stopped` як перманентну відміну, але для production важливий перехідний стан “cancel requested/ in progress”, бо скасування може бути повільним (зупинка воркерів, очікування), і потрібна спостережуваність цього процесу. Prefect явно має CANCELLING→CANCELLED; Temporal розрізняє Canceled vs Terminated. citeturn4search1turn4search0turn4search16  
- **paused/suspended/blocked (waiting_on_human або waiting_on_external)**: у вас `stuck` прив’язаний до ретраїв, але production-системи часто мають окремий стан “на паузі” або “очікує слот/ресурс/людину”, щоб не змішувати “безнадійно зламалось” із “зупинено навмисно/операційно”. У Prefect є PAUSED/SUSPENDED та AwaitingConcurrencySlot як first-class концепти. citeturn4search1turn4search25turn15search6  

### “Stopped окремо від failure” як патерн

Ваш принцип “stopped — перманентна відміна, ніколи не використовується для фейлів” узгоджується з production-семантикою, де **cancellation ≠ failure**. Temporal має Canceled/Terminated окремо від Failed; Prefect має Cancelled/Cancelling окремо від Failed/Crashed. citeturn4search0turn4search1turn4search37  

Практична рекомендація тут — навіть якщо ви не хочете розширювати базову state machine, ввести хоча б **derived substate** (або “reason codes”) для `pending`: `pending:queued`, `pending:blocked`, `pending:retry_backoff`, щоб метрики та policy-механізми були точнішими без вибуху кількості станів. Це близько до того, як Airflow має окремі “why pending” стани (scheduled/queued/deferred/up_for_retry), не змінюючи “DAG is running”. citeturn4search7turn4search3

## Retry та “circuit breaker”: зіставлення з distributed системами і кращі практики

### Порівняння з Hystrix/resilience4j

Те, що ви назвали circuit breaker (3 спроби → stuck/tag → human), функціонально ближче до **bounded retries + human escalation**, ніж до класичного circuit breaker для викликів залежностей. Класичний circuit breaker (в сенсі entity["organization","Hystrix","circuit breaker library"] або entity["organization","Resilience4j","java resilience library"]) зазвичай має стани на кшталт closed/open/half-open і “відтинає” виклики до деградуючої залежності на певний час, щоб уникнути каскадних відмов. citeturn1search32turn2search32turn1search33  

Тобто у вас “breaker” — **запобіжник від нескінченних автономних петель**, а не “запобіжник від загибелі downstream сервісу”. Для agentic workflow це навіть більш релевантно, бо найбільший ризик тут — не “мертва залежність”, а “модель вперто повторює невдалу стратегію”. Це прямо перетинається з LLM-недетермінізмом і галюцинаціями як класами проблем. citeturn12search6turn12search5

### Дуже близька індустріальна аналогія: Dead-Letter Queue / poison messages

Ваше правило “N спроб → stuck → людина” майже 1:1 відображає pattern **Dead Letter Channel / DLQ**, де повідомлення після перевищення max delivery count ізолюється для розбору. Це стандартний механізм у брокерах:  
- entity["company","Amazon Web Services","cloud provider"]: SQS redrive policy з `maxReceiveCount`, після чого повідомлення переміщується в DLQ; citeturn10search0turn10search28  
- Azure Service Bus: max delivery count → DLQ; citeturn10search1  
- Enterprise Integration Patterns описують “Dead Letter Channel” як спосіб поводження з недоставними/необроблюваними повідомленнями. citeturn10search8  

Це сильне підтвердження того, що ваш “stuck” — **визнаний production-патерн** (failure isolation), тільки перенесений з messaging у task orchestration.

### Best practices для ретраїв у багатофазному workflow

1) **Фазові лічильники ретраїв** (exec vs validate) — хороша практика, бо причини фейлів різні: execution може фейлити через інтерфейс/контекст/інструменти, validation — через якість/тести/безпеку. У production workflow-системах retry policy зазвичай налаштовується **на вузол/крок** (task/activity/template), а не “на весь workflow однаково”. Argo має retryStrategy на рівні step/template; Airflow — `retries`/`retry_delay`/`retry_exponential_backoff` на рівні task; Prefect — `retries` і `retry_delay_seconds` на рівні flow/task; Temporal — RetryPolicy для activity/workflow з maximumAttempts і backoff. citeturn17search2turn17search0turn17search1turn17search3turn14search5  

2) **Backoff + jitter** — ключова практика для уникнення “retry storm” та синхронних повторів. AWS документує exponential backoff and jitter як базовий building block resiliency. citeturn14search0turn14search3turn14search17  

3) **Класифікація помилок на retryable vs non-retryable**. Temporal прямо підтримує “non-retryable error types” і зупинку ретраїв по типах помилок/тайм-аутах. citeturn17search11turn17search3turn14search5  
Для LLM-помилок це можна інтерпретувати як: якщо невдача викликана “відсутніми вимогами/доками/людським рішенням”, retry без нової інформації майже завжди марний — краще ескалувати в `blocked` раніше.

4) **Конфігурованість “max attempts” за доменом/ризиком**. Це типово: усі великі системи дозволяють задавати retries per task. citeturn17search0turn17search1turn17search2turn17search3  
Ваше “non-overridable floor по file path” є сильним safety-механізмом; але **верхня межа ретраїв** та “cooldown” теж корисно робити *policy-driven*: наприклад, auth/payments можуть мати менше автономних спроб, але більше вимог до діагностики/артефактів перед ескалацією.

### Як ще краще ламати нескінченні “agent loops”

Окрім ліміту спроб, production agentic системам зазвичай потрібні **детектори відсутності прогресу**:  
- “diff stagnation”: якщо два ретраї підряд генерують дуже схожий diff або не змінюють поведінку тестів — імовірно, агент застряг;  
- “evidence gating”: наступна спроба дозволяється лише якщо додано *нові факти* (новий doc reference, новий сигнал із тестів, новий stack trace, новий retrieval hit).  
Ця логіка напряму атакує клас “галюцинація/впевнене повторення” і узгоджується з тим, що retrieval+grounding знижують помилки, а довгі контексти без дисципліни можуть погіршувати якість. citeturn12search5turn12search0turn5search3turn12search19

Також вартий уваги індустріальний патерн “auto-pause after consecutive failures”: Airflow має налаштування `max_consecutive_failed_dag_runs_per_dag` (експериментальне) для авто-паузи DAG після N провалів — це близько до вашого breaker, але на рівні DAG. citeturn15search1

## Паралельність та ізоляція: зіставлення з concurrency control і production-фреймворками

### Ваш file-manifest + isolation checklist як аналог “conservative 2PL”

Ви фактично вимагаєте попереднього оголошення “read/write set” (file manifest) і допускаєте паралельність лише за відсутності перетинів та залежностей. Це дуже схоже на **консервативний 2PL** у базах даних, де транзакція може “передекларувати” readset/writeset і взяти потрібні блокування наперед для уникнення дедлоків (у літературі це відоме як conservative 2PL). citeturn2search36turn2search20turn2search12  

Ваш глобальний blacklist “завжди shared/конфліктні файли” схожий на практику виділення “гарячих об’єктів” (hotspots), які серіалізуються або захищаються mutex-ом. У Kubernetes-native workflow світі Argo прямо надає mutex/semaphore механізми для синхронізації й ліміту паралельності. citeturn15search8

### Порівняння з паралельністю в Argo/Airflow/Prefect/Temporal

- entity["organization","Argo Workflows","kubernetes workflow engine"]: підтримує явні ліміти parallelism і механізми синхронізації (mutex/semaphore) як first-class. citeturn15search0turn15search8turn15search24  
- entity["organization","Apache Airflow","workflow scheduler"]: масштабує паралельність конфігами на кшталт `max_active_tasks_per_dag` і загального `parallelism`; також має “pools” і різні механізми обмеження конкуренції на рівні DAG/тасків. citeturn15search1turn15search17turn15search21  
- entity["company","Prefect","workflow orchestration"]: має глобальні concurrency limits із lease-механікою (сервер відстежує lease, клієнт продовжує), плюс task-level tag-based limits; це концептуально близько до lock leasing. citeturn15search6turn15search18turn15search22  
- entity["company","Temporal","workflow orchestration"]: task queues збережені на сервері, воркери poll-ять; є server-side throttling, worker options для concurrency, рекомендація розділяти task queues для ізоляції та пріоритизації. citeturn15search3turn15search23turn15search27  

Ключова різниця: ці системи керують конфліктами через **ресурсні слоти / locks / rate limits**, а не через “file overlap” — бо їхні одиниці роботи зазвичай не є редагуванням одного репозиторію в одному worktree. У вашому випадку “файл” — це основний конфліктний ресурс, тож file-manifest підхід — логічний.

### Trade-off: песимістична vs оптимістична конкуренція

Ваш підхід — песимістичний: “за замовчуванням послідовно, паралельно лише якщо доведено незалежність”. Це сильно знижує ймовірність конфліктів, що для LLM-редагування коду (де merge-конфлікти часто дорогі і легко породжують приховані дефекти) може бути виправдано для enterprise reliability.

Оптимістичний варіант (аналог OCC) у DB-світі робить навпаки: дозволяє виконання, а конфлікти ловить на “commit” (validation phase). OCC класично формалізований у роботі Kung & Robinson (1981). citeturn2search1turn2search29  

Для вашої системи оптимістичний варіант практично означає: **ізольовані workspaces/patches для агентів + послідовне застосування і злиття**. Це могло б суттєво збільшити паралельність, але ціною:
- необхідності 3-way merge/конфлікт-резолюції,
- вищого ризику “логічних конфліктів” без явних merge-conflicts,
- більш складної гарантії “rollback без git reset/clean”.

Компромісний production-патерн для agentic coding: паралелити **дослідження/аналіз** (що ви вже робите), а редагування файлів — або строго розводити по файлах, або ізолювати через patch-based інтеграцію з серійним застосуванням.

## Failure history та персистентна пам’ять: “negative knowledge” як CBR/experience replay

### Паралелі з case-based reasoning та experience replay

Ваш механізм “перед виконанням шукай у пам’яті відомі фейли і блокуй повторення вже провалених підходів” природно схожий на **case-based reasoning**: нову задачу розв’язують через пошук схожих кейсів у case base, їх повторне використання/адаптацію та навчання на результаті. citeturn2search7turn2search35  

А “накопичення історії спроб і вчитись на минулих помилках” має паралель із **experience replay** у reinforcement learning, де агент зберігає досвід та повторно “програє” його для стабілізації/покращення навчання. citeturn2search14turn2search18turn2search26  

У вашому випадку це не навчання ваг моделі, а навчання **політик оркестратора** і **інструктивних патернів** (що робити/не робити). Це дуже доречний перенос ідей.

### Best practices для “negative knowledge” у production agentic системах

Найслабше місце “негативної пам’яті” — ризик **overfitting на минулі фейли** (те, що вчора не спрацювало через контекст/версії, сьогодні може спрацювати). Тому production-підхід зазвичай включає:
- **атрибути контексту** (версії залежностей, гілка/коміт, конфіг, модель/температура, дата, тип задачі);  
- **scope і TTL/сталість**: деякі “не робити” твердження мають короткий термін дії;  
- **перевіряємий артефакт**: посилання на конкретний лог/stack trace/тест/диф, а не лише текстовий опис.

Це поєднується з тим, що LLM-галюцинації потребують grounding і можливості перевірки. citeturn12search5turn5search3turn12search19  

### Vector memory vs structured зберігання

Vector memory із семантичним пошуком — сильний підхід для **неструктурованого досвіду** (опис причин, патернів, контекстів). Дослідження Retrieval-Augmented Generation показують, що поєднання parametric знань моделі та зовнішньої пам’яті/індексу може підвищувати фактичність та надавати provenance. citeturn5search3turn5search7  

Але для enterprise reliability, зазвичай потрібен **гібрид**:  
- vector store для “людських” пояснень і семантичного recall;  
- structured store (таблиці/івенти) для метрик, SLA, точних лічильників, причин переходів станів, типів помилок та аналітики.

Додатково, сучасні практики retrieval часто комбінують dense retrieval із lexical (BM25) та reranking. entity["company","Anthropic","ai research company"] описує “Contextual Retrieval” як підхід, що знижує failed retrievals та підвищує якість retrieval-кроку. citeturn12search19  
А з класичного IR відомо, що **query expansion** (додавання синонімів/варіацій) — стандартна техніка для покращення пошуку. citeturn5search2turn5search13  

Це напряму підтверджує вашу “агресивну multi-keyword doc search” як наближення до established IR-технік.

### Персистентність на SQLite: конкуренція доступу і захист “sacred memory”

Оскільки ваш knowledge store базується на SQLite, важливо спиратися на його реальну concurrency-модель: SQLite типово є “many readers / single writer”, а WAL режим підвищує паралельність читання з записом (readers не блокують writer і навпаки), але **не створює true multi-writer**. citeturn16search0turn16search1turn16search20  

Це підтримує ваш принцип “memory/ — sacred”: потрібно серіалізувати записи (або через один writer-процес/чергу) і стандартизувати транзакційні межі, щоб уникати SQLITE_BUSY та “database is locked” у паралельному агентному контурі.

## Архітектура валідації як multi-stage CI/CD та її enterprise-адекватність

Ваші 4 паралельні валідатори (completion/quality/testing/security&performance) концептуально близькі до **CI/CD pipeline із шарами контролю якості**: статичний аналіз/ліни, тести різних рівнів, security сканування, policy checks. Практика DevSecOps прямо вбудовує SAST у pipeline, щоб ловити вразливості “до продакшну”. citeturn6search2  

Те, що entity["organization","OWASP","web security foundation"] регулярно оновлює Top 10 і позиціонує його як “standard awareness document”, підтримує вашу ідею мати окремий security-валідатор із базовими перевірками на кшталт OWASP-категорій і секретів. citeturn7search4turn7search3turn7search1  

### “Косметика inline, функціональне — через fix-tasks”

Це добре узгоджується з pipeline-практикою: форматування/косметика часто auto-fix або безпечні виправлення, тоді як функціональні дефекти потребують окремого циклу розробки/перевірки. У LLM-контексті це ще важливіше, бо “швидка косметика” не має змінювати semantics і не повинна роздувати churn.

### Collateral failures та “global remediation tasks”

Ідея “якщо фейляться тести поза scope — створити глобальні remediation-задачі” відповідає production реальності: тестовий фейл у CI може сигналізувати регресію або нестабільність (flaky). Важливо, щоб система вміла:  
- відрізнити “реальний регрес” від “flaky/інфраструктурний фейл”;  
- не змішувати “вина цієї задачі” з “вина екосистеми”.

Тут може допомогти додатковий валідатор “flakiness / infrastructure suspicion” і зберігання статистики за тестами (частота фейлів). Це узгоджується з ідеєю, що вимірювання стабільності (change failure rate, time to restore) — ключова метрика engineering performance. citeturn6search0turn6search4  

### Mandatory re-validation після fix-tasks: overkill чи enterprise-правильно?

Для enterprise-grade reliability **повторна валідація після будь-якого функціонального fix** — радше правильна default-позиція, бо складність системи і ризик побічних ефектів високі. Але є оптимізація без втрати контрольованості:  
- вводити “еквівалентність scope” для повторної валідації (наприклад, якщо fix торкається лише форматування або тестів, security/perf валідатор може мати fast-path);  
- запускати повний набір лише якщо зміни зачіпають критичні шари або high-risk шляхи (що близько до вашого safety escalation).  
Це відповідає загальному принципу: контроль має бути **risk-based**, як у підходах на кшталт ABAC/політик доступу, де рішення визначається атрибутами контексту. citeturn6search3turn6search7  

### Aggregation-only path для проміжних батьків

Оптимізація “якщо всі діти validated — батько агрегує і пропускає повну перевірку” схожа на модульні/ієрархічні стратегії тестування (не завжди запускати “full suite” на кожному рівні), але має ризик пропустити integration-дефекти “на стиках” (між двома validated дітьми). Практика test pyramid підкреслює, що різні рівні тестів мають різні властивості і потрібні разом, а E2E дорогі й їх має бути менше. citeturn6search21turn6search1  

Тому enterprise-компроміс: для проміжних батьків робити **мінімальний інтеграційний smoke** (набір критичних інтеграційних тестів/контрактів), а не повний pipeline — це часто дає найкращий “cost vs risk” баланс.

## Документація як закон та керування “source of truth”

Ваш пріоритет `docs > code > memory > assumptions` дуже добре узгоджується з ідеєю “single source of truth” у GitOps/desired-state підходах. entity["organization","CNCF","cloud native foundation"] у glossary визначає GitOps як модель, де стан/конфіг повністю описані у файлах у джерелі істини (часто VCS), і автоматизовані процеси узгоджують live-state з desired-state. citeturn5search1turn5search8  

Ваш “aggressive multi-keyword doc search (3–5 варіацій)” має прямі аналоги в information retrieval як **query expansion**, що зменшує query-document mismatch. citeturn5search2turn5search13  

### Що можна зробити ще сильніше без втрати принципу “docs-as-law”

1) **Версіонування вимог**: прив’язувати задачу до конкретної версії/коміту документації (або doc “revision id”), інакше “docs-as-law” втрачає відтворюваність. Це аналогічно тому, як у GitOps “джерело істини” має audit trail. citeturn5search1turn5search8  

2) **Docs-to-tests**: критичні вимоги варто перетворювати в автоматизовані перевірки (контрактні/інваріанти) і запускати у вашому validation шарі, що наближає документацію до “executable spec”. Це зменшує ризик “док є, але його не дотримались”.

3) **Hybrid retrieval**: комбінувати semantic пошук (векторний) з lexical (BM25) та reranking/контекстом, бо це суттєво знижує retrieval failures у RAG. citeturn12search19turn5search3  

## Декомпозиція: scope-based vs time-based та гранулярність для AI-агентів

### Порівняння з WBS і Agile практиками

Ви декомпонуєте “за SCOPE (distinct concerns/files), а не за часом”. Це ближче до **deliverable-oriented decomposition**, що відповідає визначенню WBS у PMBOK як “deliverable-oriented hierarchical decomposition of the work…”. citeturn13search4turn13search0  

В Agile/Scrum є практика refinement як “розбиття і уточнення backlog items”, але Scrum не диктує метод; важливіше, щоб items ставали “готовими” і керованими. entity["organization","Scrum.org","scrum training org"] прямо описує refinement як додавання деталей/оцінок/порядку, не нав’язуючи як саме розбивати. citeturn13search1

Однак класична Agile практика “vertical slicing” наголошує: розбиття за архітектурними шарами (“UI окремо”, “API окремо”) може давати горизонтальні шматки, які не приносять завершену цінність. citeturn13search6turn13search14  
Ваше правило “distinct file scopes” потенційно підштовхує до горизонтального розбиття. Це не обов’язково погано для AI-агентів (бо зменшує конфлікти), але створює ризик, що інтеграційна нитка “розмажеться” між підзадачами. Це варто компенсувати або “інтеграційним підетапом”, або вимогою “observable completion artifact” для кожної підзадачі.

### “Atomic” як концепт

Тег “atomic” (не декомпонується) узгоджується з академічною/інженерною інтуїцією “primitive task”, який не розкладається далі. У літературі зустрічаються і формальні трактування “atomic tasks” (наприклад, у Task-Oriented Programming). citeturn13search19turn13search37  

### Дослідження про гранулярність підзадач для LLM-агентів

У software engineering агентів ключова тема — як інтерфейс та поділ дій впливають на успіх. entity["organization","SWE-agent","llm coding agent"] демонструє, що спеціально спроєктований agent-computer interface підвищує здатність агента навігувати репозиторій, редагувати файли та запускати тести. citeturn11search0turn11search4  

Роботи про планування/декомпозицію в LLM (ReAct, Plan-and-Solve, Tree of Thoughts) підтримують ідею, що structured planning і розбиття на проміжні кроки покращують результат та контроль над помилками. citeturn11search1turn11search3turn11search2  

Для довгих контекстів виникає додаткова грань: “Chain of Agents” досліджує, як кілька агентів можуть співпрацювати на long-context задачах. citeturn12search12  
Разом із “Lost in the Middle” це підсилює ваші правила: **чим менша і чіткіша підзадача, тим вища керованість**, але треба не втратити глобальні інваріанти. citeturn12search0turn12search12  

Практичний висновок для вашої системи: ваші “atomic agent tasks (1–2 files)” у async-моді — сильна default-евристика для мінімізації конфліктів і контекстного шуму, але її варто доповнювати “інтеграційними” задачами/перевірками, щоб зшивати горизонтальні зміни.

## Оптимізації, нові патерни 2024–2026 та рекомендації для Go-реалізації

### Оркестратор vs виконавці: чи правильно “Brain не виконує напряму”

Ваш розподіл “Brain = orchestration, Agents = execution” має дуже сильний production-аналог у entity["company","Temporal","workflow orchestration"]: Temporal Service “не виконує ваш код”, а лише оркеструє state transitions і видає Tasks воркерам; воркери зовнішні і саме вони виконують workflow/activity код. citeturn9search11turn9search7  

У агентному світі 2024–2026 це також проявляється як прагнення до мінімальних primitives і тестованої координації: entity["company","OpenAI","ai company"] описує Agents SDK як production-ready еволюцію Swarm із невеликою кількістю примітивів; citeturn3search25 а entity["organization","OpenAI Swarm","multi-agent framework"] акцентує lightweight coordination через “agents and handoffs”. citeturn3search2turn3search21  

Тому правило “Brain не торкається файлів у async” виглядає **обґрунтованим**, якщо ваша головна мета — контроль, трасованість і ізоляція помилок. Але варто мати чітку policy-умову, коли sync-режим безпечніший/дешевший (наприклад, дрібні зміни, один файл, низький ризик) — і у вас це вже є як окремий command.

### Що можна спростити без втрати надійності

1) **Уніфікація “completed/tested/validated” у “quality-gate pipeline” з reason-codes**. Замість множення станів, можна зберегти вашу стадійність, але формалізувати її як pipeline-результати з обов’язковими артефактами (які тести запускались, які валідатори пройдено). Це близько до того, як CI/CD інструменти відрізняють “job passed” від “pipeline passed”, не змінюючи доменний стан задачі.

2) **Явний “blocked” стан** (або tag), відмінний від “stuck”. Це прибирає семантичну плутанину між “вичерпали спроби” і “потрібне рішення/доступ/вхідні дані”. Prefect/Pipeline-рушії мають аналоги paused/suspended. citeturn4search1turn4search5  

3) **Стандартизація ретраїв як policy matrix**: `risk_level × phase × error_class → {max_attempts, backoff, requires_new_evidence}`. Це робить систему менш “магічною” і більш пояснюваною, а також зменшує надлишкові правила.

### Метрики, які варто трекати (поза completion rate)

Щоб оптимізувати enterprise-workflow, вам потрібні метрики **швидкості + стабільності + вартості**. DORA/“Four Keys” дають перевірену структуру для інженерної продуктивності: deployment frequency, lead time for changes, change failure rate, time to restore service. citeturn6search0turn6search4  

Для agentic orchestration додайте специфічні метрики:
- **Validation Failure Rate** (скільки completed падають на validate) та розподіл причин;  
- **Retry Depth Distribution** по фазах (exec vs validate), і частка “stuck”;  
- **No-progress triggers** (скільки разів детектор зупинив loop), щоб міряти “LLM thrash”;  
- **Conflict Rate** (перетин file manifests/частота конфліктів), щоб калібрувати песимістичність;  
- **Retrieval Hit Rate**: частка задач, де doc/memory retrieval реально вплинув (посилання на конкретні джерела), і correlates із успіхом; підсилюється практиками contextual retrieval і query expansion. citeturn12search19turn5search2  
- **Token/Cost per phase** і “cost-of-rework” (скільки токенів/часу пішло на fix-tasks після validate). Trade-off “RAG vs long context” прямо пов’язаний зі зменшенням input length/cost. citeturn12search11turn12search27  

### Що у Go-реалізації дасть найбільший виграш

Оскільки ви плануєте Go rewrite, є кілька природних “підсилювачів” саме для вашого класу задач:

- **Контроль життєвого циклу через context.Context**: у Go контекст — стандарт для deadline/cancellation propagation між горутинами і API boundary. citeturn9search0turn9search8  
- **Керована паралельність через errgroup**: `errgroup` дає синхронізацію, propagation помилок і cancelation group’и горутин — дуже природний примітив для “паралельні агенти + один orchestrator” з раннім скасуванням при критичній помилці. citeturn9search1  
- **Чіткі гарантії коректності конкурентного доступу**: Go memory model формалізує, коли записи одного потоку гарантовано видимі іншому; це корисно, якщо ви реалізуєте власні lock/lease механізми для scope registry. citeturn9search2  

На практиці це дозволить вирішити два болючих класи проблем:  
1) “завислі” паралельні гілки (ви вже маєте guaranteed finalization, але в Go можна зробити це через структуровану конкуренцію: `context cancel` + `errgroup.Wait()` + детерміноване finalize); citeturn9search0turn9search1  
2) “витоки ресурсів” (goroutine leaks, незавершені pollers/клієнти), які в LLM-системах часто проявляються як неконтрольовані витрати/зависання.

Як підсумок: ваша архітектура загалом дуже близька до production-патернів (DLQ-like escalation, conservative concurrency, CI-like validation, source-of-truth дисципліна). Основні точки росту — **формалізація семантики “blocked vs stuck”, ризик-орієнтовані retry policies з backoff/jitter, гібридна пам’ять (vector + structured), та інтеграційний рівень для зшивання горизонтальної декомпозиції** — і все це добре лягає на сильні сторони Go (context/errgroup/структурована конкуренція). citeturn10search0turn2search36turn6search2turn5search1turn9search0turn9search1