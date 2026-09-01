# Medidas DAX — modelo GOLD (borrador, a incorporar en el .pbip)

Todas las medidas parten de la fact `FACT_PLAYER_SEASON` (grano jugador-temporada-club-competición). El valor de mercado (`market_value_eur_season_end`) y el score (`performance_score`) **no se pueden sumar/promediar directamente** cuando un jugador tiene varias filas en la misma temporada (varias competiciones): hay que recalcularlos con medidas que deduplican o recomponen la tasa. Ver la nota en el README (Fase 3 — GOLD).

## Medidas base (aditivas, sin trampa)

```dax
Minutos Jugados = SUM(FACT_PLAYER_SEASON[minutes_played])

Goles = SUM(FACT_PLAYER_SEASON[goals])

Asistencias = SUM(FACT_PLAYER_SEASON[assists])

Partidos Jugados = SUM(FACT_PLAYER_SEASON[games_played])

Nº Jugadores =
DISTINCTCOUNT(FACT_PLAYER_SEASON[player_id])
```

## Performance Score (recalculado, no sumado)

Umbral de 450 minutos acordado en SQL; se replica aquí porque la medida recompone la tasa a cualquier nivel de agregación (una competición, un club, o toda la temporada).

```dax
Performance Score =
VAR Mins = [Minutos Jugados]
VAR Num  = SUMX(FACT_PLAYER_SEASON, FACT_PLAYER_SEASON[goals] * 2 + FACT_PLAYER_SEASON[assists])
RETURN
    IF(Mins >= 450, DIVIDE(Num, Mins / 90))
```

```dax
Score Medio =
-- promedio del Performance Score entre los jugadores del contexto de filtro actual
AVERAGEX(VALUES(DIM_PLAYER[player_id]), [Performance Score])
```

## Valor de mercado (deduplicado por jugador-temporada)

`market_value_eur_season_end` se repite en todas las filas club/competición de un mismo jugador-temporada (documentado en SILVER/GOLD), así que sumarlo tal cual multiplicaría el valor por el nº de competiciones del jugador. Se deduplica con `SUMMARIZE` antes de sumar.

```dax
Valor Total de Mercado =
SUMX(
    SUMMARIZE(
        FACT_PLAYER_SEASON,
        FACT_PLAYER_SEASON[player_id],
        FACT_PLAYER_SEASON[season],
        "mv", MAX(FACT_PLAYER_SEASON[market_value_eur_season_end])
    ),
    [mv]
)
```

```dax
Valor Medio de Mercado =
AVERAGEX(
    SUMMARIZE(
        FACT_PLAYER_SEASON,
        FACT_PLAYER_SEASON[player_id],
        FACT_PLAYER_SEASON[season],
        "mv", MAX(FACT_PLAYER_SEASON[market_value_eur_season_end])
    ),
    [mv]
)
```

## Uso por visual (página Overview)

| Visual | Campos | Medidas |
|---|---|---|
| KPI: Nº jugadores | — | `[Nº Jugadores]` |
| KPI: Valor total de mercado | — | `[Valor Total de Mercado]` |
| KPI: Score medio | — | `[Score Medio]` |
| Top jugadores por score | `DIM_PLAYER[player_name]` | `[Performance Score]` (ordenar desc, Top N) |
| Evolución temporal por temporada | `DIM_SEASON[season_label]` | `[Performance Score]` y `[Valor Medio de Mercado]` |
| Top clubs/ligas por valor | `DIM_CLUB[club_name]` o `DIM_COMPETITION[competition_name]` | `[Valor Total de Mercado]` |
| Scatter score vs. valor | eje X `[Valor Medio de Mercado]`, eje Y `[Performance Score]`, detalle `DIM_PLAYER[player_name]`, color `DIM_PLAYER[position]` | — |
| Posiciones con mayor valor medio | `DIM_PLAYER[position]` | `[Valor Medio de Mercado]` |

## Filtros / slicers

`DIM_SEASON[season_label]`, `DIM_COMPETITION[competition_name]`, `DIM_CLUB[club_name]`, `DIM_PLAYER[position]`.

## Relaciones a verificar en el modelo (vista Modelo de Power BI Desktop)

- `FACT_PLAYER_SEASON[player_id]` → `DIM_PLAYER[player_id]` (activa)
- `FACT_PLAYER_SEASON[club_id]` → `DIM_CLUB[club_id]` (activa)
- `FACT_PLAYER_SEASON[competition_id]` → `DIM_COMPETITION[competition_id]` (activa)
- `FACT_PLAYER_SEASON[season]` → `DIM_SEASON[season]` (activa)
- `FACT_PLAYER_SEASON[market_value_as_of_date]` → `DIM_DATE[date_day]` (marcar como **inactiva**: el eje temporal principal es `dim_season`, no `dim_date`; esta relación es solo para análisis puntuales de fecha de valoración)
