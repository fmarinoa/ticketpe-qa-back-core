# ticketpe-qa-back-core

Pruebas E2E de backend para la API **TicketPe Núcleo**
(`https://testathon.testingperu.com/api/core`) con [Karate](https://karatelabs.github.io/karate/) 1.5.1 sobre Maven + JUnit 5.

> **Estado al 2026-09-14:** la API de testathon respondía **503 (mantenimiento)**, así que la suite todavía **no se validó end-to-end** contra el ambiente real.

## Requisitos

- Java 17+ (el `pom.xml` compila con `maven.compiler.release=17`; el SDK del IDE puede ser mayor, p. ej. Java 26)
- Maven 3.9+

## Ejecutar

```sh
mvn test                                                          # toda la suite (5 hilos)
mvn test -Dkarate.options="--tags @smoke"                         # solo el smoke
mvn test -Dkarate.options="--tags @compra,@entradas"              # varios tags (OR)
mvn test -Dkarate.options="--tags ~@negocio"                      # excluir un tag
mvn test -Dkarate.options="classpath:ticketpe/compra.feature"     # un feature suelto
mvn test -DbaseUrl=http://localhost:4100/api/core                 # otro ambiente
```

Reporte HTML: `target/karate-reports/karate-summary.html`

`baseUrl` llega por `-DbaseUrl=...`: surefire lo pasa como system property y
`karate-config.js` lo lee. Sin el flag, el perfil `default-baseUrl` del `pom.xml`
apunta al ambiente de testathon.

## Estructura

```
pom.xml
src/test/java/
  karate-config.js                    baseUrl, password y tarjetas de prueba
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
      tarjetas.json                        tarjeta aprobada / rechazada y su resultado esperado
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
| `workflow_dispatch` | tags y `baseUrl` a elección |

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

## Fuera de alcance por ahora

- `POST /soporte`: no se pudo deducir el contrato (siempre `entrada_invalida`).
- `POST /checkin` y `GET /reportes/ventas`: requieren un rol distinto de
  `asistente` y el registro público solo crea asistentes. Solo se cubren
  sus casos 401/403 en `autorizacion.feature`.
