# Estrategia de automatización — TicketPe Núcleo

## 1. Qué se automatiza y por qué

No se automatiza todo el API: se automatizan los flujos donde una falla cuesta
plata o confianza. Criterio = impacto en el negocio x probabilidad de regresión.

La fuente de casos es la matriz de diseño `testathon2026/diseno-pruebas/API.tsv`
(R3): cada ESC es un feature y cada CP automatizable un escenario.

| ESC | Riesgo | Casos | Feature |
|---|---|---|---|
| ESC01 Control de acceso | Crítico: autorización | CP01-CP03 | `esc01-control-acceso.feature` |
| ESC02 Precio y cupones | Alto: dinero | CP05-CP07 | `esc02-precio-cupones.feature` |
| ESC03 Cobro | Crítico: cobro duplicado | CP08-CP09 | `esc03-cobro-reserva.feature` |
| ESC04 Cupo | Alto: sobreventa | CP11 | `esc04-cupo-reserva.feature` |
| ESC05 Fuga de datos | Crítico: regulatorio | CP13-CP14 | `esc05-fuga-datos.feature` |
| ESC06 Transferencia | Crítico: doble cesión | CP16-CP19 | `esc06-transferencia-estado-invalido.feature` |
| ESC07 Reembolso | Alto: doble devolución | CP20-CP21 | `esc07-reembolso.feature` |
| ESC08 Check-in | Crítico: acceso duplicado | CP22-CP23 | `esc08-checkin.feature` |
| Salud del servicio | Bajo, canario del pipeline | — | `salud.feature` |

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
6. **El bug se documenta, no se esconde.** El escenario asserta lo que dice la
   matriz y queda en rojo; el desvío va a la tabla de Hallazgos del README.

## 3. Convenciones

- Nombres de escenario en español, describiendo la regla de negocio, no el
  endpoint: "no se puede reservar más entradas de las disponibles".
- Un feature por ESC (`@ESCNN`), un escenario por CP (`@TC-API-NN`) con los tags
  de la matriz + `@datos` en los data-driven.
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
| `workflow_dispatch` | tags, ambiente y `baseUrl` a elección | corridas ad hoc en el testathon |

Cada corrida publica el reporte HTML de Karate como artifact, un resumen por
feature en el Job Summary y, fuera de los PR, despliega ese mismo reporte a
GitHub Pages (URL fija con la última corrida). El build falla si falla un
escenario: el runner JUnit asserta `results.getFailCount() == 0`.

## 5. Siguientes pasos (no implementados a propósito)

- `karate-gatling` para un smoke de performance sobre `/eventos` y `/reservas`
  reutilizando estos mismos features.
- Mock del API con `karate-netty` si el ambiente se cae (hoy responde 503) y se
  necesita validar la suite igual.
