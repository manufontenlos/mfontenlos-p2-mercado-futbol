# Proyecto 2 — Fútbol: Ingesta en Snowflake + Modelo Silver/Gold + Power BI

Mini sistema analítico en Snowflake (**RAW → SILVER → GOLD**) construido a partir del dataset de Kaggle [player-scores](https://www.kaggle.com/datasets/davidcariboo/player-scores) ([repo origen](https://github.com/dcaribou/transfermarkt-datasets)), con tablas materializadas en cada capa y un modelo en estrella en GOLD listo para conectar Power BI.

> Estado del proyecto: **RAW, SILVER, GOLD y Power BI completados**. Este documento se actualiza a medida que avanza cada fase — ver [Estado actual y próximos pasos](#estado-actual-y-próximos-pasos).

---

## Arquitectura

```
CSV (Kaggle)
   │  PUT manual a stage interno
   ▼
STAGE  RAW.STG_TRANSFERMARKT  (file format RAW.FF_CSV)
   │  COPY INTO
   ▼
RAW      →  tablas materializadas, 1:1 con los CSV origen, tipadas
   │        (NUMBER / DATE / VARCHAR) pero sin limpiar
   │  SQL (CTAS)
   ▼
SILVER   →  tablas materializadas, limpias y deduplicadas:
   │        dim_player, dim_club, dim_competition, fct_player_season
   │  SQL (CTAS)
   ▼
GOLD     →  modelo en estrella listo para BI:
   │        dim_player, dim_club, dim_competition, dim_season, dim_date,
   │        fact_player_season (con KPI performance_score)
   │
   ▼
Power BI →  informe .pbip conectado a GOLD (3 páginas: Overview, Análisis, Detalle)
```

### Nota importante sobre las fuentes

El enunciado original menciona `raw.player_scores` como tabla origen, pero **ese CSV no existe** en la versión actual del dataset descargado — solo hay 5 ficheros en `data/`: `players.csv`, `clubs.csv`, `competitions.csv`, `player_valuations.csv`, `appearances.csv`. Las métricas de rendimiento por partido (goles, asistencias, tarjetas, minutos) viven en `appearances.csv`, así que todo el modelo (incluida `fct_player_season`) se ha construido sin `player_scores`.

---

## Estructura del repositorio

```
p2-futbol/
├── README.md
├── data/                          # CSV origen (no versionar si pesan mucho / usar .gitignore)
│   ├── players.csv
│   ├── clubs.csv
│   ├── competitions.csv
│   ├── player_valuations.csv
│   └── appearances.csv
├── sql/
│   ├── raw/
│   │   ├── 00_setup.sql            # database, schema, file format, stage
│   │   ├── 01_create_tables.sql    # CREATE TABLE de las 5 tablas RAW
│   │   ├── 02_copy_into.sql        # COPY INTO desde el stage
│   │   └── 03_checks.sql           # controles mínimos de RAW
│   ├── silver/
│   │   ├── 01_dim_player.sql
│   │   ├── 02_dim_club.sql
│   │   ├── 03_dim_competition.sql
│   │   ├── 04_fct_player_season.sql
│   │   └── 05_checks.sql           # controles de calidad de SILVER
│   └── gold/
│       ├── 01_dim_player.sql
│       ├── 02_dim_club.sql
│       ├── 03_dim_competition.sql
│       ├── 04_dim_season.sql
│       ├── 05_dim_date.sql         # calendario continuo generado en SQL
│       ├── 06_fact_player_season.sql
│       └── 07_checks.sql           # controles del modelo en estrella
├── powerbi/
│   └── dax_measures.md             # referencia de las 9 medidas DAX del modelo
├── informe_futbol.pbip             # proyecto Power BI
├── informe_futbol.SemanticModel/   # modelo semántico (TMDL): tablas, relaciones, medidas
└── informe_futbol.Report/          # informe (PBIR/JSON): páginas y visuales
```

(El proyecto Power BI está en formato `.pbip` — texto/JSON editable directamente, en vez de `.pbix` binario — lo que permitió iterar medidas y visualizaciones por código.)

---

## Cómo ejecutar

Requiere una cuenta de Snowflake con permisos para crear base de datos/schemas/tablas, y el cliente que prefieras (Snowsight, SnowSQL, `snowflake-connector-python`…). Las credenciales se gestionan por variables de entorno / `.env` (nunca en el repo — añadido a `.gitignore`).

1. **Setup + carga RAW** (en orden):
   ```
   sql/raw/00_setup.sql       -- crea DB, schema, file format y stage
   -- subir los 5 CSV al stage RAW.STG_TRANSFERMARKT (PUT o Snowsight)
   sql/raw/01_create_tables.sql
   sql/raw/02_copy_into.sql
   sql/raw/03_checks.sql      -- verificar resultados (ver sección de checks)
   ```
2. **Transformación SILVER** (en orden):
   ```
   sql/silver/01_dim_player.sql
   sql/silver/02_dim_club.sql
   sql/silver/03_dim_competition.sql
   sql/silver/04_fct_player_season.sql
   sql/silver/05_checks.sql   -- verificar resultados
   ```
3. **Modelo GOLD** (en orden):
   ```
   sql/gold/01_dim_player.sql
   sql/gold/02_dim_club.sql
   sql/gold/03_dim_competition.sql
   sql/gold/04_dim_season.sql
   sql/gold/05_dim_date.sql
   sql/gold/06_fact_player_season.sql
   sql/gold/07_checks.sql     -- verificar resultados
   ```
4. **Power BI**: abrir `informe_futbol.pbip` en Power BI Desktop, conectar a `FOOTBALL.GOLD` — ver [Fase 4 — Power BI](#fase-4--power-bi).

---

## Fase 1 — RAW

Ingesta 1:1 de los 5 CSV a tablas materializadas en `FOOTBALL.RAW`, vía `COPY INTO` desde un stage interno (`RAW.STG_TRANSFERMARKT`) con un file format común (`RAW.FF_CSV`: CSV, cabecera, `"` como enclosure, vacíos y `'NULL'` tratados como `NULL`).

Las columnas se tipan de forma nativa cuando el formato del CSV es limpio y consistente (fechas ISO `YYYY-MM-DD` → `DATE`, enteros/decimales → `NUMBER`), y se dejan como `VARCHAR` los campos de texto libre o con formato "sucio" (p.ej. `net_transfer_record`, que mezcla símbolos de moneda y signo).

**Tablas creadas:** `raw.players` (50.149 filas), `raw.clubs` (796), `raw.competitions` (65), `raw.player_valuations` (656.301), `raw.appearances` (1.894.350).

**Controles mínimos aplicados** (`03_checks.sql`):
- Conteo de filas por tabla vs. CSV origen.
- Duplicados por clave: `player_id`, `club_id`, `competition_id`, `appearance_id` (único), y `(player_id, date)` para `player_valuations` (no tiene ID propio).
- Sanity check de nulos y rangos en columnas clave (fechas, minutos jugados, valor de mercado).

**Hallazgo de calidad de datos:** `players.date_of_birth` tiene 49 nulos sobre 50.149 filas — es un hueco real del dataset origen (perfiles antiguos/incompletos en Transfermarkt), confirmado también tras la carga. Decisión: no imputar, mantener `NULL`.

---

## Fase 2 — SILVER (solo SQL)

Tablas materializadas limpias, deduplicadas y con claves consistentes, construidas con `CREATE OR REPLACE TABLE ... AS SELECT` desde RAW.

### `silver.dim_player`
Desde `raw.players`. Dedup defensivo por `player_id`, `TRIM` en texto. `date_of_birth` se mantiene sin imputar. `international_caps` / `international_goals`: `NULL → 0` (sin apariciones internacionales registradas equivale a 0, no a "desconocido").

### `silver.dim_club`
Desde `raw.clubs`. Dedup por `club_id`. Se descarta `total_market_value` (siempre `NULL` en origen). Se añade `net_transfer_record_eur`: parseo del texto original (`'+€5.90m'`, `'€-25.00m'`, `'+-0'`, `'+€900k'`, `'€-180k'`) a un número en EUR, conservando también el valor original.

### `silver.dim_competition`
Desde `raw.competitions`. Dedup por `competition_id`. `country_id = -1` (competiciones sin país, p.ej. internacionales) se convierte a `NULL`.

### `silver.fct_player_season`
**Grano: jugador · temporada · club · competición.** Construida solo desde `appearances` + `player_valuations` (no existe `player_scores` en este dataset).

- **Temporada:** convención Transfermarkt — una temporada "Y" cubre de julio del año Y a junio del año Y+1 (`season = 2012` → 2012/2013). Se deriva de la fecha: `MONTH >= 7 → YEAR`, si no `→ YEAR - 1`.
- **Métricas de rendimiento** (goles, asistencias, tarjetas amarillas/rojas, minutos, partidos jugados): suma de todas las apariciones del jugador en esa temporada-club-competición.
- **Valor de mercado:** se toma la **última valoración registrada dentro de la temporada** del jugador (no la media), porque Transfermarkt actualiza el valor de forma puntual e irregular — el último valor conocido es el más representativo del cierre de temporada. Como la valoración no está desglosada por club/competición en la fuente, se repite para todas las combinaciones club-competición de ese jugador en esa temporada.

**Controles de calidad aplicados** (`05_checks.sql`): conteo de filas, unicidad de claves en las 3 dimensiones, unicidad del grano de la fact (jugador-temporada-club-competición), integridad referencial fact → dimensiones, y cobertura de valor de mercado por temporada.

**Decisión de calidad de datos — claves huérfanas:** al validar `fct_player_season` contra `dim_club` y `dim_competition` aparecen ~686 `club_id` (11.062 filas, 0,58%) y 4 `competition_id` (14.200 filas, 0,75%) que no existen en las dimensiones — equipos de categorías inferiores y competiciones menores no catalogados en el dataset origen. **Decisión tomada: mantenerlas tal cual**, sin filtrar ni reasignar a un miembro "Desconocido", priorizando no perder histórico de rendimiento. Consecuencia esperada y documentada: en Power BI esas filas (~1,3% del total) aparecerán como `(en blanco)` al relacionar con `dim_club`/`dim_competition`.

---

## Fase 3 — GOLD

Modelo en estrella para consumo directo desde Power BI, con `dim_player`, `dim_club`, `dim_competition`, `dim_season` y `dim_date` alrededor de `fact_player_season`.

### `gold.dim_player` / `gold.dim_club` / `gold.dim_competition`
Paso directo desde las tablas SILVER equivalentes (ya limpias). En `dim_player` se excluyen `url`/`image_url`, que no aportan a los KPIs ni visuales pedidos.

### `gold.dim_season`
Construida a partir de las temporadas realmente presentes en `fct_player_season` (no es un rango arbitrario). Añade `season_label` (`"2012/2013"`), `season_start_year`, `season_end_year` para facilitar los filtros y el eje temporal en Power BI.

### `gold.dim_date`
Calendario **continuo** (sin huecos) generado en SQL con `TABLE(GENERATOR(...))`, cuyo rango se calcula a partir de las fechas mínima y máxima presentes en `appearances.date` y `player_valuations.date` (2000-01-20 a 2026-06-28 en la carga actual). Incluye año, trimestre, mes, día, día de la semana y semana del año. Un calendario continuo es necesario para que las funciones de time intelligence de Power BI (acumulados, interanual, etc.) funcionen correctamente — una tabla con solo las fechas "sueltas" que aparecen en los datos tendría huecos y rompería esos cálculos.

Uso previsto: relacionar con `fact_player_season.market_value_as_of_date`. El eje temporal principal del análisis sigue siendo `dim_season`, porque la fact está a grano temporada, no a grano día.

### `gold.fact_player_season`
Mismo grano que en SILVER (jugador · temporada · club · competición), con dos columnas añadidas para los KPIs del Overview de Power BI:

- `goal_contributions` = `goals + assists`.
- `performance_score` — el dataset **no trae ninguna columna de score** pese a llamarse "player-scores" (solo goles, asistencias, tarjetas y minutos por aparición), así que se definió una fórmula propia, acordada explícitamente: **contribución de gol por 90 minutos** = `(goles × 2 + asistencias) / (minutos_jugados / 90)`. Se normaliza por minutos jugados para comparar de forma justa a titulares y suplentes. Es la base de los visuales "top jugadores por score" y "scatter score vs. valor" pedidos en el enunciado.

  **Corrección por muestra pequeña:** al validar el top 10 real en Snowflake apareció el problema clásico de las tasas por 90' — un jugador con 1 gol en 1 minuto jugado daba `performance_score = 180`, el más alto de toda la temporada, sin ser rendimiento real (extrapola 1 minuto a 90). Se añadió un **umbral mínimo de 450 minutos** (≈ 5 partidos completos): por debajo, `performance_score` queda en `NULL`, así no contamina ni el "score medio" ni el ranking de "top jugadores". Es el criterio estándar en estadística deportiva para evitar rankings dominados por apariciones testimoniales.

**Controles aplicados** (`07_checks.sql`): conteos, unicidad de claves en las 5 dimensiones, ausencia de huecos en `dim_date`, unicidad del grano de la fact, integridad referencial fact → dimensiones (hereda de SILVER las claves huérfanas de `club_id`/`competition_id`, ya documentadas y aceptadas — no es un fallo nuevo de GOLD), y sanity check del propio `performance_score` (score medio, min/max, huecos) más un top 10 de la última temporada disponible.

⚠️ **Nota clave para Power BI (fase 4):** `fact_player_season` está a grano jugador-**temporada-club-competición**, así que `performance_score` es la tasa de esa fila (una sola competición), no la de la temporada completa del jugador. Comprobado con datos reales: Harry Kane en 2025/2026 tiene una fila en Bundesliga (2.382 min) y otra en Champions League (1.041 min); sumando todas sus competiciones acumula 5.211 minutos esa temporada — el dato está completo, no truncado (el CSV llega hasta 2026-06-28, fin real de la temporada). Al ser una tasa, **`performance_score` no se puede sumar entre filas** — en Power BI debe recalcularse como medida DAX (`DIVIDE(SUMX(tabla, Goals*2 + Assists), SUM(Minutes)/90)`, con el umbral de 450 min aplicado sobre los minutos ya agregados al nivel que se esté viendo), nunca arrastrando la columna con Suma/Promedio directo.

---

## Fase 4 — Power BI

Proyecto `informe_futbol.pbip` (formato de texto: TMDL para el modelo semántico, JSON para el informe, en vez de `.pbix` binario), conectado a Snowflake (`FOOTBALL.GOLD`, modo Import).

### Modelo semántico

- **6 tablas**: `dim_player`, `dim_club`, `dim_competition`, `dim_season`, `dim_date`, `fact_player_season`.
- **5 relaciones**: `player_id`, `season`, `competition_id` y `club_id` activas; `market_value_as_of_date → dim_date.date_day` inactiva (el eje temporal principal del informe es `dim_season`, no el calendario diario).
- **9 medidas DAX** en `fact_player_season` (carpeta "Medidas"): Minutos Jugados, Goles, Asistencias, Partidos Jugados, Nº Jugadores, Performance Score, Score Medio, Valor Total de Mercado, Valor Medio de Mercado — documentadas también en `powerbi/dax_measures.md`.
- `PERFORMANCE_SCORE` y `MARKET_VALUE_EUR_SEASON_END` tienen `summarizeBy = ninguno` en la fact, para forzar el uso de las medidas en vez de sumar/promediar la columna cruda por error.

### Informe (3 páginas, filtros sincronizados entre ellas)

**Overview** — 3 KPI (Nº Jugadores, Valor Total de Mercado, Score Medio) + 4 filtros (Temporada, Competición, Club, Posición) + 4 gráficos: Top jugadores por score (barras horizontales, Top N = 10), Evolución del valor medio de mercado por temporada (línea), Top clubs por valor de mercado (columnas, Top N = 10), y Score vs. valor de mercado (dispersión, color por posición — la vista de "oportunidades").

**Análisis** — misma cabecera de 3 KPI + 4 filtros que Overview, y 4 gráficos en cuadrícula 2×2: Top ligas/competiciones por valor de mercado (Top N = 10), Valor medio de mercado por posición, Rendimiento medio (Performance Score) por posición, y distribución de jugadores por posición (donut).

**Detalle** — misma cabecera de 3 KPI, tabla completa a grano jugador-temporada-club-competición (jugador, posición, club, competición, temporada, goles, asistencias, minutos, `[Performance Score]`, `[Valor Medio de Mercado]`) y 9 filtros a la derecha: 5 segmentaciones categóricas (Temporada, Competición, Club, Jugador, Posición) y 4 numéricas en modo rango (`MINUTES_PLAYED`, `GOALS`, `ASSISTS`, `MARKET_VALUE_EUR_SEASON_END`) — permite defender cualquier cifra del informe bajando al dato crudo.

### Cobertura de las 5 preguntas de negocio del enunciado

| Pregunta | Dónde se responde | Estado |
|---|---|---|
| ¿Qué jugadores destacan por score en una temporada? | Overview → "Top jugadores por score" | Cubierta |
| ¿Qué clubs/ligas concentran mayor valor de mercado? | Overview → "Top clubs por valor" · Análisis → "Top ligas por valor" | Cubierta |
| ¿Cómo evoluciona el valor y el rendimiento por temporada? | Overview → "Evolución del valor medio de mercado por temporada" | Cubierta (decisión consciente: se prioriza la evolución del valor, que es la que más varía de temporada a temporada; el rendimiento se analiza por posición en Análisis en vez de en el tiempo) |
| ¿Existen jugadores con score alto pero valor bajo ("oportunidades")? | Overview → scatter "Score vs. valor de mercado" (cuadrante superior-izquierdo) · Detalle → tabla filtrable/ordenable | Cubierta |
| ¿Qué posiciones tienen mayor valor medio? | Análisis → "Valor medio de mercado por posición" (Attack €5,1M y Midfield €4,8M lideran; Goalkeeper el más bajo, €2,8M) | Cubierta |

Las 5 preguntas del enunciado quedan cubiertas.

---

## Registro de decisiones técnicas

| Decisión | Alternativas consideradas | Elegido | Motivo |
|---|---|---|---|
| Tipado en RAW | Todo `VARCHAR` (staging puro) vs. tipado nativo | Tipado nativo donde el CSV es limpio | El CSV es consistente (fechas ISO, numéricos limpios); tipar en RAW ya satisface el control "tipos de dato correctos" y no bloquea la carga |
| `date_of_birth` con nulos | Imputar vs. mantener `NULL` | Mantener `NULL` | Imputar distorsionaría edad/generación; es un hueco real de la fuente |
| Grano de `fct_player_season` | Por partido vs. por temporada-club-competición | Temporada-club-competición | Es el grano pedido por el enunciado; agrega suficiente para BI sin perder detalle de club/competición |
| Valor de mercado en `fct_player_season` | Media anual vs. último valor de la temporada | Último valor de la temporada | El valor de mercado es puntual e irregular; el último valor es más representativo del cierre de temporada |
| Claves huérfanas (`club_id`, `competition_id`) en la fact | Filtrar / miembro "Desconocido" / mantener tal cual | Mantener tal cual | Prioridad: no perder histórico de rendimiento (~1,3% de las filas afectadas) |
| Fórmula de `performance_score` (no existe columna de score en el dataset) | Volumen bruto sin normalizar / score compuesto con tarjetas / contribución de gol por 90' | Contribución de gol por 90': `(goles×2 + asistencias) / (minutos/90)` | Compara de forma justa a titulares y suplentes; fácil de explicar en la presentación |
| Umbral mínimo de minutos para `performance_score` (tasas por 90' con muestra pequeña se disparaban: 1 gol en 1 min → score 180) | Sin umbral / columna `eligible_for_ranking` aparte / umbral -> `NULL` | `NULL` si `minutes_played < 450` (~5 partidos) | Estándar en estadística deportiva; evita que apariciones testimoniales dominen el ranking, detectado al validar el top 10 real |
| Granularidad de `dim_date` | Solo fechas "sueltas" presentes en los datos / calendario continuo | Calendario continuo (min–max) | Necesario para que el time intelligence de Power BI (acumulados, interanual) no tenga huecos |
