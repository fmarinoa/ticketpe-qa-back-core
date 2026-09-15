# Estrategia de automatización — TicketPe Núcleo

## 1. Qué se automatiza y por qué

No se automatiza todo el API: se automatizan los flujos donde una falla cuesta
plata o confianza. Criterio = impacto en el negocio x probabilidad de regresión.

| Flujo | Impacto si falla | Cobertura | Feature |
|---|---|---|---|
| Reserva -> pago -> emisión de entradas | Crítico: se cobra y no se emite, o se emite sin cobrar | E2E + negativos | `compra.feature` |
| Cálculo de precios (subtotal, IGV, total) | Crítico: cobro incorrecto | Cálculo verificado contra el precio del catálogo | `cotizaciones.feature` |
| Control de cupo (`sin_cupo`) | Alto: sobreventa | Negativo | `compra.feature` |
| Autenticación y propiedad del dato | Alto: ver o mover entradas ajenas | 401 / 403 | `auth.feature`, `autorizacion.feature`, `entradas.feature` |
| Transferencia y reembolso | Medio: soporte manual | Happy path + reglas (una sola transferencia) | `entradas.feature` |
| Catálogo y disponibilidad | Medio: lectura, degradación visible | Contrato + coherencia de cupos | `eventos.feature` |
| Salud del servicio | Bajo, pero es el canario del pipeline | Smoke | `salud.feature` |

Fuera de alcance consciente: `POST /soporte` (contrato no deducible) y los happy
paths de `checkin` y `reportes/ventas` (requieren un rol que el registro público
no entrega). De esos dos solo se cubren 401/403.

## 2. Principios de diseño de la suite

1. **Cero datos quemados.** Cada corrida registra su propio asistente
   (`helpers/usuario.feature`) y elige en runtime un evento futuro, pagado y con
   cupo (`helpers/evento-vendible.feature`). El inventario del ambiente cambia:
   un `evento_id` fijo convierte la suite en falso rojo.
2. **Helpers, no copy-paste.** Los pasos que se repiten (registrar usuario,
   comprar una entrada) viven en `helpers/` con `@ignore` y se invocan con
   `call` / `callonce`. Un cambio de contrato se arregla en un solo archivo.
3. **Independencia entre escenarios.** Ninguno depende del orden ni del estado
   que dejó otro; por eso la suite corre en paralelo (5 hilos) sin flakiness.
4. **Aserciones de contrato, no solo de status.** Se valida forma y tipos
   (`'#uuid'`, `'#number'`, `'#regex'`), no únicamente el 200.
5. **Data-driven donde la lógica es la misma y solo cambia el dato.** Las
   variantes viven en JSON (`ticketpe/data/`), no en Gherkin duplicado.
6. **El bug se documenta, no se esconde.** Comportamientos discutibles del API
   se cubren con un escenario etiquetado `@negocio` que fija el comportamiento
   actual (ejemplo: cotizar 99 999 entradas responde 200 sin validar cupo).

## 3. Convenciones

- Nombres de escenario en español, describiendo la regla de negocio, no el
  endpoint: "no se puede reservar más entradas de las disponibles".
- Un tag por dominio (`@auth`, `@compra`, ...) + `@smoke` en el happy path de
  cada dominio + `@datos` en los data-driven + `@negocio` en los que documentan
  comportamiento cuestionable.
- Helpers siempre `@ignore` para que no corran sueltos.
- Nada de `sleep`. Si el API fuera eventualmente consistente, se usa
  `retry until` de Karate.

## 4. Pipeline

`.github/workflows/e2e.yml`:

| Evento | Alcance | Razón |
|---|---|---|
| Pull request | `@smoke` | feedback en menos de 1 min |
| Push a `main` | suite completa | guardián de la rama |
| Cron diario 07:00 Lima | suite completa | detecta degradación del ambiente, no solo del código |
| `workflow_dispatch` | tags y `baseUrl` a elección | corridas ad hoc en el testathon |

Cada corrida publica el reporte HTML de Karate como artifact, un resumen por
feature en el Job Summary y, fuera de los PR, despliega ese mismo reporte a
GitHub Pages (URL fija con la última corrida). El build falla si falla un
escenario: el runner JUnit asserta `results.getFailCount() == 0`.

## 5. Siguientes pasos (no implementados a propósito)

- `karate-gatling` para un smoke de performance sobre `/eventos` y `/reservas`
  reutilizando estos mismos features.
- Mock del API con `karate-netty` si el ambiente se cae (hoy responde 503) y se
  necesita validar la suite igual.
