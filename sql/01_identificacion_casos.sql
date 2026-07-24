
-- Actividad 3 - Modelamiento de datos
-- Motor: SQLite. 

-- Query 1: metadata de cada tabla (nombre de columna, tipo, si es PK)
PRAGMA table_info(cuentas);
PRAGMA table_info(embargos);
PRAGMA table_info(movimientos);

-- Query 2: llaves foraneas declaradas (el esquema real no declara FKs;
-- la relacion es logica via num_cta, ver docs/actividad3_modelo_datos.md)
PRAGMA foreign_key_list(embargos);
PRAGMA foreign_key_list(movimientos);

-- Query 3: cuentas corrientes (cod_aplicacion = 'CTE') con sobregiro
-- (cupo_sobregiro > 0) y embargo vigente (estado_embargo = 'ACTIVO'),
-- que recibieron transacciones credito, indicando si el credito se
-- aplico a sobregiro (interes y/o capital) el mismo dia.
--
-- IMPORTANTE: los embargos se agregan por cuenta (COUNT/SUM/MIN) en vez
-- de unirlos directamente, porque una misma cuenta puede tener mas de un
-- embargo ACTIVO simultaneo (ver excepcion E1, Actividad 2); un JOIN
-- directo duplicaria el credito una vez por cada embargo concurrente.
SELECT
    c.num_cta,
    c.fecha_cierre,
    c.estado                AS estado_cuenta,
    c.cupo_sobregiro,
    c.dias_sobregiro,
    emb.num_embargos_activos,
    emb.valor_embargo_total,
    emb.saldo_pendiente_total,
    emb.embargo_mas_antiguo,
    m.id_movimiento,
    m.fecha_movimiento      AS fecha_credito,
    m.valor_movimiento      AS valor_credito,
    m.descripcion           AS descripcion_credito,
    COALESCE(sob.valor_aplicado_sobregiro, 0) AS valor_aplicado_sobregiro,
    CASE
        WHEN COALESCE(sob.valor_aplicado_sobregiro, 0) > 0
        THEN 'ALERTA: aplicado a sobregiro el mismo dia del credito'
        ELSE 'NORMAL: sin aplicacion a sobregiro ese dia'
    END AS clasificacion_aplicacion
FROM cuentas c
JOIN (
    SELECT num_cta,
           COUNT(*)              AS num_embargos_activos,
           SUM(valor_embargo)    AS valor_embargo_total,
           SUM(saldo_pendiente_embargo) AS saldo_pendiente_total,
           MIN(fecha_embargo)    AS embargo_mas_antiguo
    FROM embargos
    WHERE estado_embargo = 'ACTIVO'
    GROUP BY num_cta
) emb ON emb.num_cta = c.num_cta
JOIN movimientos m
    ON m.num_cta = c.num_cta
   AND m.fecha_movimiento = c.fecha_cierre
   AND m.naturaleza = 'CREDITO'
   AND m.grupo_movimiento = 'RECURSO_EMBARGABLE'
LEFT JOIN (
    SELECT num_cta, fecha_movimiento, SUM(valor_movimiento) AS valor_aplicado_sobregiro
    FROM movimientos
    WHERE grupo_movimiento = 'APLICACION_SOBREGIRO'
    GROUP BY num_cta, fecha_movimiento
) sob ON sob.num_cta = c.num_cta AND sob.fecha_movimiento = c.fecha_cierre
WHERE c.cod_aplicacion = 'CTE'
  AND c.cupo_sobregiro > 0
ORDER BY m.fecha_movimiento DESC, c.num_cta;

-- Query 4: monitoreo diario (Normal vs Alerta). Se ejecuta "hoy" para
-- evaluar los creditos de "ayer" (:fecha_corte) en cuentas corrientes
-- embargadas con sobregiro, y ademas revisa el estado FINAL del debito
-- 006 del dia siguiente (:fecha_corte + 1) para saber si quedo
-- rechazado o si se corrigio con un ajuste posterior. Esta es la query
-- que usa src/main.py.
--
-- Los embargos se agregan por cuenta (evita duplicar el credito cuando
-- hay embargos concurrentes) y la trx 006 se resuelve al ULTIMO
-- movimiento registrado ese dia (MAX(id_movimiento)), porque un rechazo
-- puede tener un "ajuste posterior" el mismo dia que es el estado real
-- final, no el rechazo original.
SELECT
    c.num_cta,
    c.estado                AS estado_cuenta,
    c.cupo_sobregiro,
    emb.num_embargos_activos,
    emb.valor_embargo_total,
    emb.saldo_pendiente_total,
    m.id_movimiento,
    m.fecha_movimiento       AS fecha_credito,
    m.valor_movimiento       AS valor_recibido,
    COALESCE(sob.valor_aplicado_sobregiro, 0) AS valor_aplicado_sobregiro,
    trx006.valor_movimiento  AS valor_trx_006,
    trx006.estado_movimiento AS estado_trx_006
FROM cuentas c
JOIN (
    SELECT num_cta,
           COUNT(*)              AS num_embargos_activos,
           SUM(valor_embargo)    AS valor_embargo_total,
           SUM(saldo_pendiente_embargo) AS saldo_pendiente_total
    FROM embargos
    WHERE estado_embargo = 'ACTIVO'
    GROUP BY num_cta
) emb ON emb.num_cta = c.num_cta
JOIN movimientos m
    ON m.num_cta = c.num_cta
   AND m.fecha_movimiento = c.fecha_cierre
   AND m.naturaleza = 'CREDITO'
   AND m.grupo_movimiento = 'RECURSO_EMBARGABLE'
LEFT JOIN (
    SELECT num_cta, fecha_movimiento, SUM(valor_movimiento) AS valor_aplicado_sobregiro
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
  AND c.fecha_cierre = :fecha_corte;
