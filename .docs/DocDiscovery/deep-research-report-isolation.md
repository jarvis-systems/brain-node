---
name: "Git Worktree Isolation Deep Research"
description: "Deep research on enterprise git worktree isolation for AI multi-agent orchestration — worktree architecture, merge strategies, shared resources, automation, sandboxing, integration patterns"
type: "research"
date: "2026-02-22"
---

# Enterprise Git Worktree ізоляція для AI multi-agent оркестрації

## Архітектура git worktree для паралельних AI-агентів

**Поточна best practice (з джерелами)**  
`git worktree` є нативним механізмом Git для підтримки **кількох робочих дерев** одного репозиторію: об’єкти/історія спільні, а “per-worktree” файли (на кшталт `HEAD`, `index` тощо) розділені. citeturn1view0turn3search3  
Git документує операції життєвого циклу worktree: `add`, `list`, `lock/unlock`, `move`, `remove`, `prune`, `repair`; а також механізм очищення “сирітських” адміністративних записів через `git worktree prune` або автоматично (через `gc.worktreePruneExpire`). citeturn1view0turn1view1  
Важлива семантика: Git за замовчуванням **відмовляється** створювати worktree, якщо гілка вже “вивантажена” в іншому worktree (захист від подвійного checkout однієї гілки), якщо не використано `--force` (або специфічні режими на кшталт detached HEAD). citeturn1view1turn3search39  
Для production-автоматизації важливо, що Git підтримує **per-worktree конфігурацію** в `config.worktree` і керування нею через `git config --worktree` (потрібно `extensions.worktreeConfig`). Це дозволяє налаштовувати worktree-специфічні речі (наприклад, hooks path) без глобального впливу. citeturn2search8turn2search4turn2search20  

image_group{"layout":"carousel","aspect_ratio":"16:9","query":["git worktree diagram linked worktrees","git worktree add prune lock workflow","git worktree config.worktree extensions.worktreeConfig"],"num_per_query":1}

**Рекомендований підхід для вашої системи (macOS M2, PHP/Node, 3–8 агентів, повна автоматизація)**  
Рекомендую перейти до “**bare repo + fan-out worktrees**” як базової фізичної ізоляції агентів:  
- 1 “центральний” bare-репозиторій (один `.git` object store),  
- N worktree-директорій (по одному на агента/задачу/спробу),  
- централізований оркестратор (“Brain”) керує тим, хто/коли створює worktree, які гілки, коли видаляє. Це безпосередньо відповідає моделі Git: “main worktree + linked worktrees” і зменшує дублювання історії порівняно з N повними clone. citeturn1view0turn3search19turn3search15  

**Branch naming та worktree path (конвенція, що добре працює з агент-per-worktree)**  
Найстабільніший патерн для enterprise-трасування — давати **унікальну** (і машинно-парсну) пару: `(branch name, worktree path)`:

- **Branch name** (рекомендація):  
  `ai/<agent>/<taskId>/<attempt>/<yyyymmdd-hhmm>`  
  Причини: (а) неможливо “випадково” взяти ту ж гілку, (б) легко шукати гілки по агенту/таску, (в) підтримує вашу circuit-breaker/attempt семантику. Обмеження Git щодо однієї гілки на один worktree робить унікальність критичною. citeturn1view1turn3search39  

- **Worktree path** (рекомендація):  
  `~/brain/worktrees/<repo>/<runId>/<agent>/<taskId>-<attempt>/`  
  Причини: чітке групування по “run”, простий GC, зручно для “first-batch-only” дисципліни; Git за замовчуванням може створювати нову гілку за basename path, але для предикативності краще явно задавати `-b`. citeturn1view0turn1view1  

**Worktree lifecycle policy (автоматизована, без ручного втручання)**  
- **Створення**: `git worktree add -b <branch> <path> <baseRef>` (або “detached” для throwaway експериментів, якщо ви хочете patch-only інтеграцію). citeturn1view0turn1view1  
- **Завершення**: `git worktree remove <path>`; Git дозволяє видаляти лише “clean” worktree, або примусово `--force` (ризик видалення незакомічених/неtracked файлів). citeturn1view1  
- **Аварійне відновлення**: якщо директорію worktree видалили “вручну”, Git тримає “stale admin files”; чиститься через `git worktree prune`, і може керуватися `gc.worktreePruneExpire`. citeturn1view0turn1view1  
- **Orphaned/moved worktrees**: `git worktree repair` відновлює зв’язки, якщо робочі дерева переміщувалися/копіювалися зовнішніми факторами. citeturn1view1  
- **Запобігання випадковому GC**: `git worktree lock` для worktrees на сьогоднішній “інтеграційній” або “критичній” фазі, якщо ви боїтесь автоматичного prune на CI/в скриптах. citeturn1view0turn1view1  

**Vendor / node_modules ізоляція (ефективно і без “contamination”)**  
Worktree дає файлову ізоляцію коду, але **залежності** (`vendor/`, `node_modules/`) залишаються найбільшим споживачем диску/IO. Best practice в CI/enterprise — **не шарити самі директорії залежностей між робочими копіями**, а шарити **кеші завантажених артефактів**:  
- Composer: підтримує `COMPOSER_CACHE_DIR` і налаштування `cache-dir`, з дефолтними шляхами на macOS і можливістю перенесення кешу в централізоване місце. citeturn2search7turn2search11  
- npm: має content-addressable HTTP/package cache (cacache) і документує керування кешем; можна централізувати `npm config set cache …` для прискорення повторних установок. citeturn3search0turn3search24  
- pnpm: будує модель “global content-addressable store + hard links у проєкт”, що зменшує диск та прискорює повторні інстали; важливо тримати store на тому ж диску/FS, інакше буде copy замість лінків. citeturn3search1turn3search25  
- Yarn: має “global cache” і документовані cache strategies для спільного кешування між проєктами. citeturn3search34turn3search10  

Для macOS M2 з 64GB RAM і 3–8 worktrees я б рекомендував:  
- для Node-проєктів — стандартизувати **pnpm** як “worktree-friendly” менеджер (через hard links store),  
- для PHP — централізувати Composer cache і **не пробувати** шарити `vendor/` як symlink між worktrees (ризик некоректних post-install, прав доступу, і “змішаних” станів), натомість — швидкий reinstall з кешем. citeturn3search1turn2search11turn2search7  

**IDE/tooling & hooks**  
Git hooks працюють на checkout-операціях (наприклад, `post-checkout`). citeturn2search32  
У multi-worktree сценаріях часто виникає вимога: “hooks path різний на worktree”. Це можливо через per-worktree config (`git config --worktree`) у зв’язці з `extensions.worktreeConfig` — практично це використовують саме для `core.hooksPath`. citeturn2search0turn2search8turn2search4  
Для JetBrains екосистеми існують рішення на рівні IDE (плагіни/roadmap), що вказує на реальну практичність worktrees у IDE. citeturn3search7turn3search23  

**Ризики (що може піти не так)**  
- Некоректне/неповне очищення worktrees → “stale записів” у `$GIT_DIR/worktrees`, помилки add/remove, накопичення сміття; потрібні `prune/repair` як аварійні шляхи. citeturn1view1turn1view0  
- `--force` на `worktree remove` може знищити незакомічені артефакти агента (логи, diagnostic outputs), якщо вони не винесені в централізоване сховище. citeturn1view1  
- Дискова “експансія” через N×(`vendor`,`node_modules`) — без кеш-стратегії стане bottleneck на IO/SSD. citeturn3search15turn3search1turn2search11  

**Пріоритет**: **Critical** (ця тема — фундамент фізичної ізоляції для паралельних агентів).  

**Оцінка складності**: **16–28 год** (core worktree manager + naming + GC policy + кеші + мінімальні hooks).

## Стратегії злиття та інтеграції AI-згенерованих змін

**Поточна best practice (з джерелами)**  
Git має набір merge стратегій (`ort` як сучасний default backend, а також `recursive`, `octopus`, тощо) і дозволяє обирати стратегію/опції. citeturn0search5turn0search24  
Для “паралельних гілок” best practice у великих системах — уникати “batch merge, якщо є конфлікти”; зокрема `octopus` корисний для злиття багатьох гілок, але відмовляється при конфліктах, що робить його поганим вибором для AI-агентів із потенційними overlap’ами. citeturn0search24  
Git підтримує patch-based workflows через `git format-patch` (експорт комітів у патчі) і застосування через `git am`, що є “класичним” способом інтеграції змін (історично Git сам так приймає патчі). citeturn2search2turn2search30turn2search10  
Для автоматизації конфліктів Git має `rerere` (“reuse recorded resolution”), який записує ручне вирішення конфлікту і може застосовувати його при повторенні конфлікту; потрібне `rerere.enabled`. citeturn2search5turn2search1turn2search13  

**Рекомендований підхід для вашої системи**  
Я б розділив інтеграцію на два режими — залежно від того, чи ви хочете зберігати “агентську історію” як набір комітів, чи прагнете “1 таск = 1 conventional commit”.

**Режим A (1 таск = 1 commit, максимально чиста історія):**  
1) Агент працює у своєму worktree/гілці, робить локальні проміжні коміти (або навіть без них),  
2) Інтеграційний агент/Brain робить **squash** (наприклад, `git merge --squash <agentBranch>`),  
3) Створює один conventional commit у цільову гілку (main/develop). (GitHub дозволяє enforce merge methods; у PR-світі це відповідає squash merge політиці.) citeturn0search27turn0search24  

**Режим B (збереження авторства/комітів агента):**  
1) Агент робить conventional commits у своїй гілці,  
2) Інтеграція виконується `git format-patch <range>` і `git am` (або `cherry-pick`),  
3) За потреби — `rerere` для повторюваних конфліктів. citeturn2search2turn2search30turn2search5  

**Чому patch-based іноді кращий за merge для AI**  
У patch-based підході ви контролюєте “apply” як серію атомарних патчів/комітів і можете:  
- відсікти небажані hunks перед застосуванням (policy gate),  
- застосовувати в строгому порядку (dependency-aware),  
- уникнути “merge commit шуму” (особливо якщо ваша governance-модель прагне лінійної історії). Це узгоджується з тим, як `git format-patch` проектувався для обговорення/рев’ю і серійного застосування патчів. citeturn2search2turn2search30  

**Оптимальний порядок застосування 3–8 агентних результатів (серійна інтеграція)**  
У production я б зробив **детерміновану policy-функцію** “merge/apply order”, наприклад:  
- topological order за вашим dependency graph (output→input), якщо є,  
- далі — “low risk first”: менша кількість файлів/рядків, не торкається blacklisted/shared конфігів,  
- потім — high risk (auth/payments/config).  
Таке впорядкування прямо мінімізує шанс ранніх конфліктів і скорочує “blast radius” при відкаті, а Git-стратегії не суперечать такій серіалізації. citeturn0search24turn0search5  

**Автоматизація merge conflict resolution**  
- **`rerere` як базовий рівень**: увімкнути глобально на інтеграційному вузлі/кореневому репо, щоб повторювані конфлікти (типові для агента, який “однаково править один і той самий блок”) лікувались автоматично. citeturn2search5turn2search13turn2search1  
- **Custom merge drivers**: Git дозволяє налаштовувати merge поведінку для конкретних файлів через `.gitattributes` + драйвери (корисно для файлів, де “merge правила” доменно відомі). citeturn0search9turn0search13  
- **Lock-файли** (`composer.lock`, `package-lock.json`): практично краще не “зливати”, а **регерерувати** (інтеграційний крок після merge) — це доменна best practice, бо lock-файли часто мають нестабільні порядки/шуми. (Тут я формулюю як інженерний висновок; джерела вище підтверджують механізми merge drivers і patch workflows, але не “єдину правильну” політику для lock-файлів.) citeturn0search13turn2search2turn0search24  

**Інтеграційне тестування після merge**  
Після кожного застосування (або після кожного “рівня” застосувань) — запускати тести/валидації. Це прямо збігається з моделлю SWE-bench, де оцінка відбувається через застосування patch і запуск тестів у ізольованому середовищі. citeturn7search2turn7search10  

**Ризики**  
- `octopus`-merge при конфліктах відвалиться і може спричинити “порожні” спроби; потрібно серійне застосування. citeturn0search24  
- Без `rerere` конфлікти “повторюються” і з’їдають час інтеграції; з `rerere` з’являється ризик “неправильно застосованого старого рішення” при зміненому контексті, тому потрібен контроль “чи конфлікт справді той самий” (git робить це через хеші preimage/postimage). citeturn2search5turn2search1  
- Patch-based інтеграція зменшує merge commits, але вимагає жорсткішого контролю порядку застосування і більшої дисципліни щодо conventional commits. citeturn2search2turn0search27  

**Пріоритет**: **High** (без цього worktrees дадуть паралельність, але інтеграція стане bottleneck).  

**Оцінка складності**: **18–40 год** (policy order + rerere + patch/merge pipeline + lockfile policy + інтеграційні тести).

## Спільні ресурси при worktree-ізоляції: SQLite, MCP, конфіги, кеші

**Поточна best practice (з джерелами)**  
SQLite у WAL mode дає вищу concurrency: читачі не блокують писача і навпаки, але “multi-writer” проблема не зникає — одночасні записи потребують координації, інакше “database is locked”/busy ситуації неминучі. citeturn0search18turn0search10turn0search14turn0search32  
SQLite описує file locking як фундамент механізму конкурентного доступу, а WAL має власні нюанси (окремі `-wal` та `-shm` файли поруч із DB). citeturn0search10turn0search18turn0search22  

**Рекомендований підхід для вашої системи**  

**SQLite (vector memory) у multi-worktree**  
Рекомендую зробити “memory/SQLite” **поза worktree каталогами**, як єдиний абсолютний шлях (наприклад, `~/brain/state/<repo>/memory.sqlite`), а в кожен worktree підкладати:  
- або симлінк на файл (обережно з правами/локальними політиками),  
- або передавати абсолютний шлях через env/config.  
Критично: усі процеси мають посилатися на **той самий файл**, інакше ви отримаєте N різних пам’ятей, що зламає “enterprise knowledge persistence”. (Це — інженерний висновок на базі моделі SQLite locking і WAL: конкурентно безпечно лише тоді, коли lock-и накладаються на один і той самий inode/файл.) citeturn0search10turn0search18turn0search14  

Політика записів:  
- на стороні Brain (або виділеного “memory-writer” сервісу) серіалізувати write-транзакції;  
- агентам дозволяти read-heavy доступ;  
- налаштувати WAL + керований checkpointing, щоб WAL не роздувався і не деградував read performance. citeturn0search18turn0search22turn0search14  

**MCP сервери (доступ до інструментів/файлів)**  
Тут є два production-сумісні варіанти (і вибір залежить від того, чи MCP сервер “прив’язаний” до workspace):  
- **Per-worktree MCP instance** (ізоляція максимальна): кожен агент отримує власний MCP endpoint, який “rooted” у свій worktree. Це мінімізує ризик, що агент помилиться шляхом і змінить чужий робочий простір.  
- **Shared MCP instance з workspace-scoping**: один сервер, але кожен запит містить workspace root; сервер enforce’ить політику “не виходити за root”.  
Оскільки для LLM-агентів типова загроза — помилковий path traversal/редагування “не того місця”, enterprise-практика sandboxing у кодових агентів зазвичай включає обмеження запису “лише в активний workspace”. Це прямо задокументовано в security-моделі Codex CLI. citeturn6search2turn6search6turn6search26  

**Shared конфіги, які не можна правити паралельно**  
Ви вже маєте global blacklist. У worktree-архітектурі best practice — **додати enforcement gate**: якщо агент змінив blacklisted файл — задача автоматично перемикається в режим “integration required” (або “stuck/needs human” залежно від strictness) і не може бути merged автоматично. (Це — policy-надбудова; Git механіки тут дають лише можливість фіксувати diff/merge, а не гарантують доменну безпеку.) citeturn0search5turn1view1  

**Build artifacts & caches**  
- Composer cache — централізувати через `COMPOSER_CACHE_DIR`/`cache-dir`. citeturn2search11turn2search7  
- Node:  
  - pnpm store / Yarn global cache / npm cache — централізувати, але `node_modules` лишати per-worktree. citeturn3search1turn3search34turn3search24  

**Ризики**  
- SQLite WAL під високою write-конкуренцією: без серіалізації записів отримаєте `database is locked` і деградацію. citeturn0search14turn0search32turn0search18  
- Симлінки/нестандартні шляхи можуть взаємодіяти з sandboxing (на macOS `sandbox-exec` чутливий до шляхів і может поводитись інакше при symlink/firm link). citeturn4search30turn4search2  
- Shared кеші без keying можуть спричинити “контамінацію” або nondeterminism (залежить від менеджера пакетів і hardening режимів). citeturn3search10turn3search0  

**Пріоритет**: **Critical** (пам’ять і інструментальний доступ — це correctness і безпека).  

**Оцінка складності**: **24–60 год** (memory writer + WAL policy + MCP scoping/instances + cache standardization).

## Автоматизована оркестрація worktrees: локально, CI, Docker

**Поточна best practice (з джерелами)**  
Git дає повний набір команд для програмного керування worktrees (`add/remove/list/prune/repair/lock`). citeturn1view0turn1view1  
Git hooks (наприклад `post-checkout`) дозволяють виконувати автоматичні дії при checkout/worktree operations. citeturn2search32  
В Kubernetes/Argo світі standard-патерн для “робочого простору” — init container робить `git clone` в `EmptyDir`, а потім основний контейнер працює з цим volume; сама Argo документація прямо каже, що `GitRepoVolumeSource` deprecated і радить саме initContainer+EmptyDir. citeturn7search27turn5search3  

**Рекомендований підхід для вашої системи**  

**Локальний Brain orchestrator (macOS)**  
- Використовуйте `git worktree list --porcelain` як “source of truth” для registry активних worktrees та їхніх гілок/хешів (для recovery). citeturn1view0turn1view1  
- Після кожного run:  
  1) зняти “lock” (якщо був),  
  2) забрати артефакти (логи, звіти тестів) у централізовану директорію,  
  3) `git worktree remove`,  
  4) `git worktree prune` (і, опційно, `git gc` за політикою). citeturn1view0turn1view1  
- Для worktree-специфічних hookів: вмикайте `extensions.worktreeConfig` і задавайте `core.hooksPath` через `git config --worktree`, щоб hooks могли копіювати `.env`, виставляти локальні налаштування, і т.д. citeturn2search0turn2search8turn2search4  

**CI сценарії (GitHub Actions / загально)**  
У CI зазвичай простіше робити ізольовані checkout’и (як окремі jobs), але якщо ви хочете “кілька worktrees в одному job” (наприклад, batch-інтеграція), це технічно коректно: worktrees — це файлові директорії, а Git об’єкти спільні. citeturn1view0turn3search19  
Для caching залежностей у CI є established практики на рівні platform (наприклад, caching механізми в GitLab CI). Це важливо, бо повторні інстали `vendor/node_modules` без кешів роблять N-паралельність дороговартісною. citeturn3search32turn2search11turn3search24  

**Docker + worktree (для запуску тестів/інструментів)**  
Монтувати конкретний worktree в контейнер — життєздатний патерн, але на macOS важливо врахувати продуктивність bind mounts (file sharing між host і VM). Docker офіційно писав про gRPC-FUSE vs virtiofs і суттєві зміни продуктивності; в реальному світі це відчутно саме на проєктах з десятками тисяч файлів (типово для `vendor/node_modules`). citeturn5search10turn5search34turn5search38turn5search22  
Тому practical “enterprise” рекомендація:  
- **код редагувати на host (worktree)**,  
- **тести/лінтери запускати або на host**, або в контейнері з оптимізованим file sharing (virtiofs) і максимально можливою відмовою від bind mounts (де можливо — volumes). citeturn5search38turn5search10turn5search22  

**Ризики**  
- Складні hook-и, які змінюють файли під час checkout, можуть робити worktree “dirty” і блокувати `worktree remove` без `--force`. citeturn1view1turn2search32  
- Docker bind mounts на macOS можуть різко уповільнювати install/test цикли; неправильний режим file sharing → bottleneck. citeturn5search10turn5search38turn5search34  
- CI-кеші без дисципліни keying (по hash lockfile) можуть вводити “старі” залежності. citeturn3search10turn3search8  

**Пріоритет**: **High**.  

**Оцінка складності**: **20–48 год** (worktree manager + artifact collection + CI інтеграція + контейнерні тест-режими).

## Альтернативна або додаткова ізоляція до worktrees на macOS

**Поточна best practice (з джерелами)**  
На Linux часто використовують **bubblewrap (bwrap)** як низькорівневий sandbox builder, але bubblewrap **не підтримує macOS** (і це прямо проговорюється в issue tracker). citeturn4search0turn4search4  
**Firejail** — теж Linux-орієнтований (namespaces/seccomp-bpf) і не є практичним шляхом для macOS-воркстанції як “основний sandbox”. citeturn4search17turn4search33  
На macOS існує `sandbox-exec` (Seatbelt), але він позначений як deprecated; це підтверджується як практикою (manpage/обговорення), так і тим, що інструменти стикаються з edge cases. citeturn4search2turn4search6turn4search30  
Попри це, production tooling реально використовує Seatbelt/`sandbox-exec`: Codex CLI описує OS-level sandbox політики й прямо говорить про механізми на macOS. citeturn6search2turn6search6turn6search34  

Щодо overlayfs/unionfs на macOS: overlayfs — Linux kernel feature; на macOS типові альтернативи — FUSE-рішення (macFUSE), але вони мають істотні практичні обмеження/нестабільність у real workflows. citeturn4search15turn4search11turn4search3  

**Рекомендований підхід для вашої системи**  

**Базовий рівень (must-have)**: `git worktree` як фізична ізоляція коду (ваша основна тема). citeturn1view0turn3search19  

**Додатковий рівень безпеки (risk-based)**:  
- Для high-risk доменів (auth/payments/secrets) — додати “execution sandbox” для команд (тести, скрипти) через macOS Seatbelt, якщо ви готові інвестувати в підтримку профілів і edge cases. Те, що Codex підходом “write доступ лише в workspace” робить sandbox за замовчуванням, показує, що саме така модель вважається enterprise-адекватною. citeturn6search2turn6search6turn6search26  
- Для ще вищого рівня — контейнери (Docker), але на macOS їх треба застосовувати обережно через performance на bind mounts; найкраще — запускати тести в контейнері, а код редагувати на host у worktree. citeturn5search10turn5search38  

**Ізоляція dev environment per-agent**:  
Якщо проблема не лише у файлових конфліктах, а й у різних версіях toolchain’ів, Nix/Devbox дають “ізольовані dev shells” з репродуктивністю на macOS. Devbox позиціонується як інструмент для ізольованих середовищ на базі декларативного конфігу; Nix flakes — поширений шлях до reproducible dev environments. citeturn5search0turn5search4turn5search1turn5search29  

**Ризики**  
- `sandbox-exec` deprecated і може ламатися на специфічних файлових шляхах/посиланнях; це означає дорогий maintenance. citeturn4search2turn4search30turn4search6  
- Контейнери на macOS можуть “з’їдати” переваги worktrees через file sharing overhead (особливо Node/PHP залежності). citeturn5search10turn5search34turn5search38  
- FUSE/overlay-симуляції на macOS можуть бути нестабільними і важкими в підтримці. citeturn4search11turn4search15turn4search3  

**Пріоритет**: **Medium** (як доповнення; worktrees — уже critical).  

**Оцінка складності**:  
- Seatbelt sandbox рівня “commands only”: **24–80 год** (policy + edge cases). citeturn6search6turn4search30  
- Devbox/Nix як ізоляція toolchain: **10–24 год** (пілот + інтеграція в Brain runner). citeturn5search0turn5search1  

## Integration task pattern для паралельних пакетів worktree-результатів

**Поточна best practice (з джерелами)**  
У системах оцінювання агентів (SWE-bench) типовий pattern: “apply patch → run tests → перевірити інваріанти”, і це робиться в ізольованих середовищах для відтворюваності. citeturn7search2turn7search10turn7search6  
У продакшн-агентних інструментах модель часто “agent робить зміни → відкриває PR → людина/система рев’юить і мерджить”. GitHub описує Copilot coding agent як механізм, що робить зміни і відкриває PR, після чого просить review. citeturn6search13  

**Рекомендований підхід для вашої системи**  

**Коли створювати integration task**  
Рекомендую зробити правило “always after parallel batch”, але з fast-path для N=1:  
- якщо в run було **≥2 агентів**, integration task створюється завжди;  
- якщо торкались “shared/blacklisted” зон або виявлено конфлікти — integration task підвищує strictness і забороняє auto-merge без повного validate;  
- якщо N=1 — інтеграція може бути “inline” (merge не потрібен), але тест/validate все одно обов’язкові (у вашій системі це вже iron rule). citeturn7search2turn6search13  

**Scope інтеграційного агента**  
1) Серійно застосувати/злити гілки агентів у визначеному порядку (dependency/risk based). citeturn0search24turn0search5  
2) Вирішити конфлікти, використовуючи `rerere` і/або доменно-специфічні merge правила для деяких файлів. citeturn2search5turn0search13  
3) Зробити “lockfile policy”: або відхилити зміни lock-файлів від агентів і регенерувати централізовано, або дозволяти лише інтеграційному агенту їх міняти. (Це — governance-рішення; Git дає механізми, але не диктує політику.) citeturn0search13turn2search2  
4) Запустити тести: мінімум — smoke + релевантні suites; максимум — повний suite для high-risk. citeturn7search2turn7search10  

**Rollback стратегія (без “destructive git commands”)**  
У вас політика “без reset/clean”. Для інтеграції це означає:  
- якщо merge застосовано і тести зламались — робити **`git revert`** на інтеграційні коміти або відкотити окремий cherry-pick/patch, зберігаючи історію чистою і аудитованою. (GitHub як платформа merge-methods дозволяє політики історії; але конкретно “revert” — стандартний git-підхід для non-destructive відкатів.) citeturn0search27turn2search2  

**Ризики**  
- Якщо integration task пропускати, дефекти “на швах” (між двома validated підзадачами) пролізатимуть у mainline. citeturn7search2turn6search13  
- Регенерація lock-файлів може змінити залежності навіть без змін коду (особливо якщо lock/registry змінились), тому потрібні pinned lockfiles і детермінована політика. citeturn3search8turn2search11  

**Пріоритет**: **High**.  

**Оцінка складності**: **20–50 год** (інтеграційний pipeline + order policy + revert flow + тест-профілі).

## Enterprise-патерни з індустрії: як це роблять AI coding продукти та бенчмарки

**Поточна best practice (з джерелами)**  
Найвагоміший сигнал “що працює в продакшні” у 2024–2026 — те, що кілька AI coding IDE/CLI прямо прийшли до worktree/sandbox ізоляції:

- **Cursor**: у документації про parallel agents прямо сказано, що паралельні агенти запускаються у **своєму worktree** для ізоляції (щоб редагувати/білдити/тестити без взаємного впливу). citeturn6search3turn6search15turn6search35  
- **Windsurf**: в Arena Mode кожна модель отримує **свій worktree** для ізоляції. citeturn7search0turn7search4  
- **Codex CLI**: OpenAI описує, що sandbox політики enforce’яться OS-level механізмами; default включає обмеження запису в workspace і зазвичай “no network”, а CLI reference прямо згадує macOS Seatbelt і Linux Landlock/bubblewrap pipeline. citeturn6search2turn6search6turn6search34  
- **GitHub Copilot coding agent**: модель “агент робить зміни → відкриває PR → просить review” — це фактично enterprise-friendly інтеграційний контракт (людина/політики контролюють merge). citeturn6search13  
- **Devin**: Cognition просуває концепцію паралельних сесій (multiple Devins) у власних середовищах, а також рекомендує дроблення на ізольовані підзадачі. citeturn6search36turn6search12turn6search4  
- **SWE-agent / SWE-bench**: оцінювання агентів відбувається через застосування patch і запуск тестів, часто в Docker-ізольованих середовищах; це демонструє “apply→test” як базовий verification pattern. citeturn7search33turn7search2turn7search10  

Окрема “emerging” лінія 2026: дослідження пропонують **container-free sandboxes** для SWE агентів як спосіб зменшити overhead контейнерів, при цьому зберегти ізоляцію. Це релевантно вам як можливий напрям оптимізації, якщо container-based інтеграція занадто дорога, але worktree-ізоляції недостатньо. citeturn7search1turn7search29  

**Рекомендований підхід для вашої системи**  
Виходячи з індустріальних сигналів вище, найбільш “enterprise-сумісний” дизайн для вашого Brain виглядає так:

1) **Worktree-per-agent** як стандартний runtime для паралельного виконання (як у Cursor/Windsurf). citeturn6search3turn7search0  
2) **Sandbox-per-execution** (не обов’язково на кожну задачу; risk-based) як доповнення (як у Codex). citeturn6search2turn6search6  
3) **PR/patch як контракт інтеграції** (як у Copilot agent): агентні результати — це артефакт для інтеграції/рев’ю, а не direct write в mainline. citeturn6search13turn2search2  
4) **Apply→Test** як гарантія (як у SWE-bench) — і в ідеалі автоматика, яка не дає merged стану без test/validate. citeturn7search2turn7search10  

**Ризики**  
- “Worktree всюди” підсилює інтеграційний bottleneck, якщо merge policy слабкий або тест-профілі занадто дорогі; потрібні чіткі fast/slow lanes. citeturn0search24turn7search2  
- OS sandbox на macOS може бути fragile через deprecated статус і edge cases, тому варто мати fallback (контейнери/відмова від sandbox для low-risk). citeturn4search2turn6search2  

**Пріоритет**: **Medium** (це “прив’язка до реальності індустрії” + напрям оптимізації, але core робота вже в інших секціях).  

**Оцінка складності**: **8–20 год** (документування/політики/узгодження з вашим Brain; без реалізації sandbox).

## Пріоритизований план впровадження та загальна оцінка робіт

Нижче — консолідований enterprise-roadmap, який зберігає ваш песимістичний concurrency як fallback, але додає фізичну ізоляцію worktrees і керовану інтеграцію.

**Critical**  
- Worktree Manager (bare repo + worktree add/remove/prune/repair/lock), branch/worktree naming, recovery, артефакти логів. citeturn1view0turn1view1  
  **Оцінка**: 16–28 год.  
- Shared SQLite memory orchestration: абсолютний шлях, WAL policy, серіалізація writes, checkpoint policy. citeturn0search18turn0search14turn0search22  
  **Оцінка**: 24–60 год.  

**High**  
- Merge & integration pipeline: serial apply policy, rerere, patch-based або squash-based контракт, lockfile governance, revert-based rollback. citeturn2search5turn2search2turn0search27  
  **Оцінка**: 18–40 год.  
- Dependency caching standardization: Composer cache-dir + Node (pnpm/yarn/npm cache), keying по lockfile. citeturn2search11turn3search1turn3search24turn3search34  
  **Оцінка**: 8–20 год.  

**Medium**  
- Worktree-specific hooks (extensions.worktreeConfig + core.hooksPath), автокопія `.env`, policy checks на blacklisted files. citeturn2search8turn2search0turn2search32  
  **Оцінка**: 10–24 год.  
- Container/test acceleration на macOS (virtiofs tuning, мінімізація bind-mount болю). citeturn5search10turn5search22turn5search38  
  **Оцінка**: 10–30 год.  

**Low / R&D**  
- macOS Seatbelt sandbox (sandbox-exec) як execution sandbox: тільки якщо бізнес-ризики вимагають OS-level enforcement і ви готові підтримувати edge cases. citeturn6search2turn4search2turn4search30  
  **Оцінка**: 24–80 год.  
- Container-free sandboxes (напрямок 2026): розглянути як дослідницьку лінію для зниження overhead контейнерів у масовому масштабі. citeturn7search1turn7search29  

**Сумарна оцінка “до production-grade worktree orchestration”**: **~84–200 год** (діапазон залежить від глибини sandboxing і складності MCP/інтеграційних політик). citeturn1view0turn0search18turn2search5