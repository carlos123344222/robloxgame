# 🎁 Don't Steal the Present — ¡No robes el regalo!

Juego navideño para Roblox del género "roba y protege": compra regalos que salen de la Fábrica de Santa,
llévalos a tu taller para que generen dinero, **roba los regalos de los demás** y protege los tuyos.

![Miniatura](art/thumbnail_1.png)

Todo el juego está hecho con código (Rojo + Luau): el mapa, los 28 regalos, los talleres, los gears y la
interfaz se construyen con piezas, sin mallas ni imágenes que haya que subir. Por eso funciona nada más
abrirlo.

## Cómo jugarlo ya

**Opción rápida:** abre `DontStealThePresent.rbxl` en Roblox Studio y pulsa **Play**. El mapa ya viene
"horneado" dentro del archivo, así que también lo ves y puedes editarlo sin darle a Play.

**Con Rojo (para seguir programando):**

```bash
cd DontStealThePresent
```

```bash
rojo serve
```

En Studio: Plugins → Rojo → **Connect** y **Play**. Si el lugar está vacío, el servidor construye el mapa
al arrancar (tarda menos de un segundo).

Para probar con varios jugadores: pestaña **Test** → Clients and Servers → 2 o 3 jugadores → Start.

### Antes de publicar

1. **Game Settings → Security → Enable Studio Access to API Services** (para que se guarde el progreso; en
   Studio sin esto se juega igual pero no se guarda nada, y el juego te avisa).
2. **Game Settings → Places → Max Players = 8** (hay 8 talleres; si entra un noveno no tendrá taller).
3. Sube el icono y las miniaturas de la carpeta `art/` (renderizadas con Blender a partir del mapa real).
4. Opcional: pon una canción navideña de la Creator Store en `GameConfig.MusicSoundId`.

## Cómo se juega

| Paso | Qué hacer |
| --- | --- |
| 🎁 Comprar | Los regalos salen de la **Fábrica de Santa** y recorren la cinta de caramelo. Acércate y pulsa **E**. El regalo vuela a tu taller. Los que nadie compra acaban en el **Horno de Carbón**. |
| 💰 Cobrar | Cada regalo genera dinero por segundo. Pisa la **placa verde** que tiene delante para cobrarlo. |
| 😈 Robar | Entra en un taller **abierto**, mantén **E** sobre un regalo y corre a tu taller. Lo llevas sobre la cabeza, vas más lento y una línea de luz te marca el camino. Tienes 75 s. |
| 🔒 Proteger | Pisa el **botón rojo** del fondo de tu taller: un escudo cierra la puerta y el techo durante 60 s (más con cada renacimiento). Cuando se abre, ¡vuelve a pulsarlo! |
| 🍭 Defender | Con el **Bastón Golpeador** (gratis) o los gears haces que el ladrón suelte el regalo, que vuelve a su pedestal. |
| ⭐ Renacer | Con suficiente dinero y un regalo de cierta rareza en tu taller renaces: pierdes dinero y regalos pero ganas **+50 % de ingresos**, **2 huecos más** y **más tiempo de bloqueo**, para siempre. |

Si te roban, salta una **alarma roja** en pantalla con el nombre del ladrón.

### Controles

| Acción | PC | Móvil / mando |
| --- | --- | --- |
| Comprar / robar / vender | **E** (robar: mantener) · vender: **F** | Botón del prompt |
| Usar gear | Clic | Tocar la pantalla |
| Tienda / Renacer / Índice / Ayuda | **G** / **R** / **J** / **H** | Botones de la izquierda |
| Cerrar ventana | Esc | ✖ |

## Contenido

* **8 talleres** de troncos con 16 pedestales, placas de cobro, chimenea, guirnaldas que parpadean, carámbanos y escudo
  ForceField al bloquear (la puerta es sólida solo para los demás).
* **28 regalos** en 7 rarezas, cada uno con su modelo propio: calcetín, bastón de caramelo, casita de jengibre, globo de
  nieve con árbol dentro, tambor cascanueces, caja musical con bailarina que gira, estrella, cofre de hielo, corona,
  trineo, cristal eterno, campana real, farol con fuego, regalo galáctico con planetas, núcleo de la Navidad...
* **5 mutaciones**: Dorado x1.5, Diamante x2, Escarcha x2.5, Caramelo x3 y Arcoíris x5 (cambia de color en vivo).
* **4 eventos** automáticos cada 5–8 minutos: ❄️ Ventisca (escarcha + tormenta de nieve), 🌌 Aurora Boreal (arcoíris +
  aurora en el cielo), 🎅 Noche de Santa (suerte x3 + el trineo de Santa sobrevolando el mapa) y ✨ Lluvia de Oro.
* **5 gears**: 🍭 Bastón Golpeador, ⛄ Bolas de Nieve (congelan 1.4 s), 🦌 Botas de Reno (+45 % velocidad),
  🔔 Campana Saltarina (salto enorme) y 🧊 Rayo Congelador (3 s de hielo).
* **12 renacimientos**, **índice** de regalos con vistas 3D giratorias, **ganancias offline** (20 % hasta 6 h),
  anuncios a todo el servidor cuando sale o se roba algo legendario, leaderstats y guardado con DataStore.
* Mapa: Fábrica de Santa con engranajes que giran, cinta con rayas animadas y arcos de bastón, Horno de Carbón,
  plaza con un árbol de 80 studs y estrella giratoria, Tienda del Elfo, Altar de Renacer, estanque helado (resbala),
  muñecos de nieve, renos, bosque nevado y montañas de Terrain. Noche de Navidad con niebla, bloom y nieve cayendo.
* Interfaz completa: pantalla de bienvenida animada, HUD con dinero animado, avisos, alarma de robo, confeti,
  tienda, renacer, índice y ayuda. Se adapta a móvil.

### Regalos

| Rareza | Regalo | Precio | Genera | Prob. de la rareza |
| --- | --- | ---: | ---: | ---: |
| Común | Calcetín Sorpresa | $25 | $1/s | 56 % |
| Común | Caja de Cartón | $60 | $2/s | 56 % |
| Común | Saco de Carbón | $110 | $4/s | 56 % |
| Común | Bastón de Caramelo | $180 | $6/s | 56 % |
| Común | Regalo Rojo Clásico | $300 | $9/s | 56 % |
| Poco común | Caja Muérdago | $650 | $18/s | 26 % |
| Poco común | Sombrerera de Nieve | $1.1K | $30/s | 26 % |
| Poco común | Torre de Regalos | $1.8K | $46/s | 26 % |
| Poco común | Bola de Árbol Brillante | $2.8K | $70/s | 26 % |
| Raro | Casita de Jengibre | $5.5K | $130/s | 11.5 % |
| Raro | Regalo Escarchado | $9.5K | $215/s | 11.5 % |
| Raro | Globo de Nieve | $16K | $340/s | 11.5 % |
| Raro | Tambor Cascanueces | $26K | $520/s | 11.5 % |
| Épico | Saco de Santa | $55K | $1.05K/s | 4.6 % |
| Épico | Caja Musical Dorada | $95K | $1.75K/s | 4.6 % |
| Épico | Árbol en Miniatura | $160K | $2.7K/s | 4.6 % |
| Épico | Regalo Aurora | $260K | $4.1K/s | 4.6 % |
| Legendario | Estrella de la Punta | $550K | $8.5K/s | 1.5 % |
| Legendario | Cofre del Polo Norte | $950K | $14.5K/s | 1.5 % |
| Legendario | Corona de Navidad | $1.7M | $25.5K/s | 1.5 % |
| Legendario | Trineo de Juguete | $3.1M | $46K/s | 1.5 % |
| Mítico | Cristal de Hielo Eterno | $6.5M | $92K/s | 0.33 % |
| Mítico | Campana de Oro Real | $12.5M | $172K/s | 0.33 % |
| Mítico | Farol Polar | $23M | $305K/s | 0.33 % |
| Mítico | Regalo Galáctico | $42M | $520K/s | 0.33 % |
| SECRETO | El Regalo de Santa | $110M | $1.25M/s | 0.07 % |
| SECRETO | Núcleo de la Navidad | $380M | $4.2M/s | 0.07 % |
| SECRETO | Regalo Infinito | $1.1B | $10.5M/s | 0.07 % |

Los legendarios o mejores salen con un **pilar de luz** y se anuncian a todo el servidor. Durante la Noche de Santa los
secretos son unas 27 veces más probables.

![Regalos](art/presents.png)

## Ajustar el juego

Todo lo importante está en `src/shared/Config/`:

| Archivo | Qué controla |
| --- | --- |
| `GameConfig.luau` | Dinero inicial, velocidad y frecuencia de la cinta, robos (tiempo, lentitud), autoguardado, eventos, música |
| `Presents.luau` | Los 28 regalos: nombre, rareza, precio, ingreso, forma y colores |
| `Rarities.luau` | Probabilidad, colores y tamaño de cada rareza |
| `Mutations.luau` | Multiplicadores y probabilidad de las mutaciones |
| `Gears.luau` | Precio y potencia de cada gear |
| `Rebirths.luau` | Coste y requisitos de cada renacimiento, huecos y tiempo de bloqueo |
| `Events.luau` | Duración y efectos de los eventos |
| `Sounds.luau` | Sonidos (por defecto usa los que trae el cliente de Roblox; cámbialos por `rbxassetid://`) |

Para añadir un regalo nuevo basta con una entrada en `Presents.luau`; la forma puede ser cualquiera de las de
`Shared/PresentBuilder.luau` (Box, TallBox, Cylinder, Stack, Ball, Sock, Cane, Bag, Sack, House, FrostBox, Globe, Drum,
MusicBox, Tree, AuroraBox, Star, Chest, Wreath, Sleigh, Crystal, Bell, Lantern, Galaxy, Royal, Core, Infinite).

### Comandos de prueba

En Studio (o si eres el creador del juego) puedes escribir en el chat:

| Comando | Efecto |
| --- | --- |
| `/dinero 5m` | Añade dinero (acepta k, m, b, t) |
| `/regalo SantasGift Rainbow` | Saca ese regalo ahora en la cinta |
| `/evento SantaNight` | Empieza un evento (Blizzard, Aurora, SantaNight, GoldRain) |
| `/renacer` | Renace sin requisitos |
| `/bloquear` | Bloquea tu taller |
| `/borrar` | Reinicia tus datos |

Se desactivan con `GameConfig.DevCommands = false`.

## Estructura

```
src/
  shared/                     → ReplicatedStorage.Shared
    Config/                   regalos, rarezas, mutaciones, gears, renacimientos, eventos, sonidos
    PresentBuilder            construye los 28 regalos con piezas (servidor y vistas 3D del índice)
    Util/ Net/                formato de números, señales, RNG, ayudas de interfaz, remotes
  server/                     → ServerScriptService.Server
    World/                    MapBuilder, BaseBuilder, Decor, ToolBuilder, terreno, iluminación, carteles
    Services/
      DataService             DataStore, leaderstats, sincronización con el cliente
      BaseService             talleres, pedestales, cobro, bloqueo, venta, ganancias offline
      ConveyorService         la cinta: sorteo de regalos y mutaciones, compras
      StealService            robos, llevar el regalo, entregas y regalos que vuelven
      GearService             tienda y gears (todos los impactos se resuelven en el servidor)
      CharacterService        velocidad y salto según el estado (llevar regalo, congelado, botas...)
      RebirthService, EventService, DevCommands
  client/                     → StarterPlayerScripts.Client
    UI/                       HUD, avisos, tienda, renacer, índice, bienvenida y ayuda
    Controllers/              animación del mundo, bases, gears, efectos, sonido
tools/
  build.sh                    construye el .rbxl y pasa todas las comprobaciones
  lune/                       comprobación de sintaxis, pruebas, horneado del mapa, exportar escenas
  sim/                        emulador de Roblox y partida simulada completa
  blender/render.py           renderiza el mapa y los regalos con Blender (icono y miniaturas)
art/                          icono, miniaturas y renders de los regalos
```

### Decisiones técnicas

* **La cinta se anima en el cliente.** El servidor solo guarda cuándo salió cada regalo y a qué velocidad va; cada cliente
  calcula su posición con la hora del servidor (`GetServerTimeNow`). Movimiento perfectamente suave sin tráfico de red, y
  el servidor valida las compras con la misma fórmula.
* **El escudo de bloqueo es sólido solo para los demás**: cada cliente activa la colisión localmente en las bases ajenas; el
  servidor además expulsa a quien esté dentro.
* **Todo se valida en el servidor**: precio, distancia, huecos libres, bloqueos, cooldowns de los gears y puntería.
* Si el DataStore falla al cargar no se guarda nada en esa sesión, para no sobrescribir datos buenos.

## Comprobaciones sin Studio

```bash
tools/build.sh
```

Construye el lugar con Rojo, compila todos los scripts, pasa Selene, prueba la lógica, construye los 28 regalos con las 6
variantes y hornea el mapa en `DontStealThePresent.rbxl`. Las piezas se crean con la API real de Roblox (Lune valida cada
propiedad), así que un nombre o tipo de propiedad mal escrito falla aquí.

Con el volcado de la API de Roblox (`Full-API-Dump.json` de
[Roblox-Client-Tracker](https://github.com/MaximumADHD/Roblox-Client-Tracker)) se ejecuta además una **partida simulada
completa** con el código real del servidor y del cliente: entran jugadores, compran, cobran, bloquean, roban, se golpean,
entregan, compran gears, renacen, se lanzan los eventos, se abren todos los menús, se sale y se vuelve a entrar. El
emulador valida cada propiedad, método, evento y Enum contra la API oficial (62 comprobaciones).

```bash
API_DUMP=/ruta/Full-API-Dump.json tools/build.sh
```

Las imágenes de `art/` se generan con `tools/lune/export-scene.luau` + `tools/blender/render.py` (Blender como módulo de
Python: `pip install bpy`).

## Ideas para seguir

* Game passes (x2 dinero, VIP) y productos (bloqueo instantáneo, regalo garantizado).
* Más pisos en los talleres a partir de cierto renacimiento.
* Música y efectos de sonido propios subidos a Roblox.
* Animaciones propias para robar y lanzar.
