# 1. OpenSpec como fuente de verdad viva: la spec solo cambia por delta-specs

## Contexto

FlowSync describe su comportamiento en `openspec/`, con el esquema `spec-driven` (`openspec/config.yaml`, sin `context` ni `rules` propios). Hoy hay dos piezas que conviene no confundir:

- **La spec viva**, una por capability: `openspec/specs/auth/spec.md` (19 requisitos, 45 scenarios) y `openspec/specs/tasks/spec.md` (32 requisitos, 124 scenarios). Dice cómo **debe** comportarse el sistema, requisito a requisito, con scenarios *WHEN/THEN* colgando de cada uno.
- **Los changes**, cada uno con `proposal.md`, `design.md`, `tasks.md` y unas **delta-specs** en `specs/<capability>/spec.md` que no reescriben la spec viva, sino que declaran qué requisitos se añaden (`ADDED`) o se sustituyen enteros (`MODIFIED`). Al archivar, la delta se funde en la spec viva y el change se mueve a `openspec/changes/archive/`.

Los tres changes archivados, todos de 2026-08-13, son los que han construido `tasks`:

| Change | `tasks` | `auth` |
|---|---|---|
| `add-task-list` | crea la capability: `Purpose` y 14 `ADDED` | 3 `MODIFIED` (los destinos tras entrar pasan a ser la lista) y 1 `ADDED` |
| `add-task-status-filter` | 7 `ADDED`, 4 `MODIFIED` | — |
| `add-task-due-date` | 11 `ADDED`, 1 `MODIFIED` | — |

14 + 7 + 11 son exactamente los 32 requisitos vivos de `tasks`. `auth`, en cambio, no tiene ningún change que la origine: entró ya escrita como spec viva en el mismo commit (`04940fc`), y su historia anterior no está en `openspec/`.

La relación no ha sido siempre limpia, y eso es lo que motiva este ADR:

- **El filtro por estado (FS-142) se implementó sin tocar `openspec/`**; el encargo decía expresamente «no toques openspec/». El código filtraba y la spec viva seguía afirmando que `GET /api/v1/tasks` devolvía «todas las tareas del espacio». `add-task-due-date` dejó constancia de la deriva en su propuesta sin arreglarla, y hubo que escribir después `add-task-status-filter` como change **retroactivo**, que documenta código ya en marcha y corrige con `MODIFIED` los dos requisitos que mentían (commit `209df12`).
- **Un mismo requisito se ha sustituido entero en tres changes**: «Una sola vista de tareas, sin señales de presencia» nace en `add-task-list` y lo reescriben con `MODIFIED` tanto `add-task-status-filter` como `add-task-due-date`. El texto vivo depende del orden en que se archivaron.
- **Hoy siguen abiertas al menos dos diferencias entre spec y código:**
  - el scenario «Estado inventado» exige `422` para `GET /api/v1/tasks?status=archivado`, y el código responde `200` con lista vacía;
  - `PUT /api/v1/tasks/:id/due-date` exige un `today` que la spec no menciona.
- **Los scenarios casi no tienen pruebas.** Dos de los tres changes dejan los tests fuera a propósito («Sin tests», por decisión de quien encarga), y hoy solo 3 de los 124 scenarios de `tasks` tienen un test que los compruebe.

Alrededor de la spec hay otras fuentes que también dicen cosas del comportamiento:

- **Entradas:** el PRD (`docs/prd/`) y las historias del backlog (`docs/backlog/`), con sus `CA-*` y `PA-*`, que las propuestas citan.
- **Derivados:** el código, los tests, el documento OpenAPI que sirve `/api.json` y `docs/architecture.md`.

`docs/backlog/README.md` ya establece que el tablero es seguimiento y que, si contradice al repositorio, manda el repositorio. Falta decir **qué** del repositorio manda.

## Decisión

**La spec viva de `openspec/specs/` es la fuente de verdad del comportamiento de FlowSync, y la única forma de cambiarla es una delta-spec dentro de un change de OpenSpec.**

En concreto:

1. **Ningún cambio de comportamiento entra sin su change.** Antes de tocar código se abre un change en `openspec/changes/<nombre>/`, con su propuesta, su diseño, sus tareas y sus delta-specs. Para eso están las skills `openspec-propose`, `openspec-apply-change` y `openspec-archive-change` de `.claude/`.
2. **La delta-spec es lo que se revisa.** Un `MODIFIED` copia el requisito entero tal como queda, no solo lo que cambia, para que la revisión se haga sobre el texto final.
3. **Archivar es la parte que más importa del change.** Hasta que la delta no se funde en la spec viva, el comportamiento nuevo no existe a efectos del contrato. Un change sin archivar es trabajo en curso.
4. **Los changes archivados son historia, no verdad.** Explican por qué la spec dice lo que dice, pero no se consultan para saber qué hace el sistema: para eso está la spec viva.
5. **Si el código va por delante, se escribe un change retroactivo**, como `add-task-status-filter`, y su propuesta lo dice desde la primera línea. Si el código va por detrás o contradice a la spec, es un fallo del código, salvo que un change decida explícitamente lo contrario.
6. **Lo demás se deriva y se contrasta contra la spec:**
   - el PRD y el backlog son entrada;
   - los tests trazan scenarios;
   - el OpenAPI y los diagramas describen lo que existe.

   Ninguno de ellos manda sobre la spec.

## Estado

Aceptada, 2026-10-27.

Registra una práctica que ya se seguía desde `add-task-list`, y la regla 5 recoge lo que se aprendió con FS-142. No sustituye a ningún ADR anterior.

## Consecuencias

**Lo que ganamos**

- **Un único sitio donde leer qué debe hacer el sistema.** Las propuestas dicen el porqué; la spec viva dice el qué, ya fundido y sin tener que reconstruirlo a partir de commits.
- **Revisión sobre texto, no sobre diffs de código.** Las delta-specs dejan ver qué requisitos nacen, cuáles se reescriben y con qué redacción final, antes de que haya nada implementado.
- **Algo contra lo que verificar.** La matriz de trazabilidad scenario → test, la revisión adversarial y el contraste del OpenAPI pueden anclarse a requisitos concretos y citarlos por nombre.
- **Los cambios de opinión quedan explicados.** Cada `MODIFIED` tiene detrás una propuesta con su porqué, y las decisiones abiertas del PRD quedan escritas donde se tocaron: `add-task-list` cierra PA-9 (200 caracteres) y PA-7 (transiciones libres), y deja PA-3 anotado como abierto.

**Lo que nos cuesta**

- **Ceremonia en cada cambio.** Incluso un ajuste pequeño paga propuesta, diseño, tareas, delta y archivo. Es la tentación que llevó a implementar FS-142 por fuera, y seguirá apareciendo cada vez que haya prisa.
- **La spec no se hace cumplir sola.** `openspec validate` comprueba el formato, no que el código haga lo que dice el texto. La deriva de FS-142 no la detectó ninguna herramienta, y hoy conviven dos diferencias abiertas (el `422` del estado inventado y el `today` del `PUT`) en una spec que se presenta como verdad. Mientras falten tests, es una verdad declarada, no comprobada: 3 de 124 scenarios de `tasks` tienen prueba.
- **`MODIFIED` reescribe el requisito entero.** Dos changes en paralelo que toquen el mismo requisito chocan, y el último en archivarse gana. Ya hay un requisito reescrito por tres changes, y el orden de archivo no se ve en las carpetas porque las tres llevan la misma fecha.
- **Los changes retroactivos pueden legitimar fallos.** Documentar «lo que el código ya hace» convierte en contrato lo que el código haga, incluido lo que haga mal. Exige leer el código con ojo crítico antes de escribir la delta, no solo describirlo.
- **Dos fuentes de requisitos río arriba.** El PRD y el backlog siguen existiendo y evolucionando. Cada historia nueva hay que traducirla a requisitos y scenarios, y una historia actualizada no cambia nada hasta que alguien abre un change.
- **Dependemos de una herramienta y de su formato.** El flujo descansa en la CLI de OpenSpec y en skills locales, y `config.yaml` no fija convenciones propias, así que hoy viven en los prompts. Además, `auth` no tiene un change de origen, de modo que su porqué no está en `openspec/`.
- **Lo que no se escribe no existe.** Requisitos como «no hay vista de mis tareas» o «la lista no lleva vencimiento» deben estar escritos para protegerse. Cada promesa en negativo que se olvide en la spec queda sin defensa frente a un change futuro.
