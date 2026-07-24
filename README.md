# Prueba técnica

## Estructura del repositorio

```
sobregiros-embargos/
├── README.md                          <- este archivo
├── requirements.txt
├── .gitignore
├── data/
│   ├── input/
│   │   └── sobregiros.db              <- base de datos REAL entregada para la prueba
│   └── output/
│       └── tabla_resultado.csv        <- resultado generado por src/main.py
├── docs/
│   ├── documentos_soporte/
│   │   ├── AS_IS/
│   │   │   ├── analisis_problema.md
│   │   │   └── proceso_asis.jpg
│   │   └── TO_BE/
│   │       ├── reglas_negocio.md
│   │       └── proceso_tobe.jpg
│   ├── modelo_datos.md
│   ├── cierre_ejecutivo.md
│  
├── dashboard/
│   ├── tablero_monitoreo.pbix         <- tablero de monitoreo en Power BI
│   └── descripcion_tablero.md
├── sql/
│   └── 01_identificacion_casos.sql
└── src/
    └── main.py                        <- script principal: consulta, POO y automatización

```


## Cómo ejecutar la solución

Requiere Python 3.10+ (usa sintaxis de type hints con `|`).

```bash
## Cómo ejecutar la solución

Requiere Python 3.10+ (en Windows, usa el comando `py` en vez de `python3`).

```bash
# 1. Clonar el repositorio y entrar a la carpeta
git clone <url-del-repo>
cd sobregiros-embargos

# 2. Instalar dependencias (opcionales, solo si quieres correr pytest)
pip install -r requirements.txt

# 3. Ejecutar el monitoreo diario (2026-07-20 es la unica fecha con creditos
#    en cuentas corrientes embargadas y sobregiradas en este dataset)
py src/main.py 2026-07-20
```

El script imprime en consola la tabla de casos clasificados (Normal / Alerta) y exporta el
resultado completo a `data/output/tabla_resultado.csv`.
```

## Guía de lectura por actividad

## Guía de lectura por actividad

| Actividad | Dónde está |
|---|---|
| 1. Análisis del problema (As-Is) | `docs/documentos_soporte/AS_IS/analisis_problema.md` |
| 2. Diseño funcional (To-Be) | `docs/documentos_soporte/TO_BE/reglas_negocio.md` |
| 3. Modelamiento de datos | `docs/modelo_datos.md`, `sql/01_identificacion_casos.sql`, `src/main.py` |
| 4. Visualización del monitoreo | `dashboard/descripcion_tablero.md` + `dashboard/tablero_monitoreo.pbix` |
| 5. Comunicación ejecutiva | `docs/cierre_ejecutivo.md` |


## Supuestos y decisiones clave (resumen)

- Se priorizó el Escenario 2 (cuenta corriente con sobregiro y embargo) por ser el que origina el problema.
- La solución funcional propuesta no modifica el motor de cierre de depósitos (eso tardaría ~3 años);
  actúa antes, mediante una regla de exclusión/retención parametrizable y un producto de datos de monitoreo,
  lo que la hace viable en el plazo de 4 meses solicitado.
- `cuentas` es una tabla de snapshot diario (PK compuesta `num_cta + fecha_cierre`); la query filtra
  explícitamente por fecha de corte en vez de asumir una sola fila por cuenta.
- No existe un vínculo directo (`embargo_id`) entre `movimientos` y `embargos`; se infiere por
  cuenta + fecha + `grupo_movimiento`/`tipo_aplicacion`. Esto se documenta como limitación del
  modelo (ver `docs/modelo_datos.md`).
- Se detectaron cuentas con más de un embargo `ACTIVO` simultáneo; la query agrega los embargos
  por cuenta (`COUNT`/`SUM`) antes de unir, para no duplicar créditos por cada embargo concurrente.
- Cuando la trx 006 tiene más de un movimiento el mismo día (rechazo + ajuste posterior), se toma
  el último registrado (`MAX(id_movimiento)`) como estado final, no el rechazo original.
