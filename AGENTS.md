# AGENTS.md

Guía para agentes de codificación que trabajen en este repositorio. Agnóstica de
proveedor. Complementa a `README.md` (uso humano) y `STRATEGY.md` (criterios de
qué se automatiza y por qué); no los repite.

## Qué es esto

Suite E2E de API contra **TicketPe Núcleo** con Karate 1.5.1 + Maven + JUnit 5.
No hay código de producción: todo el repo es test. `src/main` no existe.

## Comandos

```sh
mvn test -Denvironment=prod                                              # suite completa (5 hilos)
mvn test -Denvironment=stag                                              # otro ambiente
mvn test -Denvironment=prod "-Dkarate.options=--tags @smoke"             # por tag
mvn test -Denvironment=prod "-Dkarate.options=--tags @compra,@entradas"  # varios tags (OR)
mvn test -Denvironment=prod "-Dkarate.options=--tags ~@negocio"          # excluir
mvn test -Denvironment=prod "-Dkarate.options=classpath:ticketpe/compra.feature"        # un feature
mvn test -Denvironment=prod "-Dkarate.options=classpath:ticketpe/compra.feature:12"     # un escenario (por línea)
```

- `-Denvironment=` es **obligatorio**. Sin él (o con valor inválido)
  `karate-config.js` corta la corrida con `ambiente desconocido: ...`.
- **Para correr un escenario suelto se usa `-Dkarate.options`, no `-Dtest=`.**
  Existe un único test JUnit (`ticketpe/runners/RunnerTest.java`) que levanta
  toda la carpeta; filtrar por clase no sirve.
- Reporte: `target/karate-reports/karate-summary.html`.
- `mvn` propaga las `-D` al JVM de Surefire y `karate-config.js` las lee con
  `karate.properties[...]`. Ese es el único canal de configuración.
- IntelliJ: runners versionados en `.run/*.run.xml` (duplicar y cambiar `name` +
  `<option value="-D...">` para agregar uno; marcar *Store as project file*).

## Arquitectura

```
pom.xml                                  karate-junit5, release 17, surefire 3.5.2
src/test/java/
  karate-config.js                       ambientes, tarjetas, timeouts, password
  ticketpe/
    runners/RunnerTest.java              Runner.path("classpath:ticketpe").parallel(5)
    *.feature                            un feature por dominio, un tag por feature
    data/*.json                          casos de los escenarios @datos
    helpers/*.feature                    fixtures @ignore invocados con call/callonce
```

Cuatro decisiones que hay que entender antes de tocar nada:

1. **`src/test/java` es a la vez fuente y test resource.** El `<testResources>`
   del `pom.xml` copia todo salvo `**/*Test.java` al classpath. Por eso los
   `.feature`, los JSON y `karate-config.js` se resuelven como
   `classpath:ticketpe/...`. Un `.feature` nuevo bajo `ticketpe/` entra a la
   suite solo por existir: no hay que registrarlo en ningún lado.

2. **Todo pasa por `karate-config.js`.** Ahí viven `baseUrl`, `cards`,
   `password`, `env` y los timeouts (`connectTimeout` 10 s, `readTimeout` 30 s).
   Agregar un ambiente = una línea en `environments` y otra en `testCards`. No
   existe forma de pasar una URL suelta por CLI: toda URL contra la que se corre
   está versionada y pasa por PR. Los features leen `cards.approved` /
   `cards.declined`, nunca un número de tarjeta literal.

3. **La suite corre en paralelo (5 hilos).** Ningún escenario puede depender del
   orden ni del estado que dejó otro. Cada uno arma sus propios datos en el
   `Background` con `call` / `callonce` a `helpers/`.

4. **Cero datos quemados.** `helpers/usuario.feature` registra un asistente
   nuevo por corrida (correo con UUID) y `helpers/evento-vendible.feature` elige
   en runtime un evento futuro, pagado y con cupo consultando el catálogo y la
   disponibilidad. El inventario del ambiente cambia; un `evento_id` fijo
   convierte la suite en falso rojo.

## Convenciones al escribir tests

- **Todo helper nuevo lleva `@ignore`** y vive en `helpers/`. El runner levanta
  la carpeta entera; sin `@ignore` el helper corre suelto, sin sus parámetros, y
  falla. Se invoca con `call read('helpers/x.feature') { param: valor }` o
  `callonce` cuando basta una vez por feature.
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
- **Un bug del API se documenta, no se esconde**: escenario con `@negocio` que
  fija el comportamiento actual, más una fila en la tabla de Hallazgos del
  README.

## CI

`.github/workflows/e2e.yml`: PR → `@smoke`; push a `main`, cron diario y
`workflow_dispatch` → suite completa (el dispatch acepta `tags` y `environment`).
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
