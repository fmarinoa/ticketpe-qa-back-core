@smoke @RIESGO-BAJO
Feature: Salud del servicio

Background:
  * url baseUrl

@health @REQ-SAL-01
Scenario: el servicio responde sano y con base de datos conectada
  Given path 'health'
  When method get
  Then status 200
  And match response == { estado: 'ok', base_de_datos: 'conectada' }
