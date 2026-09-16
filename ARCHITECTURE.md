# ARCHITECTURE

Decisiones estructurales de la suite y las restricciones de Karate 1.5.1 que las
fuerzan. Solo lo que no se deduce leyendo el código.

Uso y comandos: [`README.md`](README.md) · qué se automatiza y por qué:
[`STRATEGY.md`](STRATEGY.md) · decisiones de ingeniería de automatización (gTAA,
TAS vs SUT, trazabilidad): [`TAE.md`](TAE.md) · reglas para agentes:
[`AGENTS.md`](AGENTS.md).

## Capas

Karate evalúa tres archivos por escenario, en este orden fijo. Lo que cada uno
retorna queda como variable global en el feature.

```
karate-base.js        genérico, sin dominio     utils.*, auth.*, traceId
      │
      ▼
karate-config.js      proyecto TicketPe          env, baseUrl, ticketpe.*
      │                  usa utils.loadConfig()
      ▼
*.feature             el test                    consume ambas capas
```

| Capa | Qué puede saber | Qué expone hoy |
|---|---|---|
| `karate-base.js` | nada de TicketPe; reusable en otro repo | `utils.loadConfig(nombre)`, `utils.round(n, decimales)`, `utils.minutesBetween(desde, hasta)`, `utils.randomPassword()`, `auth.bearer(token)`, `traceId` |
| `karate-config.js` | ambientes, credenciales, tarjetas, dominio del correo | `env`, `baseUrl`, `ticketpe.cards`, `ticketpe.password`, `ticketpe.newEmail()` |
| `helpers/*.feature` | todo, incluido HTTP | fixtures `@ignore` vía `call` / `callonce` |

El corte es por **dependencia, no por tamaño**: lo que hace HTTP no puede vivir
en JS (necesitaría `karate.call` anidado y un Runner), y lo que no conoce
TicketPe no debe bajar a `karate-config.js`.

**Un namespace por capa, y el prefijo dice de dónde sale la función.**
`utils.*` y `auth.*` los define `karate-base.js`; `ticketpe.*`,
`karate-config.js`. Mezclarlas en un solo `utils` ahorra un prefijo y cuesta la
procedencia: se lee `utils.newEmail()`, se abre `karate-base.js` y no está.

Por eso `cards`, `password` y `newEmail()` son `ticketpe.*`: son datos del
dominio y no pueden quemarse en la capa genérica. `env` y `baseUrl` quedan
sueltos porque son convención de Karate (`Given url baseUrl`).

El reparto se ve claro en la password: **generarla** es genérico
(`utils.randomPassword()`), **tenerla** es del proyecto
(`ticketpe.password`).
Nombres de función en inglés en las dos capas; el español queda para los
nombres de escenario.

## Configuración versionada

`config/baseUrl.json` y `config/cards.json` mapean ambiente → valor. Agregar un
ambiente es una clave en cada uno.

No existe forma de pasar una URL suelta por CLI: **toda URL contra la que se
corre está en el repo y pasó por un PR**. Un ambiente sin `baseUrl` corta la
corrida con `ambiente desconocido: <env>` antes del primer request, en vez de
fallar 46 escenarios con `UnknownHostException`.

Las tarjetas hoy son iguales en los tres ambientes; están separadas para que uno
cambie de pasarela sin tocar un feature. Los escenarios leen
`ticketpe.cards.approved` / `ticketpe.cards.declined`, nunca un número literal.

## Classpath

`src/test/java` es a la vez fuente y test resource: el `<testResources>` del
`pom.xml` copia todo salvo `**/*Test.java`. Por eso `.feature`, `.json` y `.js`
se resuelven como `classpath:...` y un feature nuevo bajo `ticketpe/` entra a la
suite **solo por existir**.

> Si algún día se agregan clases Java de soporte, el `<exclude>` debe pasar a
> `**/*.java` o se copiarán como recursos duplicados.

## Paralelismo

`Runner.path("classpath:ticketpe").parallel(5)`. Ningún escenario puede depender
del orden ni del estado que dejó otro: cada uno arma sus datos en el `Background`
con `call` / `callonce` a `helpers/`.

De ahí salen dos reglas que parecen cosméticas y no lo son:

- **`ticketpe.newEmail()` usa UUID.** Dos hilos registrando el mismo correo dan 409.
- **Todo helper lleva `@ignore`.** El runner levanta la carpeta entera; sin el
  tag el helper corre suelto, sin sus parámetros, y falla.

## Credenciales

No hay ninguna versionada. `utils.randomPassword()` acuña una al vuelo desde un
UUID v4 (sembrado con `SecureRandom`).

Dos razones, y la segunda es la que importa:

1. El repo no guarda una clave reutilizable.
2. **El reporte HTML se publica en GitHub Pages y loguea los request bodies.**
   Enmascararlos exigiría una clase Java (ver abajo). Lo que queda publicado es
   la credencial de un usuario desechable que ya no sirve para nada.

**La password pertenece al usuario, no al escenario.**
`helpers/usuario.feature` acuña la suya y la devuelve junto a `correo`, `token`
y `usuario`; quien necesite loguear a ese usuario usa `alta.password`.

Ese detalle es lo que hace seguro el `callonce`: el usuario cacheado viaja con
su propia credencial, así que sirve en cualquier escenario del feature aunque
`karate-config.js` se evalúe de nuevo en cada uno.

`ticketpe.password` hoy no lo usa ningún feature del SUT; queda para registros
inline que no pasen por el helper.

## Correlación con el SUT

`karate-base.js` acuña un `traceId` por escenario (el archivo se evalúa una vez
por escenario) y viaja como `X-Request-Id` en cada request. Dos vías, porque una
sola no alcanza:

- `karate.configure('headers', { 'X-Request-Id': traceId })` en
  `karate-config.js` cubre los requests anónimos.
- `auth.bearer(token)` lo devuelve junto al `Authorization`, porque
  `configure headers = auth.bearer(...)` **reemplaza** el default, no lo
  extiende: sin esto, todo escenario autenticado perdería el id.

Los escenarios que hacen `configure headers = null` o los sobreescriben desde un
`Examples:` quedan sin id a propósito: prueban justamente el request sin
cabeceras o con una inválida.

## Verificación del propio framework

`framework/utils.feature` prueba `utils.*`, `auth.*` y `ticketpe.*` sin hacer
HTTP, con su propio runner (`framework/FrameworkTest.java`) y su propio
`reportDir` — si compartiera `target/karate-reports`, el segundo runner pisaría
el `karate-summary-json.txt` que el workflow lee para el Job Summary.

Lleva `@smoke` además de `@framework` para que corra en los PR: el filtro de
tags de `-Dkarate.options` es global a la JVM y se aplica también a este runner.
El razonamiento completo, en [`TAE.md`](TAE.md#1-tas-y-sut-dos-cosas-que-se-prueban-por-separado).

## Restricciones de Karate que muerden

| Restricción | Consecuencia |
|---|---|
| `karate.configure` valida la clave contra una lista cerrada | Una clave inventada (`logging`) tira `RuntimeException` en **cada** escenario, no un warning. En uso: `connectTimeout`, `readTimeout`, `retry`, `headers`, `logPrettyRequest`, `logPrettyResponse` |
| `configure logModifier` hace `checkcast` a `HttpLogModifier` | Enmascarar secretos en el log exige una clase Java; un objeto JS revienta con `ClassCastException`. Por eso el reporte publicado en Pages no enmascara: los tokens son de usuarios desechables por corrida |
| Un test JUnit levanta una carpeta entera | Para elegir escenarios el filtro es `-Dkarate.options`, no `-Dtest=`. `-Dtest=` solo elige runner (`RunnerTest` = SUT, `FrameworkTest` = TAS) |
| `-Dkarate.options` es una propiedad de JVM, no del runner | El filtro de tags se aplica a **todos** los runners de la corrida. Por eso `framework/utils.feature` lleva `@smoke`: sin él, un PR no verificaría el TAS |
| `karate.properties[...]` lee propiedades de JVM, no env vars | El `CI=true` que GitHub Actions ya expone no llega solo: el workflow pasa `-Dci=true` explícito |

## Datos: cero valores quemados

`helpers/usuario.feature` registra un asistente nuevo por corrida.
`helpers/evento-vendible.feature` elige en runtime un evento futuro, pagado y con
cupo, consultando catálogo y disponibilidad.

El inventario del ambiente cambia entre corridas: un `evento_id` fijo no es un
atajo, es una suite en falso rojo la semana siguiente.

## Dónde va una función nueva

1. ¿Karate ya lo resuelve? (`contains deep`, `#?`, `#regex`, `retry until`) → no
   se escribe nada.
2. ¿Lógica pura y reusable, sin dominio? → `karate-base.js`, como `utils.*` /
   `auth.*`.
3. ¿Lógica pura pero conoce TicketPe? → `karate-config.js`, como `ticketpe.*`.
4. ¿Hace HTTP? → `helpers/*.feature` con `@ignore`.
5. ¿Assert de un solo escenario, sin reuso? → inline en el feature, y está bien.
