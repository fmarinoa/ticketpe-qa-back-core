@ESC08 @estado @RIESGO-CRITICO
Feature: ESC08 - Check-in con QR en estado inválido

Background:
  * url baseUrl
  * def org = callonce read('helpers/login.feature') { role: 'organizer' }
  * def dueno = call read('helpers/usuario.feature')
  * def compra = call read('helpers/entrada-comprada.feature') { token: '#(dueno.token)', cantidad: 1, soloEvento: '#(ticketpe.roles.organizer.evento_id)' }

@TC-API-22 @REQ-HU-E5.1 @api @p1 @critico @autorizacion
Scenario: CP22 - check-in con el QR anterior de una entrada transferida
  * def destino = call read('helpers/usuario.feature')
  * configure headers = auth.bearer(dueno.token)
  Given path 'entradas', compra.entrada.id, 'transferir'
  And request { correo_destino: '#(destino.correo)' }
  When method post
  Then status 200

  * configure headers = auth.bearer(destino.token)
  Given path 'entradas', compra.entrada.id
  When method get
  Then status 200
  * def qrNuevo = response.entrada.codigo_qr

  * configure headers = auth.bearer(org.token)
  Given path 'checkin'
  And request { codigo_qr: '#(compra.entrada.codigo_qr)' }
  When method post
  Then status 409
  And match response.error == 'entrada_transferida'

  Given path 'checkin'
  And request { codigo_qr: '#(qrNuevo)' }
  When method post
  Then status 200

  * configure headers = auth.bearer(destino.token)
  Given path 'entradas', compra.entrada.id
  When method get
  Then status 200
  And match response.entrada.estado == 'usada'

@TC-API-23 @REQ-HU-E5.1 @api @p1 @alto @regresion
Scenario: CP23 - doble check-in con el mismo QR
  * configure headers = auth.bearer(org.token)
  Given path 'checkin'
  And request { codigo_qr: '#(compra.entrada.codigo_qr)' }
  When method post
  Then status 200

  Given path 'checkin'
  And request { codigo_qr: '#(compra.entrada.codigo_qr)' }
  When method post
  Then status 409
  And match response.error == 'ya_usada'
  # el instante del primer ingreso, en cualquier campo
  * string cuerpo = response
  And match cuerpo == '#regex .*\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}.*'

  * configure headers = auth.bearer(dueno.token)
  Given path 'entradas', compra.entrada.id
  When method get
  Then status 200
  And match response.entrada.estado == 'usada'
