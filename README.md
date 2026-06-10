# ProjectD HUD (template)

Tres widgets CSP Lua con **datos falsos** ? sin API por ahora. **No depende de CMRT** ni de otras apps Lua.

| Widget | Descripción |
|--------|-------------|
| **ProjectD Top 10** | Ranking del servidor (clave futura: server + track + layout + car) |
| **ProjectD Profile** | Tu perfil: foto, nombre, tier, coche, mejor tiempo |
| **ProjectD Rival** | Piloto #rank-1: etiqueta "rival", misma info |

## Instalación

Copia la carpeta completa `ProjectD-HUD` a:

```
assettocorsa/apps/lua/ProjectD-HUD/
```

Requiere CSP 0.1.76+. Activa las 3 apps en el menú de AC.

## Assets incluidos (standalone)

Todo debe vivir dentro de `ProjectD-HUD/`. Al instalar en otro PC, copia esta carpeta entera con `assets/`:

| Archivo | Uso |
|---------|-----|
| `assets/panel_card.png` | Fondo Profile / Rival |
| `assets/leaderboard_panel.png` | Fondo Top 10 |
| `assets/logo.png` | Cabecera del leaderboard |
| `assets/tiers/tier0.png` ? `tier10.png` | Iconos de tier |
| `icon.png` | Icono de la app en el menú CSP |

### Opcionales (solo si existen en `assets/`)

| Archivo | Widget |
|---------|--------|
| `panel_overlay.png` o `panel_gradient.png` | Profile, Rival |
| `leaderboard_overlay.png` o `leaderboard_gradient.png` | Top 10 |

Sin overlay, solo se muestra el panel base.

## Avatares por URL

Los mocks usan URLs de imagen; el HUD las descarga con `web.get` + `ui.decodeImage`.
Hace falta conexión a internet la primera vez.

## Cambiar datos de prueba

Edita `common/mock_data.lua`:

- `MOCK_CONTEXT` ? servidor, pista, layout, coche, Steam ID
- `LEADERBOARDS` ? top 10 por clave `server@track@layout@car`
- `PROFILES` ? perfil por Steam ID

## Próximo paso (API)

Sustituir `mock_data.lua` por llamadas a ProjectD:

- Top 10: `GET /leaderboards/{trackId}/{carId}` + server id
- Perfil: `GET /drivers/{steamId}/profile`
- Rival: entrada con `rank - 1` del leaderboard
