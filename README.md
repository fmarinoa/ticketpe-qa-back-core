# ticketpe-qa-back-core

Pruebas E2E de backend para la API **TicketPe Núcleo**
(`https://testathon.testingperu.com/api/core`) con [Karate](https://docs.karatelabs.io/) 2.1.2 sobre Maven + JUnit 6.

> **Estado al 2026-09-16:** suite reestructurada a los 19 casos automatizables de
> la matriz `diseno-pruebas/API.tsv` (45 escenarios con los Examples). Contra
> `prod`: 34 verdes, 11 rojos. Los rojos son hallazgos reales del API, no tests
> mal escritos (ver "Hallazgos").

## Requisitos

- Java 21+ (Karate v2 lo exige; el `pom.xml` compila con `maven.compiler.release=21`; el SDK del IDE puede ser mayor, p. ej. Java 26)
- Maven 3.9+

## Ejecutar

```sh
mvn test -Dkarate.env=prod                                # toda la suite (5 hilos)
mvn test -Dkarate.env=stag                                # contra staging
mvn test -Dkarate.env=local                               # contra localhost:4100
mvn test -Dkarate.env=prod "-Dkarate.options=--tags @smoke"             # solo el smoke
mvn test -Dkarate.env=prod "-Dkarate.options=--tags @ESC03,@ESC06"      # varios tags (OR)
mvn test -Dkarate.env=prod "-Dkarate.options=--tags ~@critico"          # excluir un tag
mvn test -Dkarate.env=prod "-Dkarate.options=classpath:ticketpe/esc03-cobro-reserva.feature"
```

## Ambientes

Las URL base están versionadas en `src/test/java/config/baseUrl.json`:

| Ambiente | URL |
|---|---|
| `prod` | `https://testathon.testingperu.com/api/core` |
| `stag` | `https://testathon.stag.testingperu.com/api/core` |
| `local` | `http://localhost:4100/api/core` |

Se elige con `-Dkarate.env=<nombre>` (también sirve `-Dkarate.env=` o la
variable `KARATE_ENV`). **El flag es obligatorio**: sin ambiente, o con uno que
no existe, la corrida falla de inmediato con
`ambiente desconocido: x (usar -Dkarate.env=prod|stag|local)`. No hay forma de
pasar una URL suelta por línea de comandos: toda URL contra la que se corre está
versionada en el repo y revisada en un PR.

Las tarjetas de prueba también van por ambiente, en
`src/test/java/config/cards.json`. Hoy son las mismas en los tres; están
separadas para que un ambiente pueda cambiar su pasarela sin tocar los features.
Los escenarios las leen como `ticketpe.cards.approved` /
`ticketpe.cards.declined`, nunca por número literal.

Agregar un ambiente = una clave en `config/baseUrl.json` y otra en
`config/cards.json`.

## Runners en IntelliJ IDEA

El repo versiona configuraciones compartidas en `.run/`; IntelliJ las carga solas
al abrir el proyecto y aparecen en el selector de Run:

| Runner | Qué corre |
|---|---|
| Suite completa (prod) | `mvn test -Dkarate.env=prod` |
| Smoke (prod) | `mvn test -Dkarate.env=prod -Dkarate.options=--tags @smoke` |
| Suite completa (stag) | `mvn test -Dkarate.env=stag` |
| Suite completa (local) | `mvn test -Dkarate.env=local` |

Para uno nuevo: duplicar un `.run/*.run.xml`, cambiar `name` y los `<option value="-D...">`.
Si lo creas desde la UI, marca **Store as project file** para que quede versionado.

Reporte HTML: `target/karate-reports/karate-summary.html` (dashboard con filtro por tags; `karate-timeline.html` muestra el uso de hilos).
`RunnerTest` también emite `junit-xml/`, `cucumber-json/` y `karate-json/karate-events.jsonl` (el stream que leen los scripts).

Surefire propaga las `-D` del comando `mvn` al JVM de los tests, y
`karate-config.js` las lee con `karate.properties[...]`.

## Estructura

```
pom.xml
src/test/java/
  karate-base.js                      utilidades genéricas (utils.*, auth.*, traceId)
  karate-config.js                    ambientes, credenciales y tarjetas de prueba
  framework/
    FrameworkTest.java                runner del TAS (reporte aparte)
    utils.feature                     verifica el framework, sin tocar el SUT
  config/
    baseUrl.json                      URL base por ambiente
    cards.json                        tarjetas de prueba por ambiente
  ticketpe/
    runners/RunnerTest.java           runner JUnit (Runner.path("classpath:ticketpe").parallel(5))
    salud.feature                           gate de ambiente del CI
    esc01-control-acceso.feature            CP01-CP03  rol x endpoint, entrada ajena, escalada en registro
    esc02-precio-cupones.feature            CP05-CP07  desglose al céntimo, cupón inválido, cupones apilados
    esc03-cobro-reserva.feature             CP08-CP09  doble pago, resultado por tarjeta
    esc04-cupo-reserva.feature              CP11       tope de 4 por evento
    esc05-fuga-datos.feature                CP13-CP14  QR adivinable, datos en el reporte
    esc06-transferencia-estado-invalido.feature  CP16-CP19  usada, transferida, reembolso, evento iniciado
    esc07-reembolso.feature                 CP20-CP21  doble reembolso, evento iniciado
    esc08-checkin.feature                   CP22-CP23  QR anterior, doble check-in
    data/
      cotizacion-desglose.json              CP05: precio, cupón y desglose esperado
      tarjetas.json                         CP09: tarjeta y resultado esperado
    helpers/
      usuario.feature                 registra un asistente nuevo y devuelve token
      login.feature                   login de un rol fijo (config/roles.json)
      evento-vendible.feature         elige evento futuro, pagado y con cupo (soloEvento / excluirEvento)
      disponibilidad.feature          consulta /eventos/{id}/disponibilidad
      entrada-comprada.feature        reserva + pago y devuelve la entrada emitida
      cupon.feature                   el organizador crea un cupón porcentual para su evento
      cupon-agotado.feature           cupón de un uso ya consumido
      pago-paralelo.feature           dos pagos simultáneos con la misma Idempotency-Key
      entrada-evento-iniciado.feature entrada vigente de un evento ya iniciado (cuenta demo)
```

Los helpers están marcados `@ignore` (no corren solos) y evitan datos quemados:
`usuario.feature` registra un asistente nuevo por corrida y
`evento-vendible.feature` elige en runtime un evento futuro, pagado y con cupo,
porque el inventario del ambiente cambia.

`karate-config.js` también fija `connectTimeout=10000`, `readTimeout=30000` y un
`retry` global de 3 intentos cada 1 s.

Cómo se reparten `karate-base.js` y `karate-config.js`, y qué restricciones de
Karate obligan a ese corte: [`ARCHITECTURE.md`](ARCHITECTURE.md).

## Tags disponibles

| Tag | Dónde |
|---|---|
| `@ESC01`..`@ESC08` | a nivel Feature, un feature por escenario de la matriz |
| `@TC-API-NN` | id del caso en la matriz, a nivel Scenario |
| `@api` `@p1` `@p2` `@critico` `@alto` `@medio` `@funcional` `@seguridad` `@estado` `@dinero` `@autorizacion` `@regulatorio` `@regresion` | columna *Tags* de la matriz, a nivel Scenario |
| `@smoke` / `@health` | solo `salud.feature` (gate de ambiente) |
| `@datos` | escenarios que leen sus casos de `ticketpe/data/*.json` |
| `@framework` | `framework/utils.feature`, la verificación del propio framework |
| `@ignore` | los helpers en `helpers/` |
| `@RIESGO-*` | severidad más alta del ESC, a nivel Feature |
| `@REQ-HU-*` | historia de usuario, a nivel Scenario |

`@RIESGO-*` y `@REQ-*` alimentan la matriz de trazabilidad
(`scripts/resumen-corrida.sh`): [`TAE.md`](TAE.md#3-trazabilidad-riesgo--requisito--escenario).

## Hallazgos

Escenarios en rojo contra `prod` (2026-09-16). La aserción es la de la matriz:
no se ajusta para que pase.

| Caso | Esperado (matriz) | API real |
|---|---|---|
| CP05 | cotización con `moneda: PEN` | no devuelve moneda (el desglose sí cuadra al céntimo, incluido el borde half-up) |
| CP07 | 2.º cupón ⇒ `409 cupon_ya_aplicado`; se cobra el primero | `200`: el segundo reemplaza al primero |
| CP08 | entradas emitidas = unidades de la reserva | emite `cantidad + 1` |
| CP09 | tarjeta aprobada ⇒ N entradas | emite `N + 1` |
| CP13 | QR con ≥ 128 bits | `QR-` + 24 hex = 96 bits |
| CP17 | cedente reintenta ⇒ `409 ya_transferida` | `403 no_autorizado` |
| CP18 | con reembolso en trámite ⇒ `409` | `200`, transfiere igual |
| CP19 | evento ya iniciado ⇒ `409 evento_finalizado` | `200`, transfiere igual (consume una entrada sembrada de la cuenta demo) |
| CP22 | QR anterior a la transferencia ⇒ `409 entrada_transferida` | `200`, el QR viejo sigue entrando |
| CP23 | 2.º check-in indica el instante del primero | `409 ya_usada` sin timestamp |

Además, fuera de aserción: el `403` de `GET /entradas/{id}` a un tercero devuelve
en `mensaje` el nombre y correo del dueño (Ley 29733).

## Abrir en IntelliJ IDEA

1. `File > Open`, seleccionar el **`pom.xml`** de la raíz (no la carpeta) y elegir **Open as Project**. Así IntelliJ lo importa como proyecto Maven y resuelve las dependencias de Karate.
2. `File > Project Structure > Project`: cualquier SDK Java 21+ sirve (p. ej. Java 26); el `pom.xml` compila a `release 21`.
3. Plugins recomendados: **Cucumber for Java** y **Gherkin** (dan sintaxis, navegación y ejecución de escenarios sueltos desde el gutter).
4. `src/test/java` es a la vez fuente de tests y test resource (los `.feature`, los `.json` y los `.js` se copian al classpath vía la sección `<testResources>` del `pom.xml`).

## Data-driven

Los escenarios `@datos` no llevan los casos en el Gherkin: los leen de JSON.

```gherkin
Examples:
  | read('classpath:ticketpe/data/tarjetas.json') |
```

Agregar un caso = agregar un objeto al JSON, sin tocar el feature. Los JSON
llevan tipos reales (números, `null`) y admiten matchers de Karate como
`"#string"` cuando el valor esperado varía.

## Integración continua

`.github/workflows/e2e.yml`:

| Evento | Alcance |
|---|---|
| Pull request | `@smoke` |
| Push a `main` | suite completa |
| Cron 07:00 Lima | suite completa |
| `workflow_dispatch` | tags y `environment` a elección |

Antes de la suite corren dos gates fail-fast, cada uno con su propio nombre de
step para que el veredicto se lea sin abrir el log:

| Step | Qué verifica | Si falla |
|---|---|---|
| Verificar el framework (TAS) | `FrameworkTest`, sin red | la suite está rota, no el producto |
| Gate de salud del ambiente | `salud.feature` con `--tags @health` | el ambiente está caído, no es una regresión |

El paso de la suite corre igual los dos runners: los gates son fail-fast, no
reemplazan el alcance de la corrida.

Cada corrida sube el reporte HTML como artifact y escribe el Job Summary con
`scripts/resumen-corrida.sh`: veredicto, **los casos en rojo ordenados por
severidad, con su `feature:línea` y el primer fallo**, y la cobertura por
severidad, ESC, riesgo y requisito. El
build falla si falla un escenario.

Fuera de los PR, el reporte se despliega además a **GitHub Pages**, así que la
última corrida siempre queda en una URL fija (`https://<usuario>.github.io/<repo>/`).
Karate v2 ya genera el `index.html` que Pages necesita.

> Para que el deploy funcione: **Settings > Pages > Source = GitHub Actions**
> (una sola vez, en el repo de GitHub).

> El repo todavía no es un repositorio git: falta `git init` y el remote de
> GitHub para que el workflow corra.

## Documentación

| Documento | Qué responde |
|---|---|
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | cómo está armada la suite y por qué |
| [`STRATEGY.md`](STRATEGY.md) | qué se automatiza y con qué criterio |
| [`TAE.md`](TAE.md) | decisiones de ingeniería de automatización (gTAA, TAS vs SUT, trazabilidad, métricas) |
| [`AGENTS.md`](AGENTS.md) | reglas para agentes de codificación |

## Contrato descubierto (no está en el OpenAPI publicado)

| Endpoint | Body |
|---|---|
| `POST /auth/registro` | `{ nombre, correo, password }` -> 201 |
| `POST /auth/login` | `{ correo, password }` -> 200 |
| `POST /cotizaciones` | `{ evento_id, tipo, cantidad }` (`tipo` = nombre del tipo de entrada) -> 200 |
| `POST /reservas` | igual que cotizaciones -> 201, bloqueo de 15 min |
| `POST /reservas/{id}/cupon` | `{ codigo }` |
| `POST /reservas/{id}/pago` | `{ tarjeta_prueba }` -> 201 |
| `POST /entradas/{id}/reembolso` | `{ motivo }` -> 201 |
| `POST /entradas/{id}/transferir` | `{ correo_destino }` -> 200 |

Tarjetas: `4242424242424242` aprueba, `4000000000000002` rechaza (402), cualquier otra ⇒ `400 tarjeta_no_reconocida`.
