@RIESGO-CRITICO
Feature: ESC05 - Datos personales y texto libre

Background:
  * url baseUrl

@TC-API-18 @ESC05 @api @p2 @critico @RSK-13 @REQ-HU-E5.2
Scenario: CP18 - el reporte de ventas no expone datos de compradores
  * def nombre = 'QA Karate ' + utils.randomPassword()
  * def correo = ticketpe.newEmail()
  Given path 'auth', 'registro'
  And request { nombre: '#(nombre)', correo: '#(correo)', password: '#(utils.randomPassword())' }
  When method post
  Then status 201
  * def compra = call read('helpers/entrada-comprada.feature') { token: '#(response.token)', cantidad: 1 }
  * def eventoE = compra.elegido.evento_id
  * def admin = call read('helpers/login.feature') { role: 'admin' }
  * configure headers = auth.bearer(admin.token)

  Given path 'reportes', 'ventas'
  And param evento_id = eventoE
  When method get
  Then status 200
  And match response == { evento_id: '#notnull', evento_nombre: '#notnull', por_tipo: '#notnull', totales: '#notnull', formato: '#notnull' }
  * string cuerpo = response
  And match cuerpo !contains nombre
  And match cuerpo !contains correo
  # sin '@' no hay texto con forma de correo
  And match cuerpo !contains '@'

  Given path 'reportes', 'ventas'
  And param evento_id = eventoE
  And param formato = 'csv'
  When method get
  Then status 200
  * string cuerpo = response
  And match cuerpo !contains nombre
  And match cuerpo !contains correo
  # sin '@' no hay texto con forma de correo
  And match cuerpo !contains '@'

@TC-API-19 @ESC05 @api @p2 @alto @RSK-25 @REQ-HU-E2.1 @REQ-HU-E6.1 @REQ-HU-E4.3
Scenario: CP19 - texto libre malicioso no rompe el backend
  * def asistente = call read('helpers/usuario.feature')
  * def compra = call read('helpers/entrada-comprada.feature') { token: '#(asistente.token)', cantidad: 1 }

  Given path 'eventos'
  And param limite = 200
  When method get
  Then status 200
  * def catalogo = response.eventos

  Given path 'eventos'
  And param limite = 200
  And param query = "' OR 1=1--"
  When method get
  Then match responseStatus == '#? _ < 500'
  And match karate.get('response.eventos', []) == '#[_ < karate.sizeOf(catalogo)]'

  Given path 'soporte'
  And request { resumen: '<script>alert(1)</script>' }
  When method post
  Then status 201

  * def largo = karate.repeat(10000, function(){ return 'a' }).join('')
  Given path 'soporte'
  And request { resumen: '#(largo)' }
  When method post
  Then match responseStatus == '#? _ == 201 || _ == 400'
  And assert responseStatus == 201 || response.error != null

  * configure headers = auth.bearer(asistente.token)
  Given path 'entradas', compra.entrada.id, 'reembolso'
  And request { motivo: "'; DROP TABLE entradas;--" }
  When method post
  Then status 201

  Given path 'entradas', compra.entrada.id
  When method get
  Then status 200
