@RIESGO-ALTO
Feature: ESC04 - Ciclo de vida de la entrada

Background:
  * url baseUrl
  * def duenoA = call read('helpers/usuario.feature')
  * def compra = call read('helpers/entrada-comprada.feature') { token: '#(duenoA.token)', cantidad: 1 }
  * def entrada = compra.entrada
  * def estaEntrada = "$.entradas[?(@.id=='" + entrada.id + "')]"

@TC-API-14 @ESC04 @api @p2 @alto @RSK-09 @REQ-HU-E4.2 @REQ-HU-E4.1
Scenario: CP14 - transferir una entrada propia la mueve una sola vez
  * def destinoB = call read('helpers/usuario.feature')
  * def terceroC = call read('helpers/usuario.feature')

  * configure headers = auth.bearer(duenoA.token)
  Given path 'entradas', entrada.id, 'transferir'
  And request { correo_destino: '#(destinoB.correo)' }
  When method post
  Then status 200

  Given path 'mis-entradas'
  When method get
  Then status 200
  And match karate.jsonPath(response, estaEntrada) == []

  Given path 'entradas', entrada.id
  When method get
  Then status 403

  * configure headers = auth.bearer(destinoB.token)
  Given path 'mis-entradas'
  When method get
  Then status 200
  And match karate.jsonPath(response, estaEntrada) == '#[1]'

  Given path 'entradas', entrada.id, 'transferir'
  And request { correo_destino: '#(terceroC.correo)' }
  When method post
  Then status 409
  And match response.error == 'ya_transferida'

  * configure headers = auth.bearer(terceroC.token)
  Given path 'mis-entradas'
  When method get
  Then status 200
  And match karate.jsonPath(response, estaEntrada) == []

@TC-API-15 @ESC04 @api @p2 @alto @RSK-09 @REQ-HU-E4.2
Scenario: CP15 - no se transfiere a sí mismo, a un organizador ni a un correo sin cuenta
  * configure headers = auth.bearer(duenoA.token)
  Given path 'entradas', entrada.id, 'transferir'
  And request { correo_destino: '#(duenoA.correo)' }
  When method post
  Then status 400

  Given path 'entradas', entrada.id, 'transferir'
  And request { correo_destino: '#(ticketpe.roles.organizer.email)' }
  When method post
  Then status 404

  Given path 'entradas', entrada.id, 'transferir'
  And request { correo_destino: '#(ticketpe.newEmail())' }
  When method post
  Then status 404

  Given path 'mis-entradas'
  When method get
  Then status 200
  And match karate.jsonPath(response, estaEntrada) == '#[1]'
  And match karate.jsonPath(response, estaEntrada)[0].transferida == false

@TC-API-16 @ESC04 @api @p2 @alto @RSK-10 @REQ-HU-E4.3
Scenario: CP16 - un segundo reembolso con el primero en trámite se rechaza
  * configure headers = auth.bearer(duenoA.token)
  Given path 'entradas', entrada.id, 'reembolso'
  And request { motivo: 'No podré asistir' }
  When method post
  Then status 201
  And match response.reembolso contains { id: '#uuid', entrada_id: '#(entrada.id)', estado: 'solicitado' }

  Given path 'entradas', entrada.id, 'reembolso'
  And request { motivo: 'No podré asistir' }
  When method post
  Then status 409
  And match response.error == 'ya_en_tramite'

@TC-API-17 @ESC04 @api @p2 @alto @RSK-11 @REQ-HU-E5.1
Scenario: CP17 - una entrada registra ingreso una sola vez
  # check-in con el administrador para no depender de eventos propios
  * def admin = call read('helpers/login.feature') { role: 'admin' }
  * configure headers = auth.bearer(admin.token)
  Given path 'checkin'
  And request { codigo_qr: '#(entrada.codigo_qr)' }
  When method post
  Then status 200

  * configure headers = auth.bearer(duenoA.token)
  Given path 'entradas', entrada.id
  When method get
  Then status 200
  And match response.entrada.estado == 'usada'

  * configure headers = auth.bearer(admin.token)
  Given path 'checkin'
  And request { codigo_qr: '#(entrada.codigo_qr)' }
  When method post
  Then status 409
