@RIESGO-CRITICO
Feature: ESC01 - Cuentas, rol y propiedad

Background:
  * url baseUrl

@TC-API-01 @ESC01 @api @p2 @critico @RSK-18 @REQ-HU-E1.2 @REQ-HU-E1.1
Scenario: CP01 - el registro entrega un token de asistente utilizable al instante
  * def correo = ticketpe.newEmail()
  * def password = utils.randomPassword()
  * def elegido = call read('helpers/evento-vendible.feature')

  Given path 'auth', 'registro'
  And request { nombre: 'QA Karate', correo: '#(correo)', password: '#(password)' }
  When method post
  Then status 201
  And match response.token == '#string'
  * def token = response.token

  * configure headers = auth.bearer(token)
  Given path 'reservas'
  And request { evento_id: '#(elegido.evento_id)', tipo: '#(elegido.tipo)', cantidad: 1 }
  When method post
  Then status 201

  Given path 'auth', 'me'
  When method get
  Then status 200
  And match response.usuario.rol == 'asistente'

  * configure headers = null
  Given path 'auth', 'registro'
  And request { nombre: 'QA Karate', correo: '#(correo)', password: '#(password)' }
  When method post
  Then status 409

  Given path 'auth', 'login'
  And request { correo: '#(correo)', password: 'incorrecta-123' }
  When method post
  Then status 401

  Given path 'auth', 'login'
  And request { correo: '#(ticketpe.newEmail())', password: '#(password)' }
  When method post
  Then status 401

@TC-API-02 @ESC01 @api @p1 @critico @RSK-02 @REQ-HU-E1.3 @REQ-HU-E1.2 @REQ-HU-E5.1 @REQ-HU-E8.1
Scenario: CP02 - el rol lo determina el token y no lo que declara el cuerpo
  Given path 'auth', 'registro'
  And request { nombre: 'QA Karate', correo: '#(ticketpe.newEmail())', password: '#(utils.randomPassword())', rol: 'administrador' }
  When method post
  Then status 201
  * def token = response.token
  * def compra = call read('helpers/entrada-comprada.feature') { token: '#(token)', cantidad: 1 }
  * configure headers = auth.bearer(token)

  Given path 'auth', 'me'
  When method get
  Then status 200
  And match response.usuario.rol == 'asistente'

  Given path 'checkin'
  And request { codigo_qr: '#(compra.entrada.codigo_qr)' }
  When method post
  Then status 403

  Given path 'reportes', 'ventas'
  And param evento_id = compra.elegido.evento_id
  When method get
  Then status 403

  Given path 'cupones'
  And request { codigo: '#("QA" + utils.randomPassword().toUpperCase())', tipo: 'porcentaje', valor: 10, usos_maximos: 1, vigente_desde: '2026-01-01T00:00:00Z', vigente_hasta: '2099-01-01T00:00:00Z', evento_id: '#(compra.elegido.evento_id)' }
  When method post
  Then status 403

  Given path 'entradas', compra.entrada.id
  When method get
  Then status 200
  And match response.entrada.estado == 'emitida'

@TC-API-03 @ESC01 @api @p2 @alto @RSK-27 @REQ-HU-E1.3
Scenario Outline: CP03 - un token de usuario alterado se rechaza y no se atiende como visitante: <caso>
  * def alta = callonce read('helpers/usuario.feature')
  * def t = alta.token
  * def elegido = callonce read('helpers/evento-vendible.feature')
  * configure headers = auth.bearer(<token>)
  Given path <ruta>
  And request <cuerpo>
  When method <verbo>
  Then status 401

  Examples:
    | caso                           | token                                                   | verbo | ruta           | cuerpo                                                                          |
    | mis-entradas, último carácter  | t.substring(0, t.length - 1) + (t.endsWith('0') ? '1' : '0') | get   | 'mis-entradas' | null                                                                            |
    | reservas, último carácter      | t.substring(0, t.length - 1) + (t.endsWith('0') ? '1' : '0') | post  | 'reservas'     | { evento_id: '#(elegido.evento_id)', tipo: '#(elegido.tipo)', cantidad: 1 }     |
    | mis-entradas, truncado a mitad | t.substring(0, t.length / 2)                            | get   | 'mis-entradas' | null                                                                            |
    | reservas, truncado a mitad     | t.substring(0, t.length / 2)                            | post  | 'reservas'     | { evento_id: '#(elegido.evento_id)', tipo: '#(elegido.tipo)', cantidad: 1 }     |

@TC-API-04 @ESC01 @api @p1 @critico @RSK-03 @REQ-HU-E4.1
Scenario: CP04 - un asistente no puede ver la entrada de otro asistente
  * def duenoA = call read('helpers/usuario.feature')
  * def compra = call read('helpers/entrada-comprada.feature') { token: '#(duenoA.token)', cantidad: 1 }
  # call y no callonce: callonce cachea por el texto de la línea y devolvería al mismo usuario
  * def intrusoB = call read('helpers/usuario.feature')

  * configure headers = auth.bearer(intrusoB.token)
  Given path 'entradas', compra.entrada.id
  When method get
  Then status 403
  And match response.error == '#present'
  * string cuerpo = response
  And match cuerpo !contains compra.entrada.codigo_qr

  * configure headers = null
  Given path 'entradas', compra.entrada.id
  When method get
  Then status 401

  * configure headers = auth.bearer(duenoA.token)
  Given path 'entradas', compra.entrada.id
  When method get
  Then status 200

@TC-API-05 @ESC01 @api @p2 @alto @RSK-12 @REQ-HU-E5.1 @REQ-HU-E5.2 @REQ-HU-E8.1
Scenario: CP05 - un organizador no opera sobre eventos ajenos
  * def org = call read('helpers/login.feature') { role: 'organizer' }
  * def asistente = call read('helpers/usuario.feature')
  * def compra = call read('helpers/entrada-comprada.feature') { token: '#(asistente.token)', cantidad: 1, excluirEvento: '#(ticketpe.roles.organizer.evento_id)' }
  * def ajeno = compra.elegido.evento_id
  * def codigo = 'QA' + utils.randomPassword().toUpperCase()

  Given path 'eventos', ajeno
  When method get
  Then status 200
  And match response.evento.organizador_id != org.usuario.id

  * configure headers = auth.bearer(org.token)
  Given path 'checkin'
  And request { codigo_qr: '#(compra.entrada.codigo_qr)' }
  When method post
  Then status 403

  Given path 'reportes', 'ventas'
  And param evento_id = ajeno
  When method get
  Then status 403

  Given path 'cupones'
  And request { codigo: '#(codigo)', tipo: 'porcentaje', valor: 10, usos_maximos: 5, vigente_desde: '2026-01-01T00:00:00Z', vigente_hasta: '2099-01-01T00:00:00Z', evento_id: '#(ajeno)' }
  When method post
  Then status 403

  * configure headers = auth.bearer(asistente.token)
  Given path 'entradas', compra.entrada.id
  When method get
  Then status 200
  And match response.entrada.estado == 'emitida'

  * configure headers = null
  Given path 'cotizaciones'
  And request { evento_id: '#(ajeno)', tipo: '#(compra.elegido.tipo)', cantidad: 1, cupon: '#(codigo)' }
  When method post
  Then status 400
