@RIESGO-ALTO
Feature: ESC03 - Inventario: concurrencia, expiración y tope

Background:
  * url baseUrl

@TC-API-13 @ESC03 @api @p2 @alto @RSK-06 @REQ-HU-E3.2
Scenario: CP13 - el tope de 4 suma lo comprado y lo reservado vigente
  * def comprador = call read('helpers/usuario.feature')
  * def compra = call read('helpers/entrada-comprada.feature') { token: '#(comprador.token)', cantidad: 2 }
  * def pedido = { evento_id: '#(compra.elegido.evento_id)', tipo: '#(compra.elegido.tipo)' }
  * configure headers = auth.bearer(comprador.token)

  Given path 'reservas'
  And request karate.merge(pedido, { cantidad: 1 })
  When method post
  Then status 201

  # 2 compradas + 1 reservada + 2 = 5
  Given path 'reservas'
  And request karate.merge(pedido, { cantidad: 2 })
  When method post
  Then status 409

  # 2 + 1 + 1 = 4
  Given path 'reservas'
  And request karate.merge(pedido, { cantidad: 1 })
  When method post
  Then status 201

  # 4 + 1 = 5
  Given path 'reservas'
  And request karate.merge(pedido, { cantidad: 1 })
  When method post
  Then status 409
