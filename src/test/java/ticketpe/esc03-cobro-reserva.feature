@ESC03 @dinero @RIESGO-CRITICO
Feature: ESC03 - Cobro de la reserva

Background:
  * url baseUrl
  * def comprador = call read('helpers/usuario.feature')
  * def elegido = callonce read('helpers/evento-vendible.feature') { cantidad: 2 }
  * configure headers = auth.bearer(comprador.token)

@TC-API-03 @REQ-HU-E3.3 @api @p1 @critico @funcional
Scenario: CP08 - pagar dos veces la misma reserva no genera dos cobros
  Given path 'reservas'
  And request { evento_id: '#(elegido.evento_id)', tipo: '#(elegido.tipo)', cantidad: 2 }
  When method post
  Then status 201
  * def reserva = response.reserva

  * def paralelo = call read('helpers/pago-paralelo.feature') { reserva_id: '#(reserva.id)', token: '#(comprador.token)', clave: '#(java.util.UUID.randomUUID() + "")' }
  * def pagos = paralelo.respuestas
  * match pagos[0].body.pago.id == '#uuid'
  * match pagos[1].body.pago.id == pagos[0].body.pago.id

  Given path 'reservas', reserva.id, 'pago'
  And request { tarjeta_prueba: '#(ticketpe.cards.approved)' }
  When method post
  Then status 409
  And match response.error == 'ya_confirmada'

  Given path 'mis-entradas'
  When method get
  Then status 200
  * def emitidas = karate.jsonPath(response, "$.entradas[?(@.reserva_id=='" + reserva.id + "')]")
  And match emitidas == '#[2]'

@TC-API-04 @REQ-HU-E3.3 @api @p1 @alto @funcional @datos
Scenario Outline: CP09 - la tarjeta <caso> determina el resultado sin alterar la reserva
  Given path 'reservas'
  And request { evento_id: '#(elegido.evento_id)', tipo: '#(elegido.tipo)', cantidad: 2 }
  When method post
  Then status 201
  * def reserva = response.reserva

  Given path 'reservas', reserva.id, 'pago'
  And request { tarjeta_prueba: '#(ticketpe.cards[card])' }
  When method post
  Then status <status>
  And match karate.get('response.error') == error
  And match karate.sizeOf(karate.get('response.entradas', [])) == entradas

  Given path 'reservas', reserva.id
  When method get
  Then status 200
  And match response.reserva.estado == estadoReserva
  And match response.reserva.expira_en == reserva.expira_en

  Examples:
    | read('classpath:ticketpe/data/tarjetas.json') |
