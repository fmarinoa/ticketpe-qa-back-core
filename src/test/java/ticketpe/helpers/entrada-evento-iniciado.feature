@ignore
Feature: entrada vigente de un evento que ya empezó (helper reutilizable)

  No hay API para crear eventos ni mover el reloj: la entrada sale del historial
  sembrado de una cuenta demo. `indice` separa los escenarios que corren en
  paralelo para que no compitan por la misma entrada.

Scenario: buscar entrada
  * def dueno = call read('classpath:ticketpe/helpers/login.feature') { role: 'attendee' }
  Given url baseUrl
  And configure headers = auth.bearer(dueno.token)
  And path 'mis-entradas'
  When method get
  Then status 200
  # ponytail: pool finito; si el API tiene el bug, cada corrida consume una entrada sembrada
  * def candidatas = response.entradas.filter(function(e){ return utils.minutesBetween(utils.now(), e.fecha_inicio) < 0 && e.estado == 'emitida' && !e.transferida && !e.reembolso_estado })
  * match candidatas == '#[_ > karate.get("indice", 0)]'
  * def entrada = candidatas[karate.get('indice', 0)]
  * def token = dueno.token
