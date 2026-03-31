# Termux Workstation — TerWorks v1.0.0

> Mini Estación de Trabajo de Bolsillo para Desarrollo Full-Stack

Script automatizado que transforma [Termux](https://termux.dev) en un entorno de desarrollo profesional completo, con stack PHP/Laravel + JavaScript/React + PostgreSQL + Nginx, editor Neovim con IDE features, shell personalizada y 16 temas de terminal.

---

## Tabla de Contenido

- [Requisitos Mínimos](#requisitos-mínimos)
- [Instalación](#instalación)
- [¿Qué instala?](#qué-instala)
- [Fases del Script](#fases-del-script)
- [Aliases y Comandos Rápidos](#aliases-y-comandos-rápidos)
- [Gestión de Servicios](#gestión-de-servicios)
- [Temas de Terminal](#temas-de-terminal)
- [Editor (Neovim + LazyVim)](#editor-neovim--lazyvim)
- [Pasos Post-Instalación](#pasos-post-instalación)
- [Idempotencia](#idempotencia)
- [Log y Depuración](#log-y-depuración)
- [Estructura de Archivos](#estructura-de-archivos)
- [Personalización](#personalización)
- [Preguntas Frecuentes](#preguntas-frecuentes)

---

## Requisitos Mínimos

### Hardware

| Recurso | Mínimo | Recomendado |
|---|---|---|
| **RAM** | 2 GB | 4 GB o más |
| **Almacenamiento libre** | 2 GB | 4 GB (espacio para proyectos) |
| **Procesador** | ARMv7 (32-bit) | ARM64 (64-bit) |

### Software

| Requisito | Versión Mínima | Notas |
|---|---|---|
| **Android** | 7.0 (Nougat) | Versiones anteriores no soportan Termux moderno |
| **Termux** | 0.118+ | **Debe instalarse desde [F-Droid](https://f-droid.org/packages/com.termux/)** o [GitHub Releases](https://github.com/termux/termux-app/releases). La versión de Google Play Store está **descontinuada** y no funcionará |
| **Termux:API** *(opcional)* | Última disponible | App companion para portapapeles, wake-lock y funciones Android. Instalar desde la **misma fuente** que Termux (F-Droid o GitHub) |

### Conectividad

| Requisito | Detalle |
|---|---|
| **Conexión a internet** | Obligatoria durante la ejecución del script (descarga ~500 MB en paquetes, repos Git, LSPs y fuentes) |
| **Tipo de conexión** | WiFi recomendado. Datos móviles funcionan pero el proceso será más lento y consumirá datos |

### Permisos Android

| Permiso | Motivo |
|---|---|
| **Almacenamiento** | Acceso a carpetas compartidas de Android (Descargas, DCIM, etc.) via `~/storage`. El script lo solicita automáticamente |

### Importante

- **No requiere root.** Todo opera dentro del sandbox de Termux.
- **No funciona con la versión de Play Store.** Termux de Play Store dejó de recibir actualizaciones en 2020 y los repositorios de paquetes ya no son compatibles.
- **Termux y Termux:API deben venir de la misma fuente.** Si instalas Termux desde F-Droid, instala Termux:API también desde F-Droid. Mezclar fuentes causa errores de firma.

---

## Instalación

### Opción 1: Una línea (descarga y ejecuta)

```bash
curl -fsSL https://raw.githubusercontent.com/DeartDev/termux_stack/main/termux-workstation.sh -o termux-workstation.sh && bash termux-workstation.sh
```

### Opción 2: Clonar el repositorio

```bash
git clone https://github.com/DeartDev/termux_stack.git
cd termux_stack
bash termux-workstation.sh
```

### Opción 3: Copiar manualmente

1. Copia el archivo `termux-workstation.sh` al almacenamiento del dispositivo.
2. En Termux:
```bash
cp ~/storage/downloads/termux-workstation.sh ~
bash ~/termux-workstation.sh
```

> **Nota:** El script es interactivo. Pedirá confirmación en ciertos pasos (permisos, selección de mirrors, credenciales de PostgreSQL, identidad Git).

---

## ¿Qué instala?

### Paquetes del Sistema (27 paquetes via `pkg`)

| Categoría | Paquetes |
|---|---|
| **Sistema y Red** | `git` `curl` `wget` `openssh` `coreutils` `htop` `termux-api` `termux-services` |
| **Navegación y Búsqueda** | `fzf` `ripgrep` `fd` `zoxide` `eza` `ncdu` `lf` |
| **Visualización y Edición** | `bat` `glow` `fastfetch` `neovim` `jq` `unzip` `zip` |
| **Lenguajes y Runtimes** | `python` `nodejs-lts` `php` |
| **Servicios** | `postgresql` `nginx` |
| **Shell y Multiplexor** | `zsh` `tmux` |

### Herramientas Adicionales

| Herramienta | Origen | Propósito |
|---|---|---|
| `lazygit` | pkg | Interfaz visual de Git en terminal |
| `tree-sitter-cli` | npm | Parser incremental para syntax highlighting de Neovim |
| `Composer` | curl (PHAR) | Gestor de dependencias de PHP (Laravel) |

### Language Servers (7 LSPs via npm)

| LSP | Lenguajes |
|---|---|
| `typescript-language-server` + `typescript` | JavaScript, TypeScript, JSX, TSX |
| `tailwindcss-language-server` | Clases Tailwind CSS |
| `vscode-langservers-extracted` | HTML, CSS, JSON, ESLint (4 en 1) |
| `intelephense` | PHP |
| `sql-language-server` | SQL / PostgreSQL |
| `bash-language-server` | Bash / Shell scripts |

### Shell y Personalización

| Componente | Descripción |
|---|---|
| **Zsh** | Shell por defecto (reemplaza Bash) |
| **Oh My Zsh** | Framework de plugins y configuración |
| **Powerlevel10k** | Tema de prompt con info contextual (Git, Node, PHP) |
| **zsh-autosuggestions** | Sugerencias de comandos basadas en historial |
| **zsh-syntax-highlighting** | Coloreo de sintaxis en tiempo real |
| **MesloLGS NF** | Nerd Font con iconos para P10K, eza y LazyVim |
| **16 temas de terminal** | Pares dark/light con aliases rápidos |

---

## Fases del Script

El script se ejecuta en **12 fases secuenciales** (0–11). Cada fase es idempotente: puede re-ejecutarse sin efectos duplicados.

| Fase | Nombre | Qué Hace |
|---|---|---|
| **0** | Configuración Global | Modo estricto (`set -euo pipefail`), trap de errores, log, funciones auxiliares (`ensure_pkg`, `command_exists`, `print_info`, etc.) |
| **1** | Inicialización | Permiso de almacenamiento, selección de mirrors (`termux-change-repo`), `pkg update/upgrade`, verificación de Termux:API |
| **2** | Paquetes Core | 27 paquetes via `pkg` + lazygit + tree-sitter + Composer |
| **3** | Identidad Git + SSH | Configuración interactiva de `user.name`/`user.email` y generación de llave SSH Ed25519 |
| **4** | PostgreSQL | `initdb`, crear usuario/contraseña (interactivo), crear base de datos, registrar servicio |
| **5** | Nginx | Configurar `nginx.conf` (puerto 8080, root `~/www`), crear página de prueba, registrar servicio |
| **6** | Zsh + Oh My Zsh + P10K | Cambiar shell a Zsh, instalar OMZ + plugins + tema Powerlevel10k |
| **7** | Aliases | Inyectar ~50 aliases en `.zshrc` usando patrón de marcadores (idempotente) |
| **8** | Neovim + LazyVim | Clonar LazyVim starter, inyectar extras (PHP, TS, Tailwind, Prettier) |
| **9** | Language Servers | Pre-instalar 7 LSPs globalmente via npm |
| **10** | Temas de Terminal | Clonar e instalar 16 temas de color (DeartDev/termux_themes) |
| **11** | Nerd Font + Resumen | Instalar MesloLGS NF, mostrar resumen con credenciales y aliases clave |

### Tiempo Estimado

| Conexión | Tiempo Aproximado |
|---|---|
| WiFi rápido (50+ Mbps) | 10–15 minutos |
| WiFi normal (10 Mbps) | 15–25 minutos |
| Datos móviles (4G) | 20–35 minutos |

> El tiempo varía según la velocidad de descarga y el procesador del dispositivo.

---

## Aliases y Comandos Rápidos

Todos los aliases se inyectan en `~/.zshrc` dentro del bloque `# --- TERMUX-WS START/END ---`.

### Navegación

| Alias | Comando Real | Descripción |
|---|---|---|
| `cd <dir>` | `z <dir>` | Navegación inteligente (aprende de tu uso) |
| `..` | `cd ..` | Subir un nivel |
| `...` | `cd ../..` | Subir dos niveles |
| `home` | `cd ~` | Ir al directorio home |
| `www` | `cd ~/www` | Ir a la carpeta de proyectos web |
| `cls` | `clear` | Limpiar pantalla |

### Listado de Archivos (eza)

| Alias | Comando Real | Descripción |
|---|---|---|
| `ls` | `eza --icons` | Listado con iconos |
| `ll` | `eza -lh --icons --git` | Listado detallado con info Git |
| `la` | `eza -lah --icons --git` | Listado detallado incluyendo ocultos |
| `tree` | `eza --tree --icons --level=3` | Árbol de directorios (3 niveles) |

### Visualización

| Alias | Comando Real | Descripción |
|---|---|---|
| `cat` | `bat --paging=never` | Visor con syntax highlighting |
| `catp` | `bat` | Visor con paginación |

### Editor (Neovim)

| Alias | Comando Real | Descripción |
|---|---|---|
| `v` | `nvim` | Abrir Neovim |
| `vi` / `vim` | `nvim` | Redirigir a Neovim |
| `nv` | `nvim .` | Abrir directorio actual en Neovim |

### Git

| Alias | Comando Real | Descripción |
|---|---|---|
| `gs` | `git status` | Estado del repo |
| `ga` | `git add .` | Agregar todos los cambios |
| `gc` | `git commit -m` | Commit con mensaje |
| `gp` | `git push` | Push al remoto |
| `gl` | `git pull` | Pull del remoto |
| `gcl` | `git clone` | Clonar repositorio |
| `glog` | `git log --oneline --graph...` | Log visual de últimos 20 commits |
| `lg` | `lazygit` | Interfaz visual de Git |

### PHP / Laravel

| Alias | Comando Real | Descripción |
|---|---|---|
| `artisan` | `php artisan` | CLI de Laravel |
| `serve` | `php artisan serve --host=0.0.0.0` | Servidor de desarrollo (accesible en LAN) |
| `tinker` | `php artisan tinker` | REPL interactivo de Laravel |
| `migrate` | `php artisan migrate` | Ejecutar migraciones |
| `comp-install` | `composer install` | Instalar dependencias PHP |
| `comp-update` | `composer update` | Actualizar dependencias PHP |

### Node / JavaScript

| Alias | Comando Real | Descripción |
|---|---|---|
| `npmi` | `npm install` | Instalar dependencias |
| `npms` | `npm start` | Iniciar proyecto |
| `npmd` | `npm run dev` | Modo desarrollo |
| `npmb` | `npm run build` | Build de producción |
| `npmt` | `npm test` | Ejecutar tests |

### Búsqueda

| Alias | Comando Real | Descripción |
|---|---|---|
| `ff` | `fzf` | Buscador fuzzy interactivo |
| `grep` | `rg` | Búsqueda en contenido (ripgrep) |
| `find` | `fd` | Búsqueda de archivos por nombre |

### Integración con Android

| Alias | Comando Real | Descripción |
|---|---|---|
| `copy` | `termux-clipboard-set` | Copiar al portapapeles de Android |
| `paste` | `termux-clipboard-get` | Pegar desde el portapapeles |
| `lock-on` | `termux-wake-lock` | Evitar suspensión (procesos largos) |
| `lock-off` | `termux-wake-unlock` | Permitir suspensión |
| `share` | `termux-share` | Compartir archivo via Android |
| `open` | `termux-open` | Abrir archivo con app de Android |

### Productividad

| Alias | Comando Real | Descripción |
|---|---|---|
| `reload` | `source ~/.zshrc` | Recargar configuración de shell |
| `update` | `pkg update -y && pkg upgrade -y` | Actualizar todo el sistema |
| `cleanup` | `pkg clean && npm cache clean...` | Limpiar caches (pkg, npm, composer) |
| `fetch` | `fastfetch` | Info del sistema |
| `myip` | `ifconfig \| grep inet...` | Mostrar IP local |
| `disk` | `ncdu` | Análisis de uso de disco |
| `ports` | `netstat -tulnp` | Puertos en uso |
| `path` | `echo $PATH \| tr ":" "\n"` | Mostrar PATH formateado |

### Flujo de Desarrollo Rápido

| Alias | Comando Real | Descripción |
|---|---|---|
| `dev` | `cd ~/www && nvim .` | Abrir directorio de proyectos en Neovim |
| `serve-all` | `sv up postgresql && sv up nginx` | Iniciar todos los servicios |
| `stop-all` | `sv down postgresql && sv down nginx` | Detener todos los servicios |

---

## Gestión de Servicios

El script registra PostgreSQL y Nginx como servicios gestionados. Ambos métodos de control están disponibles via aliases:

### PostgreSQL

| Método | Iniciar | Detener | Reiniciar | Estado |
|---|---|---|---|---|
| **termux-services** (recomendado) | `pg-start` | `pg-stop` | `pg-restart` | `pg-status` |
| **pg_ctl** (directo) | `pg-ctl-start` | `pg-ctl-stop` | — | — |

```bash
# Conectar al cliente psql
pg-connect
# Equivale a: psql -U txadmin -d txadmin
```

### Nginx

| Método | Iniciar | Detener | Reiniciar/Reload |
|---|---|---|---|
| **termux-services** (recomendado) | `ng-start` | `ng-stop` | `ng-restart` |
| **directo** | `web-start` | `web-stop` | `web-reload` |

```bash
# Verificar que funciona
ng-start
# Abrir en navegador: http://localhost:8080
```

### Cuándo usar cada método

- **termux-services** (`pg-start`, `ng-start`): Uso diario. Gestión centralizada, logs integrados.
- **Directo** (`pg-ctl-start`, `web-start`): Debugging, cuando `termux-services` no está corriendo, o necesitas flags específicos.

---

## Temas de Terminal

16 temas de color organizados en 8 pares dark/light.

### Comandos

```bash
theme list         # Ver todos los temas (marca el activo con ▶)
theme <nombre>     # Aplicar un tema
theme current      # Ver el tema activo
```

### Aliases rápidos

| Alias | Tema | Estilo |
|---|---|---|
| `tdark` / `tlight` | Zinc | Contraste neto con ámbar |
| `tocean` / `tsky` | Ocean/Sky | Abismo oceánico / cielo diurno |
| `tmocha` / `tlatte` | Catppuccin | Oscuro cálido / claro crema |
| `tforest` / `tmeadow` | Forest/Meadow | Bosque nocturno / pradera |
| `thati` / `tskoll` | Nórdico | Luna (Hati) / Sol (Sköll) |
| `tpokedark` / `tpokelight` | Pokémon | Marca oscuro / claro |
| `tcharizard` / `tshiny` | Charizard | Normal / Shiny |
| `tmega_x` / `tmega_y` | Mega Charizard | X (azul) / Y (solar) |

### Ejemplo

```bash
# Cambiar al tema oceánico
theme ocean

# Volver al tema oscuro por defecto
tdark
```

---

## Editor (Neovim + LazyVim)

El script instala LazyVim, una distribución de Neovim que funciona como IDE con:

- **Autocompletado** inteligente via LSPs (PHP, JS/TS, CSS, HTML, SQL, Bash)
- **Navegación** de archivos (neo-tree, Telescope)
- **Git** integrado (gitsigns, diff view)
- **Formateo** automático al guardar (Prettier)
- **Syntax highlighting** avanzado (Treesitter)
- **Soporte Tailwind CSS** con preview de colores

### Extras habilitados

| Extra | Qué aporta |
|---|---|
| `lang.php` | intelephense, blade templates |
| `lang.typescript` | ts_ls, JSX/TSX |
| `lang.json` | schemastore, validación |
| `lang.tailwind` | Autocompletado de clases |
| `formatting.prettier` | Formateo al guardar |
| `util.mini-hipatterns` | Preview de colores hex/rgb inline |

### Primer Uso

```bash
# Abrir Neovim (la primera vez descarga plugins automáticamente)
v

# Espera a que termine la instalación de plugins (~2-5 minutos)
# Luego cierra y vuelve a abrir para que todo cargue limpio
```

### Atajos esenciales de LazyVim

| Atajo | Acción |
|---|---|
| `Space` | Menú principal (leader key) |
| `Space f f` | Buscar archivo (Telescope) |
| `Space f g` | Buscar texto en archivos (grep) |
| `Space e` | Explorador de archivos (neo-tree) |
| `g d` | Ir a la definición |
| `K` | Ver documentación hover |
| `Space c a` | Code actions |
| `Space c f` | Formatear archivo |

---

## Pasos Post-Instalación

### 1. Reiniciar Termux

```
Cierra Termux completamente (fuerza detención desde Android) y vuelve a abrirlo.
Esto aplica Zsh como shell por defecto.
```

### 2. Configurar Powerlevel10k

```
Al abrir Termux por primera vez después del reinicio, P10K iniciará
su asistente de configuración automáticamente.
Sigue las instrucciones en pantalla para elegir el estilo del prompt.

Si necesitas reconfigurarlo después:
$ p10k configure
```

### 3. Inicializar LazyVim

```bash
# Abrir Neovim — los plugins se instalan solos
nvim
# Esperar a que termine y luego cerrar (:q)
# Abrir de nuevo para uso normal
nvim
```

### 4. Agregar clave SSH a GitHub/GitLab

```bash
# La clave pública se generó durante la instalación
cat ~/.ssh/id_ed25519.pub
# Copiar y pegar en: GitHub → Settings → SSH Keys → New SSH Key
```

### 5. Probar los servicios

```bash
# Iniciar PostgreSQL y Nginx
serve-all

# Verificar Nginx (abrir en navegador)
# http://localhost:8080

# Conectar a PostgreSQL
pg-connect

# Detener todo al terminar
stop-all
```

### 6. Elegir un tema

```bash
# Ver los temas disponibles
theme list

# Aplicar el que más te guste
theme ocean
```

---

## Idempotencia

El script puede re-ejecutarse múltiples veces de forma segura:

| Componente | Estrategia |
|---|---|
| **Paquetes** | `dpkg -s` verifica si existe antes de instalar |
| **Directorios** | `[ ! -d ... ]` antes de `mkdir` o `git clone` |
| **Aliases en .zshrc** | Bloque `# --- TERMUX-WS START/END ---` se elimina y reescribe completo |
| **PostgreSQL** | Solo ejecuta `initdb` si el directorio de datos está vacío |
| **Nginx** | Solo reescribe config si no contiene la ruta correcta |
| **Oh My Zsh / Plugins / P10K** | Solo clona si el directorio no existe |
| **LazyVim** | Solo clona si `~/.config/nvim` no existe |
| **Temas** | Solo clona el repo si los archivos `.properties` no están |
| **Nerd Font** | Solo descarga si `~/.termux/font.ttf` no existe |
| **LSPs (npm)** | `npm install -g` no reinstala versiones ya presentes |
| **Git identity** | Solo pregunta si `user.name` no está configurado |
| **SSH key** | Solo genera si `~/.ssh/id_ed25519` no existe |

---

## Log y Depuración

Toda la salida del script se guarda automáticamente en:

```
~/.termux-ws-setup.log
```

```bash
# Ver el log completo
cat ~/.termux-ws-setup.log

# Buscar errores en el log
grep -i "error\|fatal\|fail" ~/.termux-ws-setup.log
```

Si el script falla, mostrará el número de línea exacto del error gracias al `trap ERR`.

---

## Estructura de Archivos

Después de la instalación, estos son los archivos y directorios creados o modificados:

```
$HOME/
├── .zshrc                          # Configuración de Zsh (tema, plugins, aliases)
├── .termux-ws-setup.log            # Log de todas las ejecuciones del script
├── .ssh/
│   ├── id_ed25519                  # Llave privada SSH
│   └── id_ed25519.pub              # Llave pública SSH
├── .termux/
│   ├── font.ttf                    # Nerd Font (MesloLGS NF)
│   ├── theme.sh                    # Función theme() y aliases de temas
│   ├── colors.properties           # Tema activo (gestionado por theme())
│   ├── current_theme               # Nombre del tema activo
│   └── themes/                     # 16 archivos .properties (temas)
├── .config/
│   └── nvim/                       # Configuración de LazyVim
│       └── lua/plugins/
│           └── extras.lua          # Extras del stack (PHP, TS, Tailwind...)
├── .oh-my-zsh/
│   └── custom/
│       ├── plugins/
│       │   ├── zsh-autosuggestions/
│       │   └── zsh-syntax-highlighting/
│       └── themes/
│           └── powerlevel10k/
└── www/                            # Directorio de proyectos web (root de Nginx)
    └── index.html                  # Página de prueba

$PREFIX/
├── bin/
│   └── composer                    # Composer PHP (global)
├── etc/
│   └── nginx/
│       └── nginx.conf              # Configuración personalizada de Nginx
└── var/
    └── lib/
        └── postgresql/             # Datos de PostgreSQL (cluster)
```

---

## Personalización

### Agregar aliases propios

Agrega tus aliases personalizados **después** del bloque gestionado:

```bash
# En ~/.zshrc, buscar esta línea:
# --- TERMUX-WS END ---

# Agregar tus aliases DEBAJO:
alias mi-proyecto="cd ~/www/mi-app && nvim ."
alias deploy="npm run build && rsync -avz dist/ server:/var/www/"
```

> Los aliases dentro del bloque `TERMUX-WS START/END` se sobreescriben al re-ejecutar el script. Los que estén fuera se preservan.

### Agregar un tema de terminal personalizado

1. Crear archivo `~/.termux/themes/mi-tema.properties` con el formato estándar:
```properties
background=#1a1b26
foreground=#c0caf5
cursor=#f7768e
color0=#15161e
# ... color1 hasta color15
```

2. Editar `~/.termux/theme.sh` para agregar el nombre al `case` y un alias.

3. Aplicar: `theme mi-tema`

### Modificar configuración de Nginx

```bash
# Editar configuración
v $PREFIX/etc/nginx/nginx.conf

# Recargar sin reiniciar
web-reload
```

### Agregar extras de LazyVim

```bash
# Editar el archivo de extras
v ~/.config/nvim/lua/plugins/extras.lua

# Agregar imports, por ejemplo:
# { import = "lazyvim.plugins.extras.lang.python" },
# { import = "lazyvim.plugins.extras.lang.rust" },
```

---

## Preguntas Frecuentes

### ¿Puedo ejecutar el script más de una vez?

Sí. El script es completamente idempotente. La segunda ejecución salta todo lo que ya está instalado y solo reescribe los aliases (de forma limpia, sin duplicar).

### ¿Funciona sin root?

Sí. Todo opera dentro del sandbox de Termux. No se necesita root ni un dispositivo rooteado.

### ¿Puedo usarlo con la versión de Play Store de Termux?

No. La versión de Play Store está descontinuada desde 2020. Usa la versión de [F-Droid](https://f-droid.org/packages/com.termux/) o [GitHub Releases](https://github.com/termux/termux-app/releases).

### ¿Los servicios (PostgreSQL, Nginx) se inician automáticamente?

No. Se registran pero no se inician al boot. Debes iniciarlos manualmente con `serve-all` o `pg-start` / `ng-start`. Esto es intencional para ahorrar batería.

### ¿Cuánto espacio ocupa la instalación completa?

Aproximadamente 1.5–2 GB incluyendo todos los paquetes, LSPs, plugins de Neovim y Oh My Zsh.

### ¿Cómo desinstalo todo?

```bash
# Eliminar configuraciones
rm -rf ~/.oh-my-zsh ~/.config/nvim ~/.termux/themes ~/.termux/theme.sh
rm -f ~/.termux/font.ttf ~/.termux-ws-setup.log

# Eliminar el bloque de aliases
sed -i '/# --- TERMUX-WS START ---/,/# --- TERMUX-WS END ---/d' ~/.zshrc

# Cambiar shell a bash
chsh -s bash

# Desinstalar paquetes (opcional, eliminará TODOS los paquetes listados)
pkg uninstall neovim lazygit zsh postgresql nginx php nodejs-lts python
```

### ¿Cómo actualizo los temas?

```bash
# Re-clonar e instalar desde el repo
git clone --depth=1 https://github.com/DeartDev/termux_themes.git /tmp/themes
bash /tmp/themes/install.sh
rm -rf /tmp/themes
```

### ¿Puedo acceder al servidor web desde otro dispositivo en la red?

Sí. Busca tu IP local con `myip` y accede desde otro dispositivo en la misma red WiFi: `http://<tu-ip>:8080`.

Para Laravel: `serve` ya usa `--host=0.0.0.0`, así que es accesible en `http://<tu-ip>:8000`.

---

## Licencia

MIT

---

<p align="center">
  <strong>TerWorks</strong> — Tu workstation cabe en un bolsillo.
</p>
