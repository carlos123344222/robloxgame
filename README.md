# World Chase Tag

Juego de persecución (tag) para Roblox con combate contra jugadores y NPCs. Esta primera fase es el
**sistema de movimiento** de personajes y NPCs; el combate y las reglas del juego se montan encima.

El proyecto se sincroniza con Roblox Studio mediante [Rojo](https://rojo.space/) (7.7).

## Cómo probarlo

1. En tu PC, dentro de la carpeta del proyecto: `git pull origin claude/exciting-wright-nkr2of`
2. `rojo serve`
3. En Studio: Plugins → Rojo → **Connect**.
4. Pulsa **Play**. El servidor crea solo un circuito de pruebas (`Workspace.DevArena`) y 4 NPCs
   (2 perseguidores rojos y 2 corredores azules).

El código se edita aquí (o en tu editor) y Rojo lo sincroniza; lo que hagas en Studio a mano en los scripts
se pierde al reconectar.

## Controles

| Acción | Teclado | Mando |
| --- | --- | --- |
| Mover | WASD | Stick izquierdo |
| Saltar (pulsa otra vez en el aire = doble salto) | Espacio | A |
| Sprint | Mayús izquierdo (mantener) | L3 |
| Dash | Q | X |
| Deslizarse / rodar | C o Ctrl izquierdo | B |
| Ocultar el panel de depuración | F3 | |

En móvil hay botones de DASH y SLIDE en pantalla; el sprint es automático al empujar el stick al máximo.

## Qué incluye el movimiento

* **Suelo**: aceleración progresiva, giros en arco a velocidad, derrape al invertir la dirección, parada con
  un pequeño deslizamiento.
* **Salto**: altura variable (suelta para saltar menos), *coyote time*, salto en buffer, gravedad más pesada al
  caer, *chain hop* (saltar justo al aterrizar mantiene y aumenta la velocidad).
* **Dash**: 2 cargas que se recargan, i-frames, también en el aire (uno por salto); se puede cancelar en salto o
  deslizamiento.
* **Slide**: arranca desde el sprint, gana velocidad cuesta abajo, se puede dirigir y cancelar en un salto
  potenciado.
* **Wall run y wall jump**: correr por una pared, patada para saltar de una a otra.
* **Trepar / vault**: agarra automáticamente bordes de 3.3 a 7.4 studs; desde el suelo se sube saltando.
* **Rodar al aterrizar**: pulsa deslizar justo antes de caer y el impacto se convierte en velocidad; sin rodar,
  las caídas grandes te frenan.
* **Flow**: encadenar movimientos sube un pequeño bonus de velocidad y de recarga del dash; se pierde si paras.
* **Poses procedurales** para todos los personajes (inclinación al correr y al girar, reclinado en el slide,
  volteretas): no necesitan animaciones ni red.
* **Cámara**: el campo de visión se abre con la velocidad, se inclina en el wall run y "cae" al aterrizar.

### NPCs

Usan **exactamente el mismo sistema de movimiento** que los jugadores (sprint, dash, slide, saltos, trepar).

* `Navigator` sigue rutas de Roblox con *look-ahead* (corta esquinas si el camino es transitable), va en línea
  recta cuando no hay obstáculos, frena en curvas cerradas, salta donde la ruta lo pide, esquiva paredes y se
  reencamina si se atasca o el objetivo se mueve.
* **Chaser** intercepta al objetivo (predice su posición), hace dash y slide al acercarse y "toca" al llegar:
  empuja al jugador y lo aturde. El dash da i-frames y esquiva el toque.
* **Runner** huye hacia terreno abierto y hace dash cuando lo acorralan.
* Sin objetivos, deambulan.

## Estructura

```
src/
  shared/                  → ReplicatedStorage.Shared
    Config/MovementConfig  todos los números que definen el "feeling"
    Config/GameConfig      interruptores (arena de pruebas, NPCs, panel F3, anti-trampas)
    Movement/
      Locomotion           cerebro de movimiento (jugadores en el cliente, NPCs en el servidor)
      Sensors              raycasts: suelo, paredes, bordes
      States/              Ground, Air, Dash, Slide, Roll, WallRun, Mantle, Stun
    Util/ Net/ Types       utilidades, remotes y tipos
  server/                  → ServerScriptService.Server
    MovementService        replica el estado, i-frames del dash, detecta speed hacks / teletransportes
    DevArena               circuito de pruebas
    NPC/                   NPCService, NPCBrain, Navigator, NPCAnimator, ...
  client/                  → StarterPlayerScripts.Client
    Controllers/           Input, Movement, Camera, Pose, Effects, DebugHud
tests/sim/                 simulación headless del movimiento y de los NPCs (ver abajo)
```

## Ajustar el feeling

Todo está en `src/shared/Config/MovementConfig.luau`, con comentarios. Lo más útil:

| Quiero… | Toco |
| --- | --- |
| Más/menos velocidad | `RunSpeed`, `SprintSpeed` |
| Arranque más o menos ágil | `GroundAccel`, `SprintAccel`, `StopDecel` |
| Saltos más flotantes o más secos | `FallGravityMult`, `ApexGravityMult`, `JumpVelocity` |
| Dash más largo/corto | `DashSpeed`, `DashDuration` (distancia ≈ velocidad media × duración) |
| Slide más largo | `SlideFriction`, `SlideMaxSpeed` |
| Wall run más largo | `WallRunDuration`, `WallRunGravity` |
| Qué bordes se pueden trepar | `MantleMinHeight`, `MantleMaxHeight` |

Los NPCs se ajustan en `src/server/NPC/NPCConfig.luau` (cuántos, de qué tipo, velocidad relativa, rango de dash).
Si un `Part` no debe permitir wall run o trepar, ponle el atributo `NoWallRun` o `NoMantle` a `true`.

## Comprobaciones de desarrollo

Sin abrir Studio se puede comprobar el código con el verificador de tipos de Luau y con una simulación
headless de la lógica de movimiento y de los NPCs:

```bash
python3 tests/sim/bundle.py && luau tests/sim/run.luau   # ~70 escenarios: salto, dash, slide, wall run, NPCs...
```

La simulación usa una física de juguete, así que valida la lógica (estados, tiempos, distancias) pero no
sustituye a probarlo en Studio.

## Pendiente / siguientes pasos

* Combate (ataques, vida) y las reglas de tag ("quién la lleva", rondas) sobre `NPCService.Tagged`.
* Animaciones propias (ahora los jugadores usan las de Roblox y los NPCs los IDs de animación por defecto de
  Roblox, configurables en `NPCAnimator.luau`).
* Sonido y más efectos.
* Más mecánicas (gancho, habilidades por personaje...).
