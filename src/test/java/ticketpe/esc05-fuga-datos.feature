@ESC05 @seguridad @RIESGO-CRITICO
Feature: ESC05 - Fuga de datos y robustez de la entrada

Background:
  * url baseUrl

@TC-API-10 @REQ-HU-E3.3 @api @p1 @critico @autorizacion
Scenario: CP13 - el QR de una entrada no se puede adivinar desde otro
  # 5 cuentas x 4 entradas: el tope es 4 por evento y cuenta
  * def altas = call read('helpers/usuario.feature') [{}, {}, {}, {}, {}]
  * def compras = call read('helpers/entrada-comprada.feature') karate.map(altas, function(a){ return { token: a.token, cantidad: 4 } })
  * def entradas = karate.jsonPath(compras, '$[*].entradas[*]')
  * def qrs = karate.jsonPath(entradas, '$[*].codigo_qr')
  * match qrs == '#[_ >= 20]'
  # 0 colisiones
  * match karate.distinct(qrs) == '#[karate.sizeOf(qrs)]'
  # >= 128 bits = 32 hex
  * match each qrs == '#regex ^QR-[A-F0-9]{32,}$'
  # 0 prefijo incremental: los primeros 32 bits tampoco se repiten
  * match karate.distinct(karate.map(qrs, function(q){ return q.substring(0, 11) })) == '#[karate.sizeOf(qrs)]'

  * def tercero = call read('helpers/usuario.feature')
  * configure headers = auth.bearer(tercero.token)
  Given path 'entradas', entradas[0].id
  When method get
  Then status 403
  * string cuerpo = response
  And match cuerpo !contains entradas[0].codigo_qr

@TC-API-12 @REQ-HU-E5.2 @api @p1 @critico @regulatorio
Scenario: CP14 - el reporte de ventas no filtra datos de compradores
  * def comprador = call read('helpers/usuario.feature')
  * def compra = call read('helpers/entrada-comprada.feature') { token: '#(comprador.token)', cantidad: 1, soloEvento: '#(ticketpe.roles.organizer.evento_id)' }
  * def org = call read('helpers/login.feature') { role: 'organizer' }
  * def ajeno = call read('helpers/evento-vendible.feature') { excluirEvento: '#(ticketpe.roles.organizer.evento_id)' }
  * configure headers = auth.bearer(org.token)

  Given path 'reportes', 'ventas'
  And param evento_id = ticketpe.roles.organizer.evento_id
  When method get
  Then status 200
  * string cuerpo = response
  And match cuerpo !contains '"nombre"'
  And match cuerpo !contains '"correo"'
  And match cuerpo !contains '"documento"'
  And match cuerpo !contains '"telefono"'
  And match cuerpo !contains '"usuario_id"'
  And match cuerpo !contains '"codigo_qr"'
  And match cuerpo !contains comprador.correo
  And match cuerpo !contains comprador.usuario.id
  And match cuerpo !contains compra.entrada.codigo_qr

  Given path 'reportes', 'ventas'
  When method get
  * string cuerpo = response
  And match cuerpo !contains comprador.correo
  And match cuerpo !contains '"usuario_id"'
  And match cuerpo !contains '"codigo_qr"'

  Given path 'reportes', 'ventas'
  And param evento_id = ajeno.evento_id
  When method get
  Then status 403
