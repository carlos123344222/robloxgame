# Roblox Game

Proyecto Roblox con versionado de código usando **Rojo**.

## Estructura del Proyecto

```
src/
├── shared/          # Scripts compartidos (ReplicatedStorage)
├── server/          # Scripts del servidor (ServerScriptService)
└── client/          # Scripts del cliente
    ├── gui/         # GUI (StarterGui)
    ├── character/   # Scripts de personaje
    └── player/      # Scripts del jugador
```

## Requisitos

- [Rojo](https://github.com/rojo-rbx/rojo) instalado
- Roblox Studio abierto

## Setup Inicial

### 1. Instalar Rojo

```bash
# Con cargo (Rust)
cargo install rojo

# O descargar binario desde: https://github.com/rojo-rbx/rojo/releases
```

### 2. Conectar a Roblox Studio

```bash
# En la raíz del proyecto
rojo serve
```

Verás un output como:
```
🔌 Rojo server listening on port 34872
```

### 3. Conectar en Roblox Studio

1. Abre Roblox Studio
2. Ve a **Plugins** → **Rojo** (o busca el plugin de Rojo si no lo tienes)
3. Ingresa `localhost:34872` (o el puerto mostrado)
4. Haz clic en **Connect**

Ahora cualquier cambio que hagas en el código se sincronizará automáticamente.

## Estructura de Carpetas

### `src/shared/`
Scripts y módulos compartidos entre cliente y servidor.

### `src/server/`
Scripts del servidor (ServerScriptService).

### `src/client/`
- **gui/**: Interfaces gráficas (StarterGui)
- **character/**: Scripts que corren en el personaje
- **player/**: Scripts del jugador local

## Flujo de Trabajo

1. **Editar código** en la carpeta `src/`
2. **Guardar cambivos** (Ctrl+S)
3. **Rojo sincroniza** automáticamente a Roblox Studio
4. **Hacer commit** a GitHub

```bash
git add .
git commit -m "feat: agregar nuevo sistema"
git push origin branch-name
```

## Comandos Útiles

```bash
# Sincronizar en modo dev
rojo serve

# Generar archivo .rbxm (model file)
rojo build src -o model.rbxm

# Generar archivo .rbxl (place file)
rojo build -o game.rbxl
```

## Notas

- Los cambios en Rojo se sincronizan **del proyecto al archivo**, no al revés
- Siempre edita en el editor de código, no en Studio
- Confirma cambios regularmente en Git

## Documentación

- [Rojo Docs](https://rojo.space/)
- [Roblox API](https://developer.roblox.com/en-us/api-reference)
