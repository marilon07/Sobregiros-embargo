# Actividad 3 — Modelamiento de datos

## 1. Metadata de las tablas

### `cuentas` 

Cada fila es el estado de una cuenta al cierre de un día específico, no el estado
"actual" único. Esto es clave: para saber el estado de una cuenta hay que filtrar por
`fecha_cierre`, no asumir una sola fila por cuenta.

| Campo | Tipo | Descripción |
|---|---|---|
| num_cta | TEXT (PK compuesta, parte 1) | Número de cuenta |
| fecha_cierre | TEXT (PK compuesta, parte 2) | Fecha del snapshot (cierre diario) |
| cod_aplicacion | TEXT | `AHO` (ahorros) o `CTE` (corriente) |
| sld_actual | NUMERIC | Saldo al cierre de ese día |
| cupo_sobregiro | NUMERIC | Cupo de sobregiro aprobado (0 si la cuenta no tiene sobregiro) |
| dias_sobregiro | INTEGER | Días consecutivos que la cuenta lleva sobregirada |
| estado | TEXT | `ACTIVA`, `INACTIVA`, `EMBARGADA` |
| descri_estado_cta | TEXT | Descripción legible del estado |

### `embargos`

| Campo | Tipo | Descripción |
|---|---|---|
| id_embargo | INTEGER (PK) | Identificador único del embargo |
| num_cta | TEXT (FK implícita → cuentas.num_cta) | Cuenta embargada |
| fecha_embargo | TEXT | Fecha de radicado de la orden judicial |
| ente_legal | TEXT | Juzgado/entidad que ordena el embargo (ej. DIAN, UGPP, Juzgados) |
| valor_embargo | NUMERIC | Valor total exigido |
| saldo_pendiente_embargo | NUMERIC | Valor que aún falta por cubrir |
| estado_embargo | TEXT | `ACTIVO`, `CUBIERTO`, `LEVANTADO` |
| fecha_levantamiento | TEXT (nullable) | Fecha en que se levanta la medida |

### `movimientos`

| Campo | Tipo | Descripción |
|---|---|---|
| id_movimiento | INTEGER (PK) | Identificador único del movimiento |
| num_cta | TEXT (FK implícita → cuentas.num_cta) | Cuenta afectada |
| fecha_movimiento | TEXT | Fecha del movimiento |
| cod_trn | TEXT | Código de transacción: `001/002/009` (créditos normales u embargables), `101/102/103` (débitos normales), `006` (débito manual embargo cta corriente), `008` (débito manual embargo cta ahorros), `INT_SOB` / `CAP_SOB` (aplicación de interés/capital de sobregiro) |
| naturaleza | TEXT | `CREDITO` o `DEBITO` |
| valor_movimiento | NUMERIC | Valor del movimiento |
| grupo_movimiento | TEXT | `OPERACION_NORMAL`, `RECURSO_EMBARGABLE`, `PAGO_EMBARGO`, `APLICACION_SOBREGIRO` |
| tipo_aplicacion | TEXT (nullable) | `EMBARGO`, `INTERES`, `CAPITAL`, o `NULL` para movimientos normales |
| estado_movimiento | TEXT | `APLICADO` o `RECHAZADO` |
| descripcion | TEXT | Detalle libre (incluye, por ejemplo, "Rechazo cierre: trx 006 no autorizada para usar sobregiro") |

**Hallazgo clave del dataset real:** en la ventana de datos disponible (15-21 jul 2026), hay
exactamente 25 créditos con `descripcion = 'Ingreso en cuenta corriente sobregirada y
embargada'`, y exactamente 25 pares de movimientos `INT_SOB`/`CAP_SOB` el mismo día, y 25
movimientos `006` (algunos `RECHAZADO`, algunos con un `descripcion` de "Ajuste posterior al
rechazo"). Es decir, **el dataset reproduce el problema descrito en el caso de negocio**: toda cuenta corriente con sobregiro y embargo activo que recibió un crédito, en esta
muestra, tuvo su crédito aplicado a sobregiro antes que al embargo.

## 2. Relación entre tablas y llaves

- No hay llaves foráneas declaradas en el esquema (`PRAGMA foreign_key_list` devuelve vacío
 para las 3 tablas), pero la relación lógica es:
 - `cuentas.num_cta` (parte de la PK compuesta `num_cta + fecha_cierre`) ↔ `embargos.num_cta`: **1 a muchos** (una cuenta puede tener más de un embargo, concurrente o histórico).
 - `cuentas.num_cta` ↔ `movimientos.num_cta`: **1 a muchos**.
- Igual que en el diseño original: **no existe una columna que vincule directamente un
 movimiento con un embargo específico** (`embargo_id` no existe en `movimientos`). El vínculo
 se infiere por `num_cta` + cercanía de fechas + `grupo_movimiento`/`tipo_aplicacion`. Esto
 sigue siendo una limitación real del modelo para el caso de embargos concurrentes (E1 en la
 Actividad 2).
- `cuentas` requiere tratamiento como tabla histórica: cualquier query que necesite "el estado
 actual" debe filtrar explícitamente por la fecha de corte relevante (normalmente
 `MAX(fecha_cierre)` o una fecha específica), no hacer `SELECT * FROM cuentas WHERE num_cta = ...`
 sin fecha, porque devuelve hasta 7 filas por cuenta.

## 3. Query: cuentas corrientes activas/embargadas, con sobregiro y embargo vigente, con créditos

Ver [`sql/01_identificacion_casos.sql`](../sql/01_identificacion_casos.sql) , Query 3

Lógica: se toma el snapshot de `cuentas` en la fecha de corte (`cod_aplicacion = 'CTE'`,
`cupo_sobregiro > 0`), se une con `embargos` en estado `ACTIVO`, y se une con los créditos
(`naturaleza = 'CREDITO'`, `grupo_movimiento = 'RECURSO_EMBARGABLE'`) de esa misma fecha. Para
rastrear si el crédito se aplicó a sobregiro antes que al embargo, se hace un `LEFT JOIN`
adicional contra los movimientos `APLICACION_SOBREGIRO` (`INT_SOB`/`CAP_SOB`) de la misma
cuenta y fecha: si existen y suman más de 0, el caso queda marcado como alerta.
