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

Por defecto el HUD usa la API staging (`common/data.lua` → `api_data.lua`) vía **SSE unificado**.

**URL base** en `common/config.lua`:

```
https://dev-api.projectd.space
```

No uses `localhost` ni la IP del VPS desde el juego.

### Online setup checklist

1. **API** — `API_BASE_URL = "https://dev-api.projectd.space"` en `common/config.lua` (ya es el default).
2. **Server bridge (recomendado)** — Copia `server-bridge/projectd_steam_bridge.lua` al server CSP:
   ```
   assettocorsa/extension/lua/online/projectd_steam_bridge.lua
   ```
   Publica tu Steam ID64 para el overlay (las apps Lua no pueden usar `ac.getUserSteamID()`).
3. **Entrar al server online** — El HUD abre SSE al detectar sesión online:
   ```
   GET https://dev-api.projectd.space/hud/stream?steamId=YOUR_STEAM_ID&carFilter=global
   ```
   Si el VPS usa `HUD_API_KEY`, guarda la clave: `ac.storage("ProjectD-HUD:api_key", "…"):set()`
4. **Esperar `hud_session`** — Profile/Competition muestran datos tras el evento SSE. Un breve *"Waiting for server registration…"* es normal hasta que el worker registre `player_join`. Si ves *"Server not registered in ProjectD — leave and rejoin"*, sal del server y vuelve a entrar (obligatorio tras cambios en ac-data).
5. **Battle** — Mantén SSE activo mientras conduces. Acércate a otro piloto con SSE activo para pairing → arming → active.

**Tras actualizar ac-data en el VPS:** `./start.sh dev` (o prod) y **re-entrar al server** para que Convex reciba `player_join` con el slug correcto (`server-4`, no solo "Battle").

### Eventos SSE

| Evento | Uso |
|--------|-----|
| `hud_session` | Perfil, tier, rivals (time attack) |
| `hud_version` | Versiones de leaderboard |
| `battle` | Snapshot de batalla |
| `hud_error` | Errores (`player_not_connected`, etc.) |

### Smoke test (fuera del juego)

```bash
./scripts/verify-battle-hud.sh YOUR_STEAM_ID
```

Debe mostrar eventos SSE en ~15 s.

Verificar perfil completo (requiere estar **dentro** del server online):

```bash
./scripts/verify-convex-hud-session.sh YOUR_STEAM_ID
```

Debe imprimir `OK: hud_session received` con rank/elo/tier.

Debug consola in-game (sin overlay):

```lua
ac.storage("ProjectD-HUD:battle_debug", true):set()
```

Logs en consola CSP: `sse evt=hud_session`, `sse evt=hud_error`, etc.

Mocks offline: `ac.storage("ProjectD-HUD:use_api", false):set()`

Docs: `ProjectD/docs/08-hud-api.md`, `ProjectD/docs/ac-data-hud-spec.md`

## Module map (`common/`)

| Domain | Layout | Draw | Other |
|--------|--------|------|-------|
| **Competition** | `common/layout/competition.lua` | `common/draw/competition/*` | `common/competition/anim.lua` |
| **Profile** | `common/layout/profile.lua` | `common/draw/profile.lua` | `common/profile/display.lua` |
| **Battle** | `common/layout/battle.lua` | `common/draw/battle/*` | `common/api/battle/*` |
| **Shared** | `common/layout/shared.lua` | `common/draw/shared.lua` | `theme`, `data`, `images`, `config` |

Legacy shims (`common/draw.lua`, `common/layout.lua`, etc.) re-export the assembled modules so existing `require("common.draw")` calls keep working.

Verify structure (Git Bash): `./scripts/verify-requires.sh` and `./scripts/verify-competition-flip.sh`
