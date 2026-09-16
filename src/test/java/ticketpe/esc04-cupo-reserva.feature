@ESC04 @sobreventa @RIESGO-ALTO
Feature: ESC04 - Cupo, concurrencia y expiración de la reserva

Background:
  * url baseUrl
  * def comprador = call read('helpers/usuario.feature')
  * def elegido = call read('helpers/evento-vendible.feature') { cantidad: 5 }
  * configure headers = auth.bearer(comprador.token)

@TC-API-06 @REQ-HU-E3.2 @api @p1 @alto @funcional
Scenario: CP11 - el tope de 4 por evento cuenta lo reservado vigente
  Given path 'reservas'
  And request { evento_id: '#(elegido.evento_id)', tipo: '#(elegido.tipo)', cantidad: 3 }
  When method post
  Then status 201

  Given path 'reservas'
  And request { evento_id: '#(elegido.evento_id)', tipo: '#(elegido.tipo)', cantidad: 1 }
  When method post
  Then status 201

  Given path 'reservas'
  And request { evento_id: '#(elegido.evento_id)', tipo: '#(elegido.tipo)', cantidad: 1 }
  When method post
  Then status 409
  And match response.error == 'limite_excedido'
