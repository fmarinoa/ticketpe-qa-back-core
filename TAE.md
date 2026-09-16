# TAE — Arquitectura de automatización

Este documento existe para lo que el código no dice: **qué decisiones de
ingeniería de automatización se tomaron y por qué**, en el vocabulario del
syllabus ISTQB CTAL-TAE.

Uso y comandos: [`README.md`](README.md) · decisiones estructurales de Karate:
[`ARCHITECTURE.md`](ARCHITECTURE.md) · qué se automatiza y por qué:
[`STRATEGY.md`](STRATEGY.md) · reglas para agentes: [`AGENTS.md`](AGENTS.md).

## 1. TAS y SUT: dos cosas que se prueban por separado

| | SUT | TAS |
|---|---|---|
| Qué es | API TicketPe Núcleo | esta suite |
| Quién lo prueba | `ticketpe/*.feature` | `framework/utils.feature` |
| Runner | `ticketpe/runners/RunnerTest.java` | `framework/FrameworkTest.java` |
| Reporte | `target/karate-reports` | `target/karate-reports-framework` |

El TAS **también tiene defectos** y los suyos son peores: se disfrazan de fallo
del SUT. Si `utils.round` redondeara mal, `esc02-precio-cupones.feature` se
pondría roja y el triage culparía al API. Por eso las funciones de
`karate-base.js` y `karate-config.js` tienen sus propios escenarios, sin HTTP,
con runner y reporte separados. Un rojo en `FrameworkTest` significa "la suite
está rota", no "el producto está roto", y eso se lee en el nombre del job.

```sh
mvn test -Dkarate.env=prod -Dtest=FrameworkTest
```

## 2. gTAA: dónde cae cada archivo

La arquitectura genérica de automatización del syllabus tiene cuatro capas. El
mapeo real de este repo:

| Capa gTAA | Aquí | Estado |
|---|---|---|
| **Test Generation** | `ticketpe/data/*.json` leídos por `Examples:` | parcial — los casos se escriben a mano, no se derivan de un modelo |
| **Test Definition** | `ticketpe/*.feature` | completa |
| **Test Adaptation** | `helpers/*.feature` (HTTP), `karate-base.js` (genérico), `karate-config.js` (dominio) | completa |
| **Test Execution** | `RunnerTest.java`, `FrameworkTest.java`, `.github/workflows/e2e.yml` | completa |

El corte entre `karate-base.js` y `karate-config.js` es la separación que el
syllabus llama *genérico vs. específico del proyecto*: la capa de abajo es
portable a otro repo sin editar una línea; la de arriba conoce TicketPe. El
criterio de reparto y el árbol de decisión están en
[`ARCHITECTURE.md`](ARCHITECTURE.md#dónde-va-una-función-nueva).

**Hueco consciente en Test Generation.** No hay MBT ni generación desde el
OpenAPI, porque el contrato real no está publicado (ver la tabla de endpoints en
[`AGENTS.md`](AGENTS.md)). Los data-driven de `ticketpe/data/` son el sustituto
barato: agregar un caso es un objeto JSON, no Gherkin nuevo.

## 3. Trazabilidad: riesgo → requisito → escenario

Un contador de "46 escenarios verdes" no responde la única pregunta que importa
antes de un release: **¿qué riesgo de negocio quedó cubierto?**

Dos tags lo resuelven, y el reporte de Karate ya los transporta:

- `@RIESGO-{CRITICO|ALTO|MEDIO|BAJO}` — a nivel **Feature**. Sale de la tabla de
  impacto x probabilidad de regresión de [`STRATEGY.md`](STRATEGY.md#1-qué-se-automatiza-y-por-qué).
- `@REQ-{DOMINIO}-{NN}` — a nivel **Scenario**. Identifica la regla de negocio,
  no el endpoint.

Los ids salen de la matriz de diseño (`testathon2026/diseno-pruebas/API.tsv`):
`@RIESGO-*` es la severidad más alta de los casos del ESC y `@REQ-HU-*` la
historia de usuario del caso. `@TC-API-NN` conserva el id del caso.

| Riesgo | Feature |
|---|---|
| CRITICO | `esc01-control-acceso`, `esc03-cobro-reserva`, `esc05-fuga-datos`, `esc06-transferencia-estado-invalido`, `esc08-checkin` |
| ALTO | `esc02-precio-cupones`, `esc04-cupo-reserva`, `esc07-reembolso` |
| BAJO | `salud` |

| Requisito | Casos |
|---|---|
| `REQ-HU-E1.2` | CP03 |
| `REQ-HU-E1.3` | CP01 |
| `REQ-HU-E3.1` | CP05, CP06 |
| `REQ-HU-E3.2` | CP11 |
| `REQ-HU-E3.3` | CP07, CP08, CP09, CP13 |
| `REQ-HU-E4.1` | CP02 |
| `REQ-HU-E4.2` | CP16, CP17, CP18, CP19 |
| `REQ-HU-E4.3` | CP20, CP21 |
| `REQ-HU-E5.1` | CP22, CP23 |
| `REQ-HU-E5.2` | CP14 |
| `REQ-SAL-01` | salud del servicio |

`scripts/resumen-corrida.sh` reconstruye esta matriz **desde la corrida**, no
desde el código: lee los tags del reporte JSON y emite, por caso de la matriz
(`@TC-API-*`; los Examples de un Outline cuentan como uno), los rojos ordenados
por severidad y la cobertura por severidad, ESC, riesgo y requisito. El workflow
lo pega en el Job Summary, así que cada corrida responde "4 P1 críticos en rojo"
sin que nadie abra el HTML.

```sh
scripts/resumen-corrida.sh                 # tras un mvn test
scripts/resumen-corrida.sh target/karate-reports
```

## 4. Testability pedida al SUT: `X-Request-Id`

Un fallo en CI contra un ambiente compartido deja una pregunta abierta: *¿qué
pasó del otro lado?* Sin correlación, el triage es adivinanza.

`karate-base.js` acuña un `traceId` por escenario y lo manda en cada request:

```
X-Request-Id: qa-3f2b9c4e-...
```

`karate.configure('headers', ...)` lo pone como default y `auth.bearer(token)` lo
propaga cuando el escenario reemplaza los headers con los suyos. El id queda en
el reporte HTML publicado; con él se filtra el log del SUT sin repetir la corrida.

Esto es un **requisito de testability hacia desarrollo**, no una utilidad del
test: el valor aparece solo si el backend loguea la cabecera. Está pedido; si el
SUT no lo hace todavía, el costo del lado del test ya está pagado (2 líneas).

## 5. Clasificación de fallos: ambiente ≠ regresión

El error más caro de una suite E2E no es el falso negativo: es **48 rojos porque
el ambiente estaba caído** y media hora de triage para descubrirlo.

El pipeline pregunta en orden **de lo barato a lo caro, y de adentro hacia
afuera**. Cada paso falla con su propio nombre, así el veredicto se lee en la
lista de steps sin abrir un log:

1. **Verificación del TAS** (`e2e.yml`, primer step de test). `FrameworkTest`
   solo: sin red, ~1 s. Si la suite está rota no tiene sentido interrogar al
   SUT — los 48 escenarios siguientes producirían triage falso.
2. **Gate de salud** (`e2e.yml`, antes de la suite). Corre `salud.feature` sola:
   `-Dtest=RunnerTest "-Dkarate.options=--tags @health"`. Si el ambiente no
   responde sano, la suite **no corre** y el job falla con
   `::error title=Ambiente caido::`. El veredicto es inequívoco antes del primer
   escenario de negocio.

   El gate reusa el feature en vez de un `curl` a propósito: el contrato de
   salud (`estado: ok`, `base_de_datos: conectada`) y la resolución del
   `baseUrl` por ambiente ya viven en el repo. Un `curl` con `jq` los
   duplicaría, y esa copia se desincroniza en silencio el día que cambie
   `config/baseUrl.json` o el body de `/health`.

   `-Dtest=RunnerTest` es necesario: `-Dkarate.options` aplica a todos los
   runners de la JVM, y `FrameworkTest` no tiene escenarios `@health`.
3. **Corte de configuración** (`karate-config.js`, dentro de cualquiera de los
   dos anteriores). Un `karate.env` sin `baseUrl` corta con
   `ambiente desconocido: <env>` en vez de 48 `UnknownHostException`.
4. **Triage asistido** (`scripts/analizar-fallo.sh`, solo si falla la suite).
   Junta commit, ambiente, escenarios fallidos, tags y el paso exacto que
   rompió, y lo manda a analizar.

Cuatro categorías de rojo con una señal distinta cada una:

| Step en rojo | Qué significa | Quién lo arregla |
|---|---|---|
| Verificar el framework (TAS) | la suite está rota | QA automation |
| Gate de salud del ambiente | el ambiente está caído | infraestructura |
| cualquiera, con `ambiente desconocido` | configuración inválida | quien lanzó la corrida |
| Ejecutar suite | regresión del producto | desarrollo |

El paso de la suite corre **los dos runners** a propósito: los steps previos son
fail-fast, no reemplazan el alcance real de la corrida.

## 6. Métricas de la automatización

Distinción del syllabus: métricas **del SUT** (cuántos defectos encontró) vs.
métricas **del TAS** (si la automatización sirve). Hoy se publican:

| Métrica | De dónde | Dónde se ve |
|---|---|---|
| Veredicto y casos en rojo por severidad, con `feature:línea` y primer fallo | `resumen-corrida.sh` | Job Summary |
| Cobertura por severidad, ESC, riesgo y requisito | `resumen-corrida.sh` | Job Summary |
| Tiempo de corrida y eficiencia del paralelismo | Karate (`elapsed`, `efficiency`) | log y reporte HTML |
| Degradación del ambiente en el tiempo | cron diario sobre el mismo código | historial de runs |
| Salud del propio TAS | `FrameworkTest` | job de CI |

El cron diario es lo que separa una métrica de producto de una de ambiente:
mismo commit, distinto día — si cambia el resultado, no fue el código.

**Pendiente de la sección 8:** flakiness rate y duración por escenario exigen
histórico; hoy cada run es independiente.

## 7. Riesgos del propio TAS y cómo se mitigan

| Riesgo del TAS | Mitigación en el repo |
|---|---|
| Datos quemados que caducan | cada corrida registra su usuario y elige evento en runtime (`helpers/`) |
| Colisión entre hilos | correo con UUID; ningún escenario depende del estado de otro |
| Credencial versionada | `utils.randomPassword()`; el reporte publica credenciales de usuarios desechables |
| Correr contra una URL no revisada | no hay forma de pasar URL por CLI: todo ambiente pasa por PR |
| Helper que corre suelto y falla | `@ignore` obligatorio en `helpers/` |
| Enmascarar un bug del API ajustando la aserción | el escenario queda en rojo con la aserción de la matriz y el hallazgo se lista en el README |
| Suite que pasa porque no prueba nada | `failWhenNoScenariosFound` por defecto en Karate + `assertEquals(0, failCount)` |
| El TAS se rompe sin que nadie lo note | `framework/utils.feature` |

## 8. Mejora continua — bitácora

| Fecha | Cambio | Motivo (ISTQB) |
|---|---|---|
| 2026-09 | `karate-base.js` separado de `karate-config.js` | capa genérica vs. específica del proyecto |
| 2026-09 | data-driven a `ticketpe/data/*.json` | mantenibilidad: agregar caso sin tocar Gherkin |
| 2026-09 | `-Dci=true` compacta el log | reporte legible en pipeline |
| 2026-09 | tags `@RIESGO-*` / `@REQ-*` + `resumen-corrida.sh` | reporting por riesgo y por escenario roto, no por archivo |
| 2026-09 | `framework/utils.feature` + runner propio | verificación del TAS |
| 2026-09 | `X-Request-Id` por escenario | testability hacia el SUT |
| 2026-09 | gate de salud antes de la suite | clasificación de fallos |

**Backlog priorizado** (no implementado a propósito):

1. Histórico de corridas en Pages para flakiness rate y tendencia de duración.
2. `karate-gatling` reutilizando estos features para un smoke de performance.
3. Limpieza de datos: hoy cada corrida deja un usuario huérfano. No hay endpoint
   de baja — **deuda aceptada**, no olvido. Se paga cuando el API lo exponga.
4. Capa de servicio (`api/*.feature`) envolviendo endpoints. Hoy sería una capa
   por la capa: `helpers/` ya abstrae lo que se repite. Se justifica si el
   contrato empieza a cambiar seguido.
