@entradas
Feature: Entradas, transferencia y reembolso

Background:
  * url baseUrl
  # usuario nuevo por escenario: el API limita a 4 entradas por evento y usuario
  * def alta = call read('helpers/usuario.feature')
  * configure headers = auth.bearer(alta.token)

@smoke
Scenario: mis entradas lista las entradas emitidas con datos del evento
  * def compra = call read('helpers/entrada-comprada.feature') { token: '#(alta.token)', cantidad: 1 }
  Given path 'mis-entradas'
  When method get
  Then status 200
  And match response.entradas == '#[_ > 0]'
  And match response.entradas[*].id contains compra.entrada.id
  And match each response.entradas contains { codigo_qr: '#string', estado: '#string', evento_nombre: '#string', tipo_nombre: '#string', precio: '#number' }

Scenario: el detalle de una entrada propia devuelve su código QR
  * def compra = call read('helpers/entrada-comprada.feature') { token: '#(alta.token)', cantidad: 1 }
  Given path 'entradas', compra.entrada.id
  When method get
  Then status 200
  And match response.entrada contains { id: '#(compra.entrada.id)', usuario_id: '#(alta.usuario.id)', estado: 'emitida', transferida: false }

Scenario: una entrada inexistente devuelve 404
  Given path 'entradas', '00000000-0000-0000-0000-000000000000'
  When method get
  Then status 404
  And match response.error == 'no_encontrado'

Scenario: el reembolso de una entrada de un evento futuro queda solicitado
  * def compra = call read('helpers/entrada-comprada.feature') { token: '#(alta.token)', cantidad: 1 }
  Given path 'entradas', compra.entrada.id, 'reembolso'
  And request { motivo: 'Cambio de planes, no podré asistir al evento' }
  When method post
  Then status 201
  And match response.reembolso contains { id: '#uuid', entrada_id: '#(compra.entrada.id)', estado: 'solicitado' }

  Given path 'mis-entradas'
  When method get
  Then status 200
  And match response.entradas contains deep { id: '#(compra.entrada.id)', reembolso_estado: 'solicitado' }

@smoke
Scenario: transferir una entrada la deja a nombre del destinatario
  * def compra = call read('helpers/entrada-comprada.feature') { token: '#(alta.token)', cantidad: 1 }
  * def destino = call read('helpers/usuario.feature')
  Given path 'entradas', compra.entrada.id, 'transferir'
  And request { correo_destino: '#(destino.correo)' }
  When method post
  Then status 200
  And match response.ok == true

  Given path 'entradas', compra.entrada.id
  When method get
  Then status 403
  And match response.error == 'no_autorizado'

  * configure headers = auth.bearer(destino.token)
  Given path 'entradas', compra.entrada.id
  When method get
  Then status 200
  And match response.entrada contains { usuario_id: '#(destino.usuario.id)', transferida: true }

Scenario: una entrada solo se puede transferir una vez
  * def compra = call read('helpers/entrada-comprada.feature') { token: '#(alta.token)', cantidad: 1 }
  * def primero = call read('helpers/usuario.feature')
  Given path 'entradas', compra.entrada.id, 'transferir'
  And request { correo_destino: '#(primero.correo)' }
  When method post
  Then status 200

  * def segundo = call read('helpers/usuario.feature')
  * configure headers = auth.bearer(primero.token)
  Given path 'entradas', compra.entrada.id, 'transferir'
  And request { correo_destino: '#(segundo.correo)' }
  When method post
  Then status 409

Scenario: transferir a un correo sin cuenta devuelve 404
  * def compra = call read('helpers/entrada-comprada.feature') { token: '#(alta.token)', cantidad: 1 }
  Given path 'entradas', compra.entrada.id, 'transferir'
  And request { correo_destino: 'no.existe.qa@testingperu.com' }
  When method post
  Then status 404
  And match response.error == 'destinatario_no_encontrado'
