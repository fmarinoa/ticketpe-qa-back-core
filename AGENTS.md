# AGENTS.md

Guía para agentes de codificación que trabajen en este repositorio. Agnóstica de
proveedor. Complementa a `ARCHITECTURE.md` (decisiones estructurales),
`README.md` (uso humano), `STRATEGY.md` (criterios de qué se automatiza y por
qué) y `TAE.md` (gTAA, TAS vs SUT, trazabilidad y métricas); no los repite.

## Qué es esto

Suite E2E de API contra **TicketPe Núcleo** con Karate 1.5.1 + Maven + JUnit 5.
No hay código de producción: todo el repo es test. `src/main` no existe.

## Comandos

```sh
mvn test -Dkarate.env=prod                                              # suite completa (5 hilos)
mvn test -Dkarate.env=stag                                              # otro ambiente
mvn test -Dkarate.env=prod "-Dkarate.options=--tags @smoke"             # por tag
mvn test -Dkarate.env=prod "-Dkarate.options=--tags @ESC03,@ESC06"      # varios tags (OR)
mvn test -Dkarate.env=prod "-Dkarate.options=--tags ~@critico"          # excluir
mvn test -Dkarate.env=prod "-Dkarate.options=classpath:ticketpe/esc03-cobro-reserva.feature"     # un feature
mvn test -Dkarate.env=prod "-Dkarate.options=classpath:ticketpe/esc03-cobro-reserva.feature:11"  # un escenario (por línea)
mvn test -Dkarate.env=prod -Dci=true                                    # modo CI (log compacto)
mvn test -Dkarate.env=prod -Dtest=RunnerTest "-Dkarate.options=--tags @health"   # gate de salud del ambiente
mvn test -Dkarate.env=prod -Dtest=FrameworkTest                          # solo los tests del framework (TAS)
scripts/resumen-corrida.sh                                              # resumen y trazabilidad (tras un mvn test)
```

- `-Dkarate.env=` es **obligatorio**. Sin él (o con valor inválido)
  `karate-config.js` corta la corrida con `ambiente desconocido: ...`.
- **Para correr un escenario suelto se usa `-Dkarate.options`, no `-Dtest=`.**
  `RunnerTest` levanta `classpath:ticketpe` entero; filtrar por clase no elige
  escenarios. `-Dtest=` solo sirve para elegir runner: `RunnerTest` prueba el
  SUT, `FrameworkTest` prueba el framework.
- **`-Dkarate.options` se aplica a los dos runners** (es propiedad de JVM). Un
  filtro de tag que no matchee `framework/utils.feature` lo saltea.
- Reporte: `target/karate-reports/karate-summary.html`.
- `-Dci=true` compacta el log de consola (`logPrettyRequest` /
  `logPrettyResponse` en `false`); el reporte HTML no cambia. Lo pone el
  workflow; localmente se omite.
- `mvn` propaga las `-D` al JVM de Surefire y `karate-config.js` las lee con
  `karate.properties[...]`. Ese es el único canal de configuración.
- IntelliJ: runners versionados en `.run/*.run.xml` (duplicar y cambiar `name` +
  `<option value="-D...">` para agregar uno; marcar *Store as project file*).

## Arquitectura

En [`ARCHITECTURE.md`](ARCHITECTURE.md): las dos capas de configuración
(`karate-base.js` genérica → `karate-config.js` del proyecto) y su orden de
evaluación, los ambientes versionados en `config/*.json`, el classpath de
`src/test/java`, el paralelismo de 5 hilos y las restricciones de Karate que
rompen la corrida entera (claves de `karate.configure`, `logModifier`).

**Leerlo antes de tocar `karate-base.js`, `karate-config.js`, `config/*.json` o
el `pom.xml`.**

## Convenciones al escribir tests

- **Todo helper nuevo lleva `@ignore`** y vive en `helpers/`. El runner levanta
  la carpeta entera; sin `@ignore` el helper corre suelto, sin sus parámetros, y
  falla. Se invoca con `call read('helpers/x.feature') { param: valor }` o
  `callonce` cuando basta una vez por feature.
- **Un helper que crea una entidad devuelve todo lo necesario para usarla.**
  `usuario.feature` devuelve `correo`, `password`, `token` y `usuario`: para
  loguear a ese usuario se usa `alta.password`, nunca `ticketpe.password`. Si la
  credencial fuera global, un `callonce` la desincronizaría
  (ver [`ARCHITECTURE.md`](ARCHITECTURE.md#credenciales)).
- **Fuente única de casos: la matriz de diseño `testathon2026/diseno-pruebas/API.tsv`.**
  Un feature por escenario de la matriz (`escNN-*.feature`, tag `@ESCNN`), un
  Scenario por caso (`CPNN - ...`). No se agregan casos que no estén en la matriz.
  Los tags del Scenario son los de la columna *Tags* de la matriz
  más `@TC-API-NN` y `@datos` si es data-driven. `salud.feature` es la única
  excepción: es el gate de ambiente del CI (`@smoke` a nivel Feature, `@health`
  en su escenario).
- **Oráculo**: status e invariantes (dueño, estado, monto, cantidad de entradas)
  tal cual la matriz; el nombre del código de error, el que emite el API cuando
  el status coincide. Si el API no tiene código para ese caso, el de la matriz.
- **Trazabilidad obligatoria**: `@RIESGO-{CRITICO|ALTO|MEDIO|BAJO}` a nivel
  Feature (la severidad más alta del ESC) y `@REQ-HU-{épica}` a nivel Scenario. `scripts/resumen-corrida.sh`
  los lee del reporte y publica, por caso (`@TC-API-*`, los Examples cuentan
  como uno), los rojos ordenados por severidad y la cobertura por severidad, ESC,
  riesgo y requisito en el Job Summary. El catálogo
  de ids está en [`TAE.md`](TAE.md#3-trazabilidad-riesgo--requisito--escenario).
- **Una función nueva en `karate-base.js` lleva su escenario en
  `framework/utils.feature`.** Ese feature prueba el TAS, no el SUT: no hace
  HTTP y corre con `FrameworkTest`, no con `RunnerTest`.
- **Nombres de escenario en español**, describiendo la regla de negocio, no el
  endpoint: "no se puede reservar más entradas de las disponibles".
- **Aserciones de contrato, no solo de status**: `'#uuid'`, `'#number'`,
  `'#regex'`, `'#[2]'`, `match ... contains`.
- **Data-driven cuando solo cambia el dato**: los casos van en
  `ticketpe/data/*.json` y el Outline los lee con
  `Examples: | read('classpath:ticketpe/data/x.json') |`. Agregar un caso = un
  objeto más en el JSON, sin tocar Gherkin. Los JSON llevan tipos reales
  (números, `null`) y admiten matchers como `"#string"`.
- **Nada de `sleep`.** Si hiciera falta esperar, `retry until` de Karate.
- **Cero JS suelto en los asserts.** Antes de escribir un `function(){...}` en
  un feature, aplicar el árbol de decisión de
  [`ARCHITECTURE.md`](ARCHITECTURE.md#dónde-va-una-función-nueva).
- **`callonce` cachea por el texto de la línea**: dos `callonce` idénticos en un
  feature devuelven la misma entidad. Para dos usuarios distintos, `call`.
- **Un bug del API se documenta, no se esconde**: el escenario queda en rojo con
  la aserción de la matriz, más una fila en la tabla de Hallazgos del README.

## CI

`.github/workflows/e2e.yml`: PR → `@smoke`; push a `main`, cron diario y
`workflow_dispatch` → suite completa (el dispatch acepta `tags` y `environment`).
Siempre corre con `-Dci=true`.
Sube el reporte como artifact, escribe un resumen por feature en el Job Summary
y, fuera de los PR, despliega el reporte a GitHub Pages (copia
`karate-summary.html` a `index.html`). El build falla si falla un escenario
(`assertEquals(0, results.getFailCount())`).

Los `uses:` están **fijados por hash de commit** con el tag en comentario. Al
actualizar una action hay que cambiar el hash, no el tag.

## Contrato del API (no está en el OpenAPI publicado)

| Endpoint | Body | OK |
|---|---|---|
| `POST /auth/registro` | `{ nombre, correo, password }` | 201 |
| `POST /auth/login` | `{ correo, password }` | 200 |
| `POST /cotizaciones` | `{ evento_id, tipo, cantidad }` (`tipo` = nombre del tipo de entrada) | 200 |
| `POST /reservas` | igual que cotizaciones, bloquea 15 min | 201 |
| `POST /reservas/{id}/cupon` | `{ codigo }` | 200 |
| `POST /reservas/{id}/pago` | `{ tarjeta_prueba }` | 201 |
| `POST /entradas/{id}/transferir` | `{ correo_destino }` | 200 |
| `POST /entradas/{id}/reembolso` | `{ motivo }` | 201 |

Datos de prueba fijos (`config/roles.json`): el organizador de pruebas es dueño
del evento `evento_id` (check-in, reportes y `POST /cupones` solo sobre ese
evento); `attendee` es una cuenta demo con entradas de eventos ya iniciados
(CP19, CP21), porque no hay API para crear eventos ni mover el reloj.

Los rojos de la suite son hallazgos del API (tabla en el README), **no del test**.
No "arreglarlos" ajustando la aserción.
