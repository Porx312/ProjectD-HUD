# ProjectD HUD (template)

Tres widgets CSP Lua con **datos falsos** ? sin API por ahora. **No depende de CMRT** ni de otras apps Lua.

| Widget | Descripci�n |
|--------|-------------|
| **ProjectD Top 10** | Ranking del servidor (clave futura: server + track + layout + car) |
| **ProjectD Profile** | Tu perfil: foto, nombre, tier, coche, mejor tiempo |
| **ProjectD Rival** | Piloto #rank-1: etiqueta "rival", misma info |

## Instalaci�n

Copia la carpeta completa `ProjectD-HUD` a:

```
assettocorsa/apps/lua/ProjectD-HUD/
```

Requiere CSP 0.1.76+. Activa las 3 apps en el men� de AC.

## Assets incluidos (standalone)

Todo debe vivir dentro de `ProjectD-HUD/`. Al instalar en otro PC, copia esta carpeta entera con `assets/`:

| Archivo | Uso |
|---------|-----|
| `assets/panel_card.png` | Fondo Profile / Rival |
| `assets/leaderboard_panel.png` | Fondo Top 10 |
| `assets/logo.png` | Cabecera del leaderboard |
| `assets/tiers/tier0.png` ? `tier10.png` | Iconos de tier |
| `fonts/ArchivoSemiExpanded-Regular.ttf` | Texto normal |
| `fonts/ArchivoSemiExpanded-Medium.ttf` | Tiempos, coche (como CMRT) |
| `fonts/ArchivoSemiExpanded-Bold.ttf` | Nombres, ranks, cabecera |
| `icon.png` | Icono de la app en el men? CSP |

### Opcionales (solo si existen en `assets/`)

| Archivo | Widget |
|---------|--------|
| `panel_overlay.png` o `panel_gradient.png` | Profile, Rival |
| `leaderboard_overlay.png` o `leaderboard_gradient.png` | Top 10 |

Sin overlay, solo se muestra el panel base.

## Fuentes

El HUD usa **Archivo SemiExpanded** (la misma fuente que CMRT Essential HUD), embebida en `fonts/`.

- **Bold** ? nombres, ranks, titulo Top 10
- **Medium** ? tiempos, coche, linea secundaria
- **Regular** ? separadores y texto suave

Si faltan los `.ttf`, hace fallback a Segoe UI del sistema.

## Avatares por URL

Los mocks usan URLs de imagen; el HUD las descarga con `web.get` + `ui.decodeImage`.
Hace falta conexi�n a internet la primera vez.

## Cambiar datos de prueba

Edita `common/mock_data.lua`:

- `MOCK_CONTEXT` ? servidor, pista, layout, coche, Steam ID
- `LEADERBOARDS` ? top 10 por clave `server@track@layout@car`
- `PROFILES` ? perfil por Steam ID

## Pr�ximo paso (API)

## API en vivo (ProjectD)

Por defecto el HUD usa la API en el VPS (`common/data.lua` → `api_data.lua`).
Ahora el cliente consulta primero una versión ligera y solo descarga la sesión cuando cambia:

```
GET http://176.57.150.251:3000/hud/version
  ?serverName=&track=&steamIds=
```

- Si `version` cambia, el HUD llama a `GET /hud/session`
- Top 10: `GET /hud/top10?serverName&track&trackConfig&car`
- Jugador: `GET /hud/player?steamId&serverName&track&trackConfig`
- Bundle (3 widgets): `GET /hud/session` (incluye `profile.rival`)

URL base en `common/config.lua`. Mocks offline: `ac.storage("ProjectD-HUD:use_api", false):set()`

Docs: `ProjectD/docs/08-hud-api.md`
