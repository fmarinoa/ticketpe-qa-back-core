@ignore
Feature: el organizador de pruebas crea un cupón porcentual para su evento (helper reutilizable)

Scenario: crear cupón
  * def org = call read('classpath:ticketpe/helpers/login.feature') { role: 'organizer' }
  * def codigo = 'QA' + java.util.UUID.randomUUID().toString().substring(0, 8).toUpperCase()
  * def cuerpo =
    """
    {
      codigo: '#(codigo)',
      tipo: 'porcentaje',
      valor: '#(karate.get("valor", 10))',
      usos_maximos: '#(karate.get("usos_maximos", 5))',
      vigente_desde: '#(karate.get("vigente_desde", "2026-01-01T00:00:00Z"))',
      vigente_hasta: '#(karate.get("vigente_hasta", "2099-01-01T00:00:00Z"))',
      evento_id: '#(ticketpe.roles.organizer.evento_id)'
    }
    """
  Given url baseUrl
  And path 'cupones'
  And configure headers = auth.bearer(org.token)
  And request cuerpo
  When method post
  Then status 201
