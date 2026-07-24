import sqlite3
import sys

fecha_corte = sys.argv[1]


conexion = sqlite3.connect("data/input/sobregiros.db")
cursor = conexion.cursor()
print("PASO 1: conexion abierta correctamente")
cursor.execute("""
    SELECT num_cta, fecha_movimiento, COUNT(*)
    FROM movimientos
    WHERE cod_trn = '006'
    GROUP BY num_cta, fecha_movimiento
    HAVING COUNT(*) > 1
""")


class Caso:
    def __init__(self, cuenta, valor_credito, num_embargos, pendiente_total, aplicado_sobregiro, estado_trx_006):
        self.cuenta = cuenta
        self.valor_credito = valor_credito
        self.num_embargos = num_embargos
        self.pendiente_total = pendiente_total
        self.aplicado_sobregiro = aplicado_sobregiro
        self.estado_trx_006 = estado_trx_006

    def es_alerta(self):
        return self.aplicado_sobregiro > 0

    def clasificacion(self):
        if self.es_alerta():
            return "ALERTA"
        else:
            return "NORMAL"

cursor.execute("""
    SELECT c.num_cta, m.fecha_movimiento, m.valor_movimiento AS valor_credito,
           emb.num_embargos, emb.pendiente_total,
           sob.total_aplicado_sobregiro,
          trx006.estado_movimiento AS estado_trx_006 
    FROM cuentas c
    JOIN movimientos m ON m.num_cta = c.num_cta
                       AND m.fecha_movimiento = c.fecha_cierre
    JOIN (
        SELECT num_cta, COUNT(*) AS num_embargos, SUM(saldo_pendiente_embargo) AS pendiente_total
        FROM embargos
        WHERE estado_embargo = 'ACTIVO'
        GROUP BY num_cta
    ) emb ON emb.num_cta = c.num_cta
    LEFT JOIN (
        SELECT num_cta, fecha_movimiento, SUM(valor_movimiento) AS total_aplicado_sobregiro
        FROM movimientos
        WHERE grupo_movimiento = 'APLICACION_SOBREGIRO'
        GROUP BY num_cta, fecha_movimiento
    ) sob ON sob.num_cta = c.num_cta AND sob.fecha_movimiento = c.fecha_cierre
 LEFT JOIN movimientos trx006
    ON trx006.id_movimiento = (
        SELECT t.id_movimiento FROM movimientos t
        WHERE t.num_cta = c.num_cta
          AND t.cod_trn = '006'
          AND t.fecha_movimiento = date(c.fecha_cierre, '+1 day')
        ORDER BY t.id_movimiento DESC
        LIMIT 1
    )   
    WHERE c.cod_aplicacion = 'CTE'
      AND c.cupo_sobregiro > 0
      AND m.naturaleza = 'CREDITO'
      AND m.grupo_movimiento = 'RECURSO_EMBARGABLE'
      AND m.fecha_movimiento = ?
      """, (fecha_corte,))

resultado_clasificado = cursor.fetchall()
print("PASO 2: la consulta trajo", len(resultado_clasificado), "filas")

casos = []
for fila in resultado_clasificado:
    num_cta = fila[0]
    valor_credito = fila[2]
    num_embargos = fila[3]
    pendiente_total = fila[4]
    aplicado_sobregiro = fila[5] if fila[5] is not None else 0
    estado_trx_006 = fila[6]
    casos.append(Caso(num_cta, valor_credito, num_embargos, pendiente_total, aplicado_sobregiro, estado_trx_006))
        


import csv
with open("data/output/tabla_resultado.csv","w",newline="") as archivo:
    escritor = csv.writer(archivo, delimiter=';')
    escritor.writerow(["cuenta", "valor_credito", "num_embargos", "pendiente_total",
                        "aplicado_sobregiro", "estado_trx_006", "clasificacion"])
    for caso in casos:
        escritor.writerow([
        caso.cuenta,
        str(caso.valor_credito).replace(".", ","),
        caso.num_embargos,
        str(caso.pendiente_total).replace(".", ","),
        str(caso.aplicado_sobregiro).replace(".", ","),
        caso.estado_trx_006,
        caso.clasificacion()
    ]) 
