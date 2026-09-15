@catalogo
Feature: Catálogo de eventos

Background:
  * url baseUrl

@smoke
Scenario: el listado devuelve eventos con la estructura esperada
  Given path 'eventos'
  When method get
  Then status 200
  And match response.eventos == '#[_ > 0]'
  And match each response.eventos contains { id: '#number', nombre: '#string', ciudad: '#string', lugar: '#string', fecha_inicio: '#string', fecha_fin: '#string', es_gratuito: '#boolean' }

Scenario: el filtro por ciudad solo devuelve eventos de esa ciudad
  Given path 'eventos'
  And param ciudad = 'Arequipa'
  When method get
  Then status 200
  And match response.eventos == '#[_ > 0]'
  And match each response.eventos contains { ciudad: 'Arequipa' }

Scenario: una ciudad sin eventos devuelve una lista vacía
  Given path 'eventos'
  And param ciudad = 'Ciudad Inexistente QA'
  When method get
  Then status 200
  And match response.eventos == []

@smoke
Scenario: la ficha de un evento incluye sus tipos de entrada
  Given path 'eventos'
  When method get
  Then status 200
  * def id = response.eventos[0].id
  Given path 'eventos', id
  When method get
  Then status 200
  And match response.evento contains { id: '#(id)', nombre: '#string', organizador_id: '#uuid' }
  And match each response.tipos_entrada contains { id: '#number', nombre: '#string', precio: '#number', cupo_total: '#number', cupo_vendido: '#number' }
  And match each response.tipos_entrada == '#? _.cupo_vendido <= _.cupo_total'

Scenario: un evento inexistente devuelve 404
  Given path 'eventos', 999999
  When method get
  Then status 404
  And match response.error == 'no_encontrado'

Scenario: la disponibilidad nunca supera el cupo total del tipo de entrada
  * def elegido = call read('helpers/evento-vendible.feature')
  Given path 'eventos', elegido.evento_id
  When method get
  Then status 200
  * def tipos = response.tipos_entrada
  Given path 'eventos', elegido.evento_id, 'disponibilidad'
  When method get
  Then status 200
  And match response.evento_id == elegido.evento_id
  And match each response.disponibilidad contains { tipo_entrada_id: '#number', nombre: '#string', precio: '#number', disponible: '#number', venta_abierta: '#boolean' }
  And match each response.disponibilidad == '#? _.disponible >= 0'
  * def porId = function(id){ return tipos.filter(function(t){ return t.id == id })[0] }
  # <= y no ==: las reservas pendientes de otros usuarios bloquean cupo sin haberlo vendido
  * def coherente = function(d){ var t = porId(d.tipo_entrada_id); return d.disponible <= t.cupo_total - t.cupo_vendido }
  And match each response.disponibilidad == '#? coherente(_)'
