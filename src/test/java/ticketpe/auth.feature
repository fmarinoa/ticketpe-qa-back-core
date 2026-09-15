@auth
Feature: Autenticación de asistentes

Background:
  * url baseUrl

@smoke
Scenario: registro de un asistente nuevo devuelve token y usuario verificado
  * def correo = ticketpe.newEmail()
  Given path 'auth', 'registro'
  And request { nombre: 'QA Karate', correo: '#(correo)', password: '#(ticketpe.password)' }
  When method post
  Then status 201
  And match response.token == '#regex ^usr_[a-f0-9]{24}$'
  And match response.usuario == { id: '#uuid', nombre: 'QA Karate', correo: '#(correo)', rol: 'asistente', verificado: true }

Scenario: no se puede registrar dos veces el mismo correo
  * def correo = ticketpe.newEmail()
  * def cuerpo = { nombre: 'QA Karate', correo: '#(correo)', password: '#(ticketpe.password)' }
  Given path 'auth', 'registro'
  And request cuerpo
  When method post
  Then status 201
  Given path 'auth', 'registro'
  And request cuerpo
  When method post
  Then status 409
  And match response.error == 'correo_en_uso'

Scenario Outline: el registro valida los campos obligatorios: <caso>
  Given path 'auth', 'registro'
  And request <cuerpo>
  When method post
  Then status 400
  And match response.error == 'entrada_invalida'
  And match response.detalle.fieldErrors.<campo> == '#present'

  Examples:
    | caso        | campo    | cuerpo                                                    |
    | sin nombre  | nombre   | { correo: 'a@testingperu.com', password: 'Qa123456' }     |
    | sin correo  | correo   | { nombre: 'QA', password: 'Qa123456' }                    |
    | sin password| password | { nombre: 'QA', correo: 'a@testingperu.com' }             |

@smoke
Scenario: login con credenciales válidas devuelve token
  * def alta = call read('helpers/usuario.feature')
  Given path 'auth', 'login'
  And request { correo: '#(alta.correo)', password: '#(alta.password)' }
  When method post
  Then status 200
  And match response.token == '#string'
  And match response.usuario.correo == alta.correo

Scenario: login con contraseña incorrecta
  * def alta = call read('helpers/usuario.feature')
  Given path 'auth', 'login'
  And request { correo: '#(alta.correo)', password: 'ClaveEquivocada1' }
  When method post
  Then status 401
  And match response.error == 'contraseña_incorrecta'

Scenario: login con un correo no registrado
  Given path 'auth', 'login'
  And request { correo: 'no.existe.qa@testingperu.com', password: '#(ticketpe.password)' }
  When method post
  Then status 401
  And match response.error == 'correo_no_registrado'

Scenario: /auth/me devuelve el usuario dueño del token
  * def alta = call read('helpers/usuario.feature')
  Given path 'auth', 'me'
  And headers auth.bearer(alta.token)
  When method get
  Then status 200
  And match response.usuario == alta.usuario

Scenario Outline: /auth/me rechaza tokens ausentes o inválidos: <caso>
  Given path 'auth', 'me'
  And configure headers = <headers>
  When method get
  Then status 401
  And match response.error == 'no_autenticado'

  Examples:
    | caso          | headers                             |
    | sin token     | null                                |
    | token basura  | { Authorization: 'Bearer usr_fake' }|
