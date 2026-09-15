@autorizacion
Feature: Control de acceso por rol y por token

Background:
  * url baseUrl
  * def alta = callonce read('helpers/usuario.feature')

Scenario Outline: sin token, <caso> responde 401
  Given path <ruta>
  And params <query>
  And request <cuerpo>
  When method <verbo>
  Then status 401
  And match response.error == 'no_autenticado'

  Examples:
    | caso              | ruta                        | query           | cuerpo                 | verbo |
    | el check-in       | 'checkin'                   | null            | { codigo_qr: 'QR-X' }  | post  |
    | mis entradas      | 'mis-entradas'              | null            | null                   | get   |
    | el reporte ventas | 'reportes', 'ventas'        | { evento_id: 1 }| null                   | get   |

Scenario Outline: el rol asistente no puede usar <caso>
  * configure headers = auth.bearer(alta.token)
  Given path <ruta>
  And params <query>
  And request <cuerpo>
  When method <verbo>
  Then status 403
  And match response.error == 'no_autorizado'

  Examples:
    | caso              | ruta                 | query            | cuerpo                | verbo |
    | el check-in       | 'checkin'            | null             | { codigo_qr: 'QR-X' } | post  |
    | el reporte ventas | 'reportes', 'ventas' | { evento_id: 1 } | null                  | get   |
