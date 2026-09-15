# ticketpe-qa-back-core

Pruebas E2E de backend para la API **TicketPe Núcleo**
(`https://testathon.testingperu.com/api/core`) con [Karate](https://karatelabs.github.io/karate/) 1.5.1 sobre Maven + JUnit 5.

> **Estado al 2026-09-14:** suite verificada contra `prod`: 45 de 46 escenarios
> en verde. El único rojo es un hallazgo real del API, no un test mal escrito
> (ver "Hallazgos").

## Requisitos

- Java 17+ (el `pom.xml` compila con `maven.compiler.release=17`; el SDK del IDE puede ser mayor, p. ej. Java 26)
- Maven 3.9+

## Ejecutar

```sh
mvn test -Denvironment=prod                                # toda la suite (5 hilos)
mvn test -Denvironment=stag                                # contra staging
mvn test -Denvironment=local                               # contra localhost:4100
mvn test -Denvironment=prod "-Dkarate.options=--tags @smoke"             # solo el smoke
mvn test -Denvironment=prod "-Dkarate.options=--tags @compra,@entradas"  # varios tags (OR)
mvn test -Denvironment=prod "-Dkarate.options=--tags ~@negocio"          # excluir un tag
mvn test -Denvironment=prod "-Dkarate.options=classpath:ticketpe/compra.feature"
```

## Ambientes

Las URL base están versionadas en `src/test/java/karate-config.js`:

| Ambiente | URL |
|---|---|
| `prod` | `https://testathon.testingperu.com/api/core` |
| `stag` | `https://testathon.stag.testingperu.com/api/core` |
| `local` | `http://localhost:4100/api/core` |

Se elige con `-Denvironment=<nombre>` (también sirve `-Dkarate.env=` o la
variable `KARATE_ENV`). **El flag es obligatorio**: sin ambiente, o con uno que
no existe, la corrida falla de inmediato con
`ambiente desconocido: x. Válidos: prod,stag,local`. No hay forma de pasar una
URL suelta por línea de comandos: toda URL contra la que se corre está
versionada en el repo y revisada en un PR.

Las tarjetas de prueba también van por ambiente (`testCards`). Hoy son las mismas
en los tres; están separadas para que un ambiente pueda cambiar su pasarela sin
tocar los features. Los escenarios las leen como `cards.approved` /
`cards.declined`, nunca por número literal.

Agregar un ambiente = una línea en `environments` y otra en `testCards` del
`karate-config.js`.

## Runners en IntelliJ IDEA

El repo versiona configuraciones compartidas en `.run/`; IntelliJ las carga solas
al abrir el proyecto y aparecen en el selector de Run:

| Runner | Qué corre |
|---|---|
| Suite completa (prod) | `mvn test -Denvironment=prod` |
| Smoke (prod) | `mvn test -Denvironment=prod -Dkarate.options=--tags @smoke` |
| Suite completa (stag) | `mvn test -Denvironment=stag` |
| Suite completa (local) | `mvn test -Denvironment=local` |

Para uno nuevo: duplicar un `.run/*.run.xml`, cambiar `name` y los `<option value="-D...">`.
Si lo creas desde la UI, marca **Store as project file** para que quede versionado.

Reporte HTML: `target/karate-reports/karate-summary.html`

Surefire propaga las `-D` del comando `mvn` al JVM de los tests, y
`karate-config.js` las lee con `karate.properties[...]`.

## Estructura

```
pom.xml
src/test/java/
  karate-config.js                    ambientes, credenciales y tarjetas de prueba
  ticketpe/
    TicketpeRunnerTest.java           runner JUnit 5 (Runner.path("classpath:ticketpe").parallel(5))
    salud.feature                     health check
    auth.feature                      registro, login, /auth/me
    eventos.feature                   catálogo, ficha, disponibilidad
    cotizaciones.feature              cálculo de subtotal, IGV y total
    compra.feature                    reserva -> cupón -> pago -> entradas
    entradas.feature                  mis entradas, detalle, transferencia, reembolso
    autorizacion.feature              401 sin token, 403 por rol
    data/
      cotizaciones-cantidad-invalida.json  casos de cantidad inválida
      tarjetas.json                        caso aprobada / rechazada y su resultado esperado
    helpers/
      usuario.feature                 registra un asistente nuevo y devuelve token
      evento-vendible.feature         elige evento futuro, pagado y con cupo
      disponibilidad.feature          consulta /eventos/{id}/disponibilidad
      entrada-comprada.feature        reserva + pago y devuelve la entrada emitida
```

Los helpers están marcados `@ignore` (no corren solos) y evitan datos quemados:
`usuario.feature` registra un asistente nuevo por corrida y
`evento-vendible.feature` elige en runtime un evento futuro, pagado y con cupo,
porque el inventario del ambiente cambia.

`karate-config.js` también fija `connectTimeout=10000` y `readTimeout=30000`.

## Tags disponibles

| Tag | Dónde |
|---|---|
| `@smoke` | `salud.feature` (a nivel Feature) más el escenario feliz de auth, catálogo, cotización, compra y entradas |
| `@auth` | `auth.feature` |
| `@catalogo` | `eventos.feature` |
| `@cotizacion` | `cotizaciones.feature` |
| `@compra` | `compra.feature` |
| `@entradas` | `entradas.feature` |
| `@autorizacion` | `autorizacion.feature` |
| `@datos` | escenarios data-driven que leen sus casos de `ticketpe/data/*.json` |
| `@negocio` | 1 escenario en `cotizaciones.feature` que documenta que cotizar no valida cupo |
| `@ignore` | los 4 helpers en `helpers/` |

No existe un tag propio para `salud.feature`: se selecciona con `@smoke`.

## Abrir en IntelliJ IDEA

1. `File > Open`, seleccionar el **`pom.xml`** de la raíz (no la carpeta) y elegir **Open as Project**. Así IntelliJ lo importa como proyecto Maven y resuelve las dependencias de Karate.
2. `File > Project Structure > Project`: cualquier SDK Java 17+ sirve (p. ej. Java 26); el `pom.xml` compila a `release 17`.
3. Plugins recomendados: **Cucumber for Java** y **Gherkin** (dan sintaxis, navegación y ejecución de escenarios sueltos desde el gutter).
4. `src/test/java` es a la vez fuente de tests y test resource (los `.feature` y `karate-config.js` se copian al classpath vía la sección `<testResources>` del `pom.xml`).

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

Cada corrida sube el reporte HTML como artifact y escribe un resumen por feature
en el Job Summary. El build falla si falla un escenario.

Fuera de los PR, el reporte se despliega además a **GitHub Pages**, así que la
última corrida siempre queda en una URL fija (`https://<usuario>.github.io/<repo>/`).
Karate genera `karate-summary.html`; el workflow lo copia a `index.html` porque
Pages necesita ese nombre.

> Para que el deploy funcione: **Settings > Pages > Source = GitHub Actions**
> (una sola vez, en el repo de GitHub).

> El repo todavía no es un repositorio git: falta `git init` y el remote de
> GitHub para que el workflow corra.

## Estrategia

Criterios de qué se automatiza, principios de diseño y convenciones:
[`STRATEGY.md`](STRATEGY.md).

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

Tarjetas: `4242424242424242` aprueba, `4000000000000002` rechaza (402).

## Hallazgos

| Hallazgo | Evidencia |
|---|---|
| `POST /reservas/{id}/pago` emite **`cantidad + 1`** entradas y cobra solo por `cantidad`. Reproducido en los eventos 4, 12, 17 y 18 con cantidades 1, 2 y 3. | `compra.feature` escenario "flujo feliz de compra" |

## Fuera de alcance por ahora

- `POST /soporte`: no se pudo deducir el contrato (siempre `entrada_invalida`).
- `POST /checkin` y `GET /reportes/ventas`: requieren un rol distinto de
  `asistente` y el registro público solo crea asistentes. Solo se cubren
  sus casos 401/403 en `autorizacion.feature`.
