@compra
Feature: Reserva, cupón y pago

Background:
  * url baseUrl
  * def alta = call read('helpers/usuario.feature')
  * def autorizado = auth.bearer(alta.token)
  * def elegido = callonce read('helpers/evento-vendible.feature') { cantidad: 2 }
  * configure headers = autorizado

@smoke
Scenario: flujo feliz de compra: reserva, pago y emisión de entradas
  Given path 'cotizaciones'
  And request { evento_id: '#(elegido.evento_id)', tipo: '#(elegido.tipo)', cantidad: 2 }
  When method post
  Then status 200
  * def cotizacion = response

  Given path 'reservas'
  And request { evento_id: '#(elegido.evento_id)', tipo: '#(elegido.tipo)', cantidad: 2 }
  When method post
  Then status 201
  And match response.reserva contains { id: '#uuid', usuario_id: '#(alta.usuario.id)', evento_id: '#(elegido.evento_id)', cantidad: 2, estado: 'pendiente', cupon_codigo: null }
  * def reserva = response.reserva
  * def minutosBloqueo = utils.minutesBetween(reserva.creado_en, reserva.expira_en)
  And match utils.round(minutosBloqueo, 0) == 15

  Given path 'reservas', reserva.id
  When method get
  Then status 200
  And match response.reserva.id == reserva.id

  Given path 'reservas', reserva.id, 'pago'
  And request { tarjeta_prueba: '#(ticketpe.cards.approved)' }
  When method post
  Then status 201
  And match response.pago contains { reserva_id: '#(reserva.id)', estado: 'aprobado', monto: '#(cotizacion.total)' }
  And match response.entradas == '#[2]'
  And match each response.entradas contains { id: '#uuid', usuario_id: '#(alta.usuario.id)', evento_id: '#(elegido.evento_id)', codigo_qr: '#regex ^QR-[A-F0-9]{24}$', estado: 'emitida', transferida: false }

@datos
Scenario Outline: el pago con tarjeta <caso> responde <status> y deja la reserva en <estadoReserva>
  Given path 'reservas'
  And request { evento_id: '#(elegido.evento_id)', tipo: '#(elegido.tipo)', cantidad: 1 }
  When method post
  Then status 201
  * def reservaId = response.reserva.id

  Given path 'reservas', reservaId, 'pago'
  And request { tarjeta_prueba: '#(ticketpe.cards[card])' }
  When method post
  Then status <status>
  And match karate.get('response.pago.estado') == estadoPago
  And match karate.get('response.error') == errorEsperado

  Given path 'reservas', reservaId
  When method get
  Then status 200
  And match response.reserva.estado == estadoReserva

  Examples:
    | read('classpath:ticketpe/data/tarjetas.json') |

Scenario: una reserva ya pagada no se puede volver a pagar
  Given path 'reservas'
  And request { evento_id: '#(elegido.evento_id)', tipo: '#(elegido.tipo)', cantidad: 1 }
  When method post
  Then status 201
  * def reservaId = response.reserva.id

  Given path 'reservas', reservaId, 'pago'
  And request { tarjeta_prueba: '#(ticketpe.cards.approved)' }
  When method post
  Then status 201

  Given path 'reservas', reservaId, 'pago'
  And request { tarjeta_prueba: '#(ticketpe.cards.approved)' }
  When method post
  Then status 409
  And match response.error == 'ya_confirmada'

Scenario: no se puede reservar más entradas de las disponibles
  Given path 'reservas'
  And request { evento_id: '#(elegido.evento_id)', tipo: '#(elegido.tipo)', cantidad: 99999 }
  When method post
  Then status 409
  And match response.error == 'sin_cupo'

Scenario: un cupón inexistente no se aplica a la reserva
  Given path 'reservas'
  And request { evento_id: '#(elegido.evento_id)', tipo: '#(elegido.tipo)', cantidad: 1 }
  When method post
  Then status 201
  * def reservaId = response.reserva.id

  Given path 'reservas', reservaId, 'cupon'
  And request { codigo: 'CUPON-QA-INEXISTENTE' }
  When method post
  Then status 400
  And match response.error == 'cupon_invalido'

Scenario: reservar exige autenticación
  * configure headers = null
  Given path 'reservas'
  And request { evento_id: '#(elegido.evento_id)', tipo: '#(elegido.tipo)', cantidad: 1 }
  When method post
  Then status 401
  And match response.error == 'no_autenticado'

Scenario: un usuario no puede ver la reserva de otro
  Given path 'reservas'
  And request { evento_id: '#(elegido.evento_id)', tipo: '#(elegido.tipo)', cantidad: 1 }
  When method post
  Then status 201
  * def reservaId = response.reserva.id

  * def intruso = call read('helpers/usuario.feature')
  * configure headers = auth.bearer(intruso.token)
  Given path 'reservas', reservaId
  When method get
  Then status 403
  And match response.error == 'no_autorizado'
