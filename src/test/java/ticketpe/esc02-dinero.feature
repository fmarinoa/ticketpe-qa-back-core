@RIESGO-CRITICO
Feature: ESC02 - Dinero: cotización, cupones y pago

Background:
  * url baseUrl
  * def eventoPropio = ticketpe.roles.organizer.evento_id

@TC-API-06 @ESC02 @api @p2 @alto @RSK-04 @REQ-HU-E3.1 @REQ-HU-E8.1
Scenario: CP06 - la cotización aplica el descuento antes del IGV
  * def elegido = call read('helpers/evento-vendible.feature') { cantidad: 3 }
  * def cupon = call read('helpers/cupon.feature') { valor: 10, usos_maximos: 5, evento_id: '#(elegido.evento_id)' }
  Given path 'cotizaciones'
  And request { evento_id: '#(elegido.evento_id)', tipo: '#(elegido.tipo)', cantidad: 3, cupon: '#(cupon.codigo)' }
  When method post
  Then status 200
  And match response.cupon_aplicado == cupon.codigo
  * def c = response
  # margen de medición ±0.01: el README no fija regla de redondeo
  And assert Math.abs(c.subtotal - c.precio_unitario * 3) <= 0.01
  And assert Math.abs(c.descuento - c.subtotal * 0.10) <= 0.01
  And assert Math.abs(c.igv - (c.subtotal - c.descuento) * 0.18) <= 0.01
  And assert Math.abs(c.total - (c.subtotal - c.descuento + c.igv)) <= 0.01

@TC-API-07 @ESC02 @api @p2 @alto @RSK-24 @REQ-HU-E3.3 @REQ-HU-E8.1
Scenario: CP07 - un cupón inexistente, agotado o vencido no da descuento
  * def agotado = call read('helpers/cupon-agotado.feature')
  * def vencido = call read('helpers/cupon.feature') { vigente_desde: '2025-01-01T00:00:00Z', vigente_hasta: '2025-02-01T00:00:00Z' }
  * def comprador = call read('helpers/usuario.feature')
  * configure headers = auth.bearer(comprador.token)
  Given path 'reservas'
  And request { evento_id: '#(eventoPropio)', tipo: 'General', cantidad: 1 }
  When method post
  Then status 201
  * def reservaId = response.reserva.id

  Given path 'reservas', reservaId, 'cupon'
  And request { codigo: 'QA-CUPON-INEXISTENTE' }
  When method post
  Then status 400

  Given path 'reservas', reservaId, 'cupon'
  And request { codigo: '#(agotado.codigo)' }
  When method post
  Then status 400

  Given path 'reservas', reservaId, 'cupon'
  And request { codigo: '#(vencido.codigo)' }
  When method post
  Then status 400

  Given path 'reservas', reservaId
  When method get
  Then status 200
  And match response.reserva.cupon_codigo == null

@TC-API-08 @ESC02 @api @p2 @alto @RSK-24 @REQ-HU-E8.1
Scenario: CP08 - crear un cupón exige código único y porcentaje hasta 100
  * def org = call read('helpers/login.feature') { role: 'organizer' }
  * def elegido = call read('helpers/evento-vendible.feature') { soloEvento: '#(eventoPropio)' }
  * def codigo = 'QA' + utils.randomPassword().toUpperCase()
  * def cupon = { tipo: 'porcentaje', usos_maximos: 5, vigente_desde: '2026-01-01T00:00:00Z', vigente_hasta: '2099-01-01T00:00:00Z', evento_id: '#(eventoPropio)' }

  Given path 'eventos', eventoPropio
  When method get
  Then status 200
  And match response.evento.organizador_id == org.usuario.id

  * configure headers = auth.bearer(org.token)
  Given path 'cupones'
  And request karate.merge(cupon, { codigo: codigo, valor: 100 })
  When method post
  Then status 201

  Given path 'cupones'
  And request karate.merge(cupon, { codigo: codigo, valor: 100 })
  When method post
  Then status 409

  Given path 'cupones'
  And request karate.merge(cupon, { codigo: 'QA' + utils.randomPassword().toUpperCase(), valor: 100.01 })
  When method post
  Then status 400

  * def asistente = call read('helpers/usuario.feature')
  * configure headers = auth.bearer(asistente.token)
  Given path 'cotizaciones'
  And request { evento_id: '#(eventoPropio)', tipo: '#(elegido.tipo)', cantidad: 1, cupon: '#(codigo)' }
  When method post
  Then status 200
  And match response.cupon_aplicado == codigo

@TC-API-09 @ESC02 @api @p2 @alto @RSK-07 @REQ-HU-E3.3
Scenario: CP09 - un pago rechazado conserva la reserva y permite reintentar
  * def comprador = call read('helpers/usuario.feature')
  * def elegido = call read('helpers/evento-vendible.feature') { cantidad: 2 }
  * configure headers = auth.bearer(comprador.token)
  Given path 'reservas'
  And request { evento_id: '#(elegido.evento_id)', tipo: '#(elegido.tipo)', cantidad: 2 }
  When method post
  Then status 201
  * def reservaId = response.reserva.id

  Given path 'reservas', reservaId, 'pago'
  And request { tarjeta_prueba: '#(ticketpe.cards.declined)' }
  When method post
  Then status 402

  Given path 'reservas', reservaId
  When method get
  Then status 200
  And match response.reserva.estado == 'pendiente'

  Given path 'reservas', reservaId, 'pago'
  And request { tarjeta_prueba: '#(ticketpe.cards.unknown)' }
  When method post
  Then status 400

  Given path 'reservas', reservaId
  When method get
  Then status 200
  And match response.reserva.estado == 'pendiente'

  Given path 'reservas', reservaId, 'pago'
  And request { tarjeta_prueba: '#(ticketpe.cards.approved)' }
  When method post
  Then status 201

  Given path 'mis-entradas'
  When method get
  Then status 200
  * def emitidas = karate.jsonPath(response, "$.entradas[?(@.reserva_id=='" + reservaId + "')]")
  And match emitidas == '#[2]'
  * def qrs = karate.jsonPath(emitidas, '$[*].codigo_qr')
  And match karate.distinct(qrs) == '#[2]'

@TC-API-10 @ESC02 @api @p2 @critico @RSK-23 @REQ-HU-E3.3
Scenario: CP10 - dos pagos simultáneos de la misma reserva emiten las entradas una sola vez
  * def comprador = call read('helpers/usuario.feature')
  * def elegido = call read('helpers/evento-vendible.feature') { cantidad: 2 }
  * configure headers = auth.bearer(comprador.token)
  Given path 'reservas'
  And request { evento_id: '#(elegido.evento_id)', tipo: '#(elegido.tipo)', cantidad: 2 }
  When method post
  Then status 201
  * def reservaId = response.reserva.id

  # sin Idempotency-Key
  * def pagos = call read('helpers/post-paralelo.feature') { ruta: '#("reservas/" + reservaId + "/pago")', cuerpo: { tarjeta_prueba: '#(ticketpe.cards.approved)' }, tokens: ['#(comprador.token)', '#(comprador.token)'] }
  And match pagos.estados contains only [201, 409]

  Given path 'mis-entradas'
  When method get
  Then status 200
  * def emitidas = karate.jsonPath(response, "$.entradas[?(@.reserva_id=='" + reservaId + "')]")
  And match emitidas == '#[2]'
