# Actividad 5 — Cierre ejecutivo

**Para:** Gerencia de Depósitos, Gerencia de Embargos, Cumplimiento normativo
**Asunto:** Solución funcional para el rechazo de la transacción 006 en cuentas embargadas con sobregiro

En cuentas corrientes embargadas que además tienen cupo de sobregiro activo, el sistema aplica
automáticamente los créditos recibidos a intereses y capital de sobregiro antes de que el área de
Embargos pueda trasladarlos al ente legal. Al día siguiente, la transacción 006 que ejecuta ese
traslado queda rechazada en el cierre de depósitos porque no está autorizada para tocar el cupo de
sobregiro, generando una cuenta por cobrar que Depósitos debe reclasificar o asumir contra su PYG.
La solución de fondo (habilitar la trx 006 en el motor de cierre) tarda alrededor de 3 años.

Para atender esta situación en el corto plazo, se propone cambiar el orden de aplicación de los
recursos: el embargo prioriza sobre el cobro de sobregiro, consistente con la jerarquía legal de
una orden judicial, y se adelanta el débito de Embargos al mismo día. Esto reduce el riesgo
regulatorio ante la Superintendencia Financiera, el riesgo contable de pérdidas recurrentes por
CxC no aplicadas, y cierra la brecha de trazabilidad sobre los recursos destinados a sobregiro
antes del embargo.

Como complemento, un producto de datos automatizado clasifica diariamente cada caso en Normal o
Alerta, permitiendo a Embargos actuar el mismo día en lugar de reaccionar ante rechazos ya
consumados. El tablero de monitoreo da visibilidad diaria del volumen de casos, el valor en riesgo
y la evolución del indicador de alertas a ambas gerencias.

La solución es parametrizable y no requiere modificar el motor de cierre, por lo que es
implementable en el plazo de 4 meses solicitado, y cada excepción queda documentada, dando soporte
auditable ante el regulador. Se recomienda aprobar la implementación de la regla de retención y el
producto de monitoreo como solución puente, sin descartar en paralelo la corrección estructural de
la trx 006 a mediano plazo.