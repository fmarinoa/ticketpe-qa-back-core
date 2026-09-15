@ignore
Feature: alta de un asistente nuevo (helper reutilizable)

Scenario: registrar asistente
  * def correo = 'qa.karate.' + java.util.UUID.randomUUID() + '@testingperu.com'
  Given url baseUrl
  And path 'auth', 'registro'
  And request { nombre: 'QA Karate', correo: '#(correo)', password: '#(password)' }
  When method post
  Then status 201
  * def token = response.token
  * def usuario = response.usuario
