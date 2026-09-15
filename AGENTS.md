# AGENTS.md

Guía para agentes de codificación que trabajen en este repositorio. Agnóstica de
proveedor. Complementa a `ARCHITECTURE.md` (decisiones estructurales),
`README.md` (uso humano) y `STRATEGY.md` (criterios de qué se automatiza y por
qué); no los repite.

## Qué es esto

Suite E2E de API contra **TicketPe Núcleo** con Karate 1.5.1 + Maven + JUnit 5.
No hay código de producción: todo el repo es test. `src/main` no existe.

## Comandos

```sh
mvn test -Dkarate.env=prod                                              # suite completa (5 hilos)
mvn test -Dkarate.env=stag                                              # otro ambiente
mvn test -Dkarate.env=prod "-Dkarate.options=--tags @smoke"             # por tag
mvn test -Dkarate.env=prod "-Dkarate.options=--tags @compra,@entradas"  # varios tags (OR)
mvn test -Dkarate.env=prod "-Dkarate.options=--tags ~@negocio"          # excluir
mvn test -Dkarate.env=prod "-Dkarate.options=classpath:ticketpe/compra.feature"        # un feature
mvn test -Dkarate.env=prod "-Dkarate.options=classpath:ticketpe/compra.feature:12"     # un escenario (por línea)
mvn test -Dkarate.env=prod -Dci=true                                    # modo CI (log compacto)
```

- `-Dkarate.env=` es **obligatorio**. Sin él (o con valor inválido)
  `karate-config.js` corta la corrida con `ambiente desconocido: ...`.
- **Para correr un escenario suelto se usa `-Dkarate.options`, no `-Dtest=`.**
  Existe un único test JUnit (`ticketpe/runners/RunnerTest.java`) que levanta
  toda la carpeta; filtrar por clase no sirve.
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
- **Un tag por dominio** (`@auth`, `@catalogo`, `@cotizacion`, `@compra`,
  `@entradas`, `@autorizacion`) a nivel Feature, más `@smoke` en el happy path de
  cada dominio, `@datos` en los data-driven y `@negocio` en los que congelan un
  comportamiento cuestionable del API. `salud.feature` va con `@smoke` a nivel
  Feature (y un `@health` en su escenario).
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
- **Un bug del API se documenta, no se esconde**: escenario con `@negocio` que
  fija el comportamiento actual, más una fila en la tabla de Hallazgos del
  README.

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

Fuera de alcance a propósito: `POST /soporte` (contrato no deducible) y los happy
paths de `POST /checkin` y `GET /reportes/ventas` (requieren un rol que el
registro público no entrega; solo se cubren sus 401/403).

Hallazgo abierto: `POST /reservas/{id}/pago` emite `cantidad + 1` entradas y
cobra solo por `cantidad`. El escenario feliz de `compra.feature` lo asserta en
`cantidad` y por eso queda en rojo: **es un bug del API, no del test**. No
"arreglarlo" ajustando la aserción.
