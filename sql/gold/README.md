# GOLD

Capa de consumo: esquema en estrella (dimensiones + hechos) optimizado para que Power BI consulte directamente, sin lógica de negocio ni limpieza — eso ya se resolvió en SILVER.

## Modelo actual (ya construido, conectado a Power BI)

- `DIM_PLAYER`, `DIM_CLUB`, `DIM_COMPETITION`, `DIM_SEASON`, `DIM_DATE`
- `FACT_PLAYER_SEASON` (grano: jugador × temporada × club × competición)

## Decisiones de diseño

**Sin SCD Tipo 2 en `DIM_PLAYER` / `DIM_CLUB`.** Se decidió deliberadamente no versionar históricamente estas dimensiones (no guardamos "cómo era el club antes del cambio X"). El motivo es que `FACT_TRANSFER` (ver abajo) ya captura el histórico de pertenencia a club en cada fecha de fichaje, que es el caso de uso real que nos importa. Añadir SCD Tipo 2 aquí sería complejidad sin un requisito de negocio detrás — sobre-ingeniería.

**Dimensiones de rol (`role-playing dimensions`) resueltas en Power Query, no como tablas físicas duplicadas.** `FACT_TRANSFER` tiene dos relaciones con club (club de origen y club de destino). En vez de crear dos tablas físicas `DIM_CLUB_ORIGEN` y `DIM_CLUB_DESTINO` en el warehouse (duplicando datos y manteniendo dos copias sincronizadas), se crea una única `DIM_CLUB` física y dos *reference queries* en Power Query que la referencian con nombres distintos. Power BI las trata como tablas independientes a efectos de relaciones, pero siguen leyendo de la misma fuente.

## Ampliaciones previstas

**`FACT_TRANSFER`** (de `transfers.csv`): grano = un fichaje. Relaciona jugador, club origen, club destino, fecha y valor de la transferencia. Es la tabla que aporta histórico de pertenencia a club sin necesidad de SCD Tipo 2 en `DIM_CLUB`.

**`FACT_CLUB_GAME`** (de `club_games.csv`): grano = club × partido (una fila por cada uno de los dos clubes que juegan un partido), no partido único. Se elige este grano en vez de `games.csv` directamente para evitar el problema de "doble relación" (un partido tiene club local Y club visitante; modelarlo a nivel de partido obligaría a una relación activa/inactiva o a duplicar la dimensión club, igual que con `FACT_TRANSFER`). Con el grano club-partido, cada fila ya tiene "un" club, y la relación con `DIM_CLUB` es directa y sin ambigüedad. `DIM_GAME` (si se añade) queda como dimensión compartida a nivel de partido para atributos que no dependen del club (fecha, competición, temporada, marcador).

## Estructura prevista

Un archivo `sql/gold/<tabla>.sql` por dimensión/hecho, con el `CREATE OR REPLACE TABLE ... AS SELECT` que arma la tabla a partir de SILVER.
