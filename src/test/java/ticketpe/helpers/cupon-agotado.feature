@ignore
Feature: cupón de un solo uso ya consumido por otra compra (helper reutilizable)

Scenario: agotar cupón
  * def cupon = call read('classpath:ticketpe/helpers/cupon.feature') { usos_maximos: 1 }
  * def codigo = cupon.codigo
  * def comprador = call read('classpath:ticketpe/helpers/usuario.feature')
  Given url baseUrl
  And configure headers = auth.bearer(comprador.token)
  And path 'reservas'
  And request { evento_id: '#(ticketpe.roles.organizer.evento_id)', tipo: 'General', cantidad: 1 }
  When method post
  Then status 201
  * def reservaId = response.reserva.id

  Given path 'reservas', reservaId, 'cupon'
  And request { codigo: '#(codigo)' }
  When method post
  Then status 200

  Given path 'reservas', reservaId, 'pago'
  And request { tarjeta_prueba: '#(ticketpe.cards.approved)' }
  When method post
  Then status 201
