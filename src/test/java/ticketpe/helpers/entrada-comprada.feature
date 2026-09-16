@ignore
Feature: compra una entrada y devuelve sus datos (helper reutilizable)

Scenario: comprar
  * def cantidad = karate.get('cantidad', 1)
  * def elegido = call read('classpath:ticketpe/helpers/evento-vendible.feature') { cantidad: '#(cantidad)', soloEvento: '#(karate.get("soloEvento", null))', excluirEvento: '#(karate.get("excluirEvento", null))' }
  Given url baseUrl
  And configure headers = auth.bearer(token)
  And path 'reservas'
  And request { evento_id: '#(elegido.evento_id)', tipo: '#(elegido.tipo)', cantidad: '#(cantidad)' }
  When method post
  Then status 201
  * def reserva = response.reserva

  Given path 'reservas', reserva.id, 'pago'
  And request { tarjeta_prueba: '#(ticketpe.cards.approved)' }
  When method post
  Then status 201
  * def entradas = response.entradas
  * def entrada = response.entradas[0]
