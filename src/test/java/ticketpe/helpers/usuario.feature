@ignore
Feature: alta de un asistente nuevo (helper reutilizable)

Scenario: registrar asistente
  * def correo = ticketpe.newEmail()
  # la password es del usuario, no del escenario: viaja con él y sobrevive al callonce
  * def password = utils.randomPassword()
  Given url baseUrl
  And path 'auth', 'registro'
  And request { nombre: 'QA Karate', correo: '#(correo)', password: '#(password)' }
  When method post
  Then status 201
  * def token = response.token
  * def usuario = response.usuario
