@framework @smoke
Feature: verificación del propio framework (TAS), sin tocar el SUT

  Estos escenarios no hacen HTTP: prueban las funciones de karate-base.js y
  karate-config.js. Si `minutesBetween` se rompe, compra.feature falla y la
  culpa parece del API. Corren en su propio runner (FrameworkTest) y su propio
  outputDir, para no mezclarse con el reporte de la suite contra el SUT.

Scenario: utils.round redondea a los decimales pedidos
  * match utils.round(10.2949, 2) == 10.29
  * match utils.round(14.7, 0) == 15
  * match utils.round(10.005) == 10.01

Scenario: utils.minutesBetween mide minutos entre dos instantes ISO
  * match utils.minutesBetween('2026-09-15T10:00:00Z', '2026-09-15T10:15:00Z') == 15
  * match utils.minutesBetween('2026-09-15T10:00:00Z', '2026-09-15T09:30:00Z') == -30

Scenario: utils.now devuelve el instante actual en ISO comparable con minutesBetween
  * match utils.now() == '#regex ^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}Z$'
  * assert utils.minutesBetween(utils.now(), '2099-01-01T00:00:00.000Z') > 0

Scenario: utils.randomPassword acuña una credencial distinta en cada llamada
  * def a = utils.randomPassword()
  * def b = utils.randomPassword()
  * match a != b
  * match a == '#regex ^[a-f0-9]{13}$'

Scenario: utils.loadConfig resuelve el ambiente en curso
  * match utils.loadConfig('baseUrl') == baseUrl
  * match utils.loadConfig('cards') == ticketpe.cards

Scenario: auth.bearer arma el header de autorización y propaga el traceId
  * match auth.bearer('abc123') == { Authorization: 'Bearer abc123', 'X-Request-Id': '#(traceId)' }
  * match traceId == '#regex ^testitans-[a-f0-9-]{36}$'

Scenario: ticketpe.newEmail no repite correo entre llamadas
  * match ticketpe.newEmail() != ticketpe.newEmail()
  * match ticketpe.newEmail() == '#regex ^qa\\.karate\\..+@testingperu\\.com$'
