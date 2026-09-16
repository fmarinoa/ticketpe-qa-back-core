@ESC06 @estado @RIESGO-CRITICO
Feature: ESC06 - Transferencia sobre entrada en estado inválido

Background:
  * url baseUrl
  * def dueno = call read('helpers/usuario.feature')
  * def destino = call read('helpers/usuario.feature')
  * def org = callonce read('helpers/login.feature') { role: 'organizer' }
  * def eventoPropio = ticketpe.roles.organizer.evento_id

@TC-API-16 @REQ-HU-E4.2 @api @p1 @alto @autorizacion
Scenario: CP16 - transferir una entrada ya usada
  * def compra = call read('helpers/entrada-comprada.feature') { token: '#(dueno.token)', cantidad: 1, soloEvento: '#(eventoPropio)' }
  * configure headers = auth.bearer(org.token)
  Given path 'checkin'
  And request { codigo_qr: '#(compra.entrada.codigo_qr)' }
  When method post
  Then status 200

  * configure headers = auth.bearer(dueno.token)
  Given path 'entradas', compra.entrada.id, 'transferir'
  And request { correo_destino: '#(destino.correo)' }
  When method post
  Then status 409
  And match response.error == 'estado_invalido'

  Given path 'entradas', compra.entrada.id
  When method get
  Then status 200
  And match response.entrada contains { estado: 'usada', usuario_id: '#(dueno.usuario.id)' }

@TC-API-17 @REQ-HU-E4.2 @api @p1 @critico @regresion
Scenario: CP17 - transferir una entrada ya transferida
  * def compra = call read('helpers/entrada-comprada.feature') { token: '#(dueno.token)', cantidad: 1 }
  * def tercero = call read('helpers/usuario.feature')
  * configure headers = auth.bearer(dueno.token)
  Given path 'entradas', compra.entrada.id, 'transferir'
  And request { correo_destino: '#(destino.correo)' }
  When method post
  Then status 200

  * configure headers = auth.bearer(destino.token)
  Given path 'entradas', compra.entrada.id, 'transferir'
  And request { correo_destino: '#(tercero.correo)' }
  When method post
  Then status 409
  And match response.error == 'ya_transferida'

  * configure headers = auth.bearer(dueno.token)
  Given path 'entradas', compra.entrada.id, 'transferir'
  And request { correo_destino: '#(tercero.correo)' }
  When method post
  Then status 409
  And match response.error == 'ya_transferida'

  * configure headers = auth.bearer(destino.token)
  Given path 'entradas', compra.entrada.id
  When method get
  Then status 200
  And match response.entrada.usuario_id == destino.usuario.id

@TC-API-18 @REQ-HU-E4.2 @api @p1 @alto @dinero
Scenario: CP18 - transferir con reembolso en trámite
  * def compra = call read('helpers/entrada-comprada.feature') { token: '#(dueno.token)', cantidad: 1 }
  * configure headers = auth.bearer(dueno.token)
  Given path 'entradas', compra.entrada.id, 'reembolso'
  And request { motivo: 'No podré asistir al evento' }
  When method post
  Then status 201

  Given path 'entradas', compra.entrada.id, 'transferir'
  And request { correo_destino: '#(destino.correo)' }
  When method post
  Then status 409
  And match response.error == 'ya_en_tramite'

  Given path 'entradas', compra.entrada.id
  When method get
  Then status 200
  And match response.entrada contains { estado: '#(compra.entrada.estado)', usuario_id: '#(dueno.usuario.id)' }

@TC-API-19 @REQ-HU-E4.2 @api @p1 @medio @dinero
Scenario: CP19 - transferir una entrada de un evento ya iniciado
  * def iniciada = call read('helpers/entrada-evento-iniciado.feature') { indice: 0 }
  * configure headers = auth.bearer(iniciada.token)
  Given path 'entradas', iniciada.entrada.id, 'transferir'
  And request { correo_destino: '#(destino.correo)' }
  When method post
  Then status 409
  And match response.error == 'evento_finalizado'

  Given path 'entradas', iniciada.entrada.id
  When method get
  Then status 200
  And match response.entrada contains { estado: '#(iniciada.entrada.estado)', usuario_id: '#(iniciada.entrada.usuario_id)' }
