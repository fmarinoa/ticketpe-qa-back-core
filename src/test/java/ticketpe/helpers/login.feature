@ignore
Feature: login de un rol fijo (helper reutilizable)

Scenario: loguear rol
  * def creds = ticketpe.roles[role]
  Given url baseUrl
  And path 'auth', 'login'
  And request { correo: '#(creds.email)', password: '#(creds.password)' }
  When method post
  Then status 200
  * def token = response.token
  * def usuario = response.usuario
