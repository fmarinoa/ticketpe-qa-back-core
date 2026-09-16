@ESC07 @estado @RIESGO-ALTO
Feature: ESC07 - Reembolso fuera de estado o ventana válida

Background:
  * url baseUrl

@TC-API-20 @REQ-HU-E4.3 @api @p1 @alto @dinero
Scenario: CP20 - segundo reembolso con el primero pendiente
  * def dueno = call read('helpers/usuario.feature')
  * def compra = call read('helpers/entrada-comprada.feature') { token: '#(dueno.token)', cantidad: 1 }
  * configure headers = auth.bearer(dueno.token)
  Given path 'entradas', compra.entrada.id, 'reembolso'
  And request { motivo: 'No podré asistir al evento' }
  When method post
  Then status 201

  Given path 'entradas', compra.entrada.id, 'reembolso'
  And request { motivo: 'No podré asistir al evento' }
  When method post
  Then status 409
  And match response.error == 'ya_en_tramite'

@TC-API-21 @REQ-HU-E4.3 @api @p1 @medio @regulatorio
Scenario: CP21 - reembolso antes y después del inicio del evento
  # el corte exacto (inicio -1 min / +1 min) no es controlable sin mover el reloj del API:
  # se prueba un evento futuro y uno ya iniciado
  * def dueno = call read('helpers/usuario.feature')
  * def futura = call read('helpers/entrada-comprada.feature') { token: '#(dueno.token)', cantidad: 1 }
  * configure headers = auth.bearer(dueno.token)
  Given path 'entradas', futura.entrada.id, 'reembolso'
  And request { motivo: 'No podré asistir al evento' }
  When method post
  Then status 201
  And match response.reembolso.estado == 'solicitado'

  * def iniciada = call read('helpers/entrada-evento-iniciado.feature') { indice: 1 }
  * configure headers = auth.bearer(iniciada.token)
  Given path 'entradas', iniciada.entrada.id, 'reembolso'
  And request { motivo: 'No podré asistir al evento' }
  When method post
  Then status 409
  And match response.error == 'evento_ya_realizado'
