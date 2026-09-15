@ignore
Feature: disponibilidad de un evento (helper reutilizable)

Scenario: consultar
  Given url baseUrl
  And path 'eventos', evento_id, 'disponibilidad'
  When method get
  Then status 200
  * def disponibilidad = response.disponibilidad
