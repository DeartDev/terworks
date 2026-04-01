#!/usr/bin/env bash

# ==============================================================================
#  TERMUX WORKSTATION - TerWorks v1.0.0
#  Mini Estación de Trabajo de Bolsillo — Full-Stack Development
# ==============================================================================
#  Stack  : PHP / Laravel · JavaScript / React · PostgreSQL · Nginx
#  Shell  : Zsh + Oh My Zsh + Powerlevel10k
#  Editor : Neovim + LazyVim (con LSPs pre-instalados)
# ------------------------------------------------------------------------------
#  Principios de diseño:
#    • Idempotente  — Se puede re-ejecutar sin romper nada ni duplicar configs.
#    • Reproducible — Mismo resultado en cualquier dispositivo con Termux.
#    • Escalable    — Estructura modular por fases, fácil de extender.
#    • Documentado  — Cada bloque explica QUÉ hace y POR QUÉ.
# ------------------------------------------------------------------------------
#  Uso:
#    chmod +x termux-workstation.sh
#    bash termux-workstation.sh
# ==============================================================================

SCRIPT_VERSION="1.0.0"

# ──────────────────────────────────────────────────────────────────────────────
# FASE 0: CONFIGURACIÓN GLOBAL, CONSTANTES Y FUNCIONES AUXILIARES
# ──────────────────────────────────────────────────────────────────────────────
# Esta fase establece las bases del script: manejo estricto de errores,
# constantes de color para la salida formateada, y funciones reutilizables
# que garantizan la idempotencia (no reinstalar lo que ya existe).
# ──────────────────────────────────────────────────────────────────────────────

# --- Modo estricto de Bash ---
# -e: Detener al primer error.  -u: Error si se usa variable no definida.
# -o pipefail: Un fallo en cualquier parte de un pipe se propaga.
set -euo pipefail

# --- Trap de errores ---
# Si el script falla en cualquier línea, muestra un mensaje claro con el
# número de línea donde ocurrió el problema, facilitando la depuración.
trap 'echo -e "\n\033[0;31m[FATAL] Error inesperado en la línea $LINENO. Revisa el log.\033[0m"; exit 1' ERR

# --- Log de ejecución ---
# Todas las salidas del script se registran en un archivo de log con
# timestamp para poder auditar instalaciones pasadas.
LOG_FILE="$HOME/.termux-ws-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo ""
echo "========== Ejecución: $(date '+%Y-%m-%d %H:%M:%S') | v$SCRIPT_VERSION =========="

# --- Constantes de Colores ---
# Códigos ANSI para dar formato visual a los mensajes del script.
# NC (No Color) resetea el formato al valor por defecto del terminal.
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- Funciones de impresión ---
# Cada función prefija el mensaje con un tag de color para identificar
# rápidamente el tipo de mensaje en la terminal.
print_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[  OK]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Función de pausa interactiva ---
# Detiene la ejecución hasta que el usuario presione ENTER.
# Se usa antes de acciones que requieren confirmación visual (permisos, menús).
pause() {
    echo -e "\n${YELLOW}>>> $1 <<<${NC}"
    read -r -p "Presiona ENTER para continuar..."
}

# --- Verificar si un comando existe ---
# Devuelve 0 (éxito) si el comando está disponible en el PATH.
# Se usa para chequeos idempotentes de herramientas instaladas vía npm, curl, etc.
command_exists() {
    command -v "$1" &> /dev/null
}

# --- Verificar si un paquete de Termux está instalado ---
# Consulta la base de datos de dpkg. Si el paquete ya está instalado,
# devuelve 0 sin intentar reinstalarlo. Esto evita llamadas innecesarias a pkg.
pkg_installed() {
    dpkg -s "$1" > /dev/null 2>&1
}

# --- Instalar un paquete solo si no está presente ---
# Función central de idempotencia para paquetes. Verifica antes de instalar.
# Parámetro: nombre del paquete tal como aparece en los repositorios de Termux.
ensure_pkg() {
    if pkg_installed "$1"; then
        print_success "$1 ya está instalado."
    else
        print_info "Instalando: $1..."
        pkg install -y "$1"
    fi
}


# ──────────────────────────────────────────────────────────────────────────────
# FASE 1: INICIALIZACIÓN, PERMISOS Y ACTUALIZACIÓN DEL SISTEMA
# ──────────────────────────────────────────────────────────────────────────────
# Esta fase prepara el entorno base de Termux:
#   1. Muestra el banner de bienvenida.
#   2. Solicita permiso de almacenamiento compartido de Android (solo si falta).
#   3. Permite al usuario seleccionar los repositorios/mirrors más rápidos.
#   4. Actualiza todos los paquetes del sistema a sus últimas versiones.
#   5. Verifica que la app Termux:API esté disponible.
# ──────────────────────────────────────────────────────────────────────────────

clear
echo -e "${CYAN}${BOLD}"
cat << "BANNER"

  ╔════════════════════════════════════════════════════════════╗
  ║        TERMUX WORKSTATION SETUP - TerWorks v1.0.0          ║
  ║        Mini Estación de Trabajo de Bolsillo                ║
  ║        PHP · Laravel · React · PostgreSQL · Nginx          ║
  ╚════════════════════════════════════════════════════════════╝

BANNER
echo -e "${NC}"
print_info "Iniciando configuración — $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# --- Paso 1.1: Acceso al almacenamiento compartido ---
# Termux opera en un sandbox aislado. Para acceder a la carpeta compartida
# de Android (Descargas, DCIM, etc.) necesita un permiso explícito.
# Este permiso crea el directorio ~/storage como punto de montaje.
if [ ! -d "$HOME/storage" ]; then
    print_warning "Se requiere acceso al almacenamiento del dispositivo."
    print_info "Aparecerá una ventana emergente. Por favor, concede el permiso."
    termux-setup-storage
    pause "Concede el permiso de almacenamiento y luego presiona ENTER."

    if [ ! -d "$HOME/storage" ]; then
        print_error "No se otorgaron los permisos de almacenamiento. Abortando..."
        exit 1
    fi
    print_success "Permiso de almacenamiento concedido."
else
    print_success "El acceso al almacenamiento ya está configurado."
fi

# --- Paso 1.2: Selección de repositorios (mirrors) ---
# Los repositorios por defecto pueden ser lentos dependiendo de la región.
# termux-change-repo abre un menú TUI donde el usuario puede elegir
# los mirrors más cercanos geográficamente (recomendado para LATAM).
print_info "Es altamente recomendado elegir el repositorio más rápido para tu región."
pause "Se abrirá el menú de selección de repositorios. Presiona ENTER para continuar..."
termux-change-repo

# --- Paso 1.3: Actualización completa del sistema ---
# Asegura que todos los paquetes base estén en su última versión antes
# de instalar software nuevo, evitando conflictos de dependencias.
print_info "Actualizando repositorios y paquetes base..."
pkg update -y && pkg upgrade -y
print_success "Sistema actualizado."

# --- Paso 1.4: Verificación de Termux:API ---
# Termux:API es una app companion de Android que expone funciones nativas
# (portapapeles, vibración, sensores, notificaciones) a la línea de comandos.
# No es un paquete de Termux sino una app separada que debe instalarse desde
# F-Droid o la misma fuente que Termux. Aquí solo advertimos si falta.
if ! command_exists termux-clipboard-get; then
    print_warning "No se detectó la app 'Termux:API' en Android."
    print_warning "Algunas funciones (portapapeles, wake-lock) no estarán disponibles."
    print_info "Instálala desde F-Droid: https://f-droid.org/packages/com.termux.api/"
fi
echo ""


# ──────────────────────────────────────────────────────────────────────────────
# FASE 2: INSTALACIÓN DE PAQUETES CORE
# ──────────────────────────────────────────────────────────────────────────────
# Instala todas las herramientas del sistema organizadas por categoría.
# Cada paquete se instala de forma idempotente con ensure_pkg():
# si ya existe, se salta sin errores.
#
# Categorías:
#   • Sistema y red      — Herramientas fundamentales de conectividad y gestión.
#   • Navegación/Búsqueda— Reemplazos modernos de cd, find, grep, ls.
#   • Visualización      — Herramientas para ver archivos y datos formateados.
#   • Lenguajes/Runtimes — PHP, Node.js, Python y sus ecosistemas.
#   • Servicios          — PostgreSQL, Nginx y gestión de daemons.
#   • Shell              — Zsh como shell principal.
#   • Multiplexor        — tmux para sesiones persistentes.
# ──────────────────────────────────────────────────────────────────────────────

print_info "Instalando paquetes del sistema (esto puede tomar varios minutos)..."
echo ""

# --- Grupo: Sistema y Red ---
# Herramientas fundamentales para transferencia de archivos, control de versiones,
# conexiones remotas y monitoreo del sistema.
print_info "── Sistema y Red ──"
for p in git curl wget openssh coreutils htop termux-api termux-services; do
    ensure_pkg "$p"
done

# --- Grupo: Navegación y Búsqueda ---
# Reemplazos modernos de herramientas UNIX clásicas, optimizados para velocidad:
#   fzf      → Buscador fuzzy interactivo (reemplaza Ctrl+R y find interactivo).
#   ripgrep  → Búsqueda en archivos (reemplaza grep, 10x más rápido).
#   fd       → Búsqueda de archivos (reemplaza find, sintaxis más simple).
#   zoxide   → Navegación inteligente de directorios (reemplaza cd, aprende rutas).
#   eza      → Listado de archivos con iconos y colores (reemplaza ls).
#   ncdu     → Análisis de uso de disco interactivo (reemplaza du).
#   lf       → Explorador de archivos en terminal (tipo ranger, más ligero).
print_info "── Navegación y Búsqueda ──"
for p in fzf ripgrep fd zoxide eza ncdu lf; do
    ensure_pkg "$p"
done

# --- Grupo: Visualización y Edición ---
#   bat       → Visor de archivos con syntax highlighting (reemplaza cat).
#   glow      → Renderizador de Markdown en terminal (para leer READMEs).
#   fastfetch → Información del sistema con estilo (tipo neofetch, más rápido).
#   neovim    → Editor de texto modal extensible (reemplaza vim).
#   jq        → Procesador de JSON en línea de comandos.
#   unzip/zip → Compresión y descompresión de archivos.
print_info "── Visualización y Edición ──"
for p in bat glow fastfetch neovim jq unzip zip; do
    ensure_pkg "$p"
done

# --- Grupo: Lenguajes y Runtimes ---
#   python     → Scripting, automatización y herramientas del sistema.
#   nodejs-lts → Runtime JavaScript/TypeScript (versión LTS para estabilidad).
#   php        → Runtime PHP para Laravel y desarrollo backend.
print_info "── Lenguajes y Runtimes ──"
for p in python nodejs-lts php; do
    ensure_pkg "$p"
done

# --- Grupo: Servicios ---
#   postgresql → Base de datos relacional potente (para datos de producción).
#   nginx      → Servidor web/proxy reverso ligero y de alto rendimiento.
print_info "── Servicios ──"
for p in postgresql nginx; do
    ensure_pkg "$p"
done

# --- Grupo: Shell y Multiplexor ---
#   zsh  → Shell avanzada con autocompletado, temas y plugins.
#   tmux → Multiplexor de terminal: múltiples paneles y sesiones persistentes.
#          Ideal para mantener procesos corriendo aunque cierres la terminal.
print_info "── Shell y Multiplexor ──"
for p in zsh tmux; do
    ensure_pkg "$p"
done

echo ""
print_info "Instalando herramientas adicionales..."

# --- lazygit ---
# Interfaz TUI para Git. Permite hacer commits, ver diffs, resolver conflictos
# y manejar branches de forma visual sin salir de la terminal.
if ! command_exists lazygit; then
    print_info "Instalando lazygit (TUI para Git)..."
    pkg install -y lazygit
else
    print_success "lazygit ya está instalado."
fi

# --- tree-sitter-cli ---
# Generador de parsers incrementales. Neovim lo necesita para el syntax
# highlighting avanzado de LazyVim (Treesitter). Sin él, el resaltado de
# sintaxis será básico y algunos plugins no funcionarán correctamente.
if ! command_exists tree-sitter; then
    print_info "Instalando tree-sitter CLI (necesario para Neovim/LazyVim)..."
    npm install -g tree-sitter-cli
else
    print_success "tree-sitter CLI ya está instalado."
fi

# --- Composer ---
# Gestor de dependencias de PHP. Indispensable para instalar Laravel y
# cualquier librería del ecosistema PHP. Se descarga como PHAR y se mueve
# al PATH global de Termux para usarlo como comando `composer`.
if ! command_exists composer; then
    print_info "Instalando Composer (gestor de dependencias PHP)..."
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar "$PREFIX/bin/composer"
    chmod +x "$PREFIX/bin/composer"
    print_success "Composer instalado."
else
    print_success "Composer ya está instalado."
fi

print_success "Todos los paquetes core están instalados."
echo ""


# ──────────────────────────────────────────────────────────────────────────────
# FASE 3: IDENTIDAD DEL DESARROLLADOR (GIT Y SSH)
# ──────────────────────────────────────────────────────────────────────────────
# Configura las credenciales de Git y genera una llave SSH para autenticación
# segura con servicios como GitHub, GitLab o Bitbucket.
#
# Idempotencia:
#   • Git: Solo pregunta nombre/email si no están configurados globalmente.
#   • SSH: Solo genera la llave si ~/.ssh/id_ed25519 no existe.
#
# La llave SSH usa el algoritmo Ed25519, más seguro y rápido que RSA.
# Se genera sin passphrase (-N "") para uso no-interactivo en Termux.
# ──────────────────────────────────────────────────────────────────────────────

print_info "Configurando identidad del desarrollador..."

# --- Paso 3.1: Configuración de Git ---
if [ -z "$(git config --global user.name 2>/dev/null || echo '')" ]; then
    echo ""
    read -r -p "$(echo -e "${CYAN}Introduce tu nombre para Git: ${NC}")" git_name
    git config --global user.name "$git_name"
    read -r -p "$(echo -e "${CYAN}Introduce tu email para Git: ${NC}")" git_email
    git config --global user.email "$git_email"
    print_success "Git configurado: $git_name <$git_email>"
else
    print_success "Git ya tiene identidad: $(git config --global user.name) <$(git config --global user.email)>"
fi

# --- Paso 3.2: Generación de Llave SSH ---
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    print_info "Generando llave SSH segura (Ed25519)..."
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "$(git config --global user.email)" -N "" -f "$HOME/.ssh/id_ed25519"
    chmod 600 "$HOME/.ssh/id_ed25519"
    chmod 644 "$HOME/.ssh/id_ed25519.pub"
    print_success "Llave SSH generada."
    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  Tu clave pública SSH (cópiala a GitHub/GitLab):         ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════╝${NC}"
    cat "$HOME/.ssh/id_ed25519.pub"
    echo ""
    pause "Copia la clave de arriba y luego presiona ENTER para continuar"
else
    print_success "Llave SSH ya existe en ~/.ssh/id_ed25519"
fi
echo ""


# ──────────────────────────────────────────────────────────────────────────────
# FASE 4: CONFIGURACIÓN DE POSTGRESQL
# ──────────────────────────────────────────────────────────────────────────────
# PostgreSQL es la base de datos relacional principal del stack. Esta fase:
#   1. Inicializa el clúster de datos (initdb) si no existe.
#   2. Crea un usuario administrador con contraseña (solicitada al usuario).
#   3. Crea una base de datos de desarrollo asociada a ese usuario.
#   4. Registra PostgreSQL como servicio gestionado por termux-services.
#
# Idempotencia:
#   • Solo ejecuta initdb si el directorio de datos está vacío o no existe.
#   • createuser y createdb usan `|| true` para no fallar si ya existen.
#
# Gestión de servicios:
#   • Método 1 (termux-services): sv up postgresql / sv down postgresql
#   • Método 2 (directo): pg_ctl -D $PREFIX/var/lib/postgresql start/stop
#   • Ambos métodos estarán disponibles como aliases.
# ──────────────────────────────────────────────────────────────────────────────

print_info "Configurando PostgreSQL..."

PG_DATA="$PREFIX/var/lib/postgresql"

if [ ! -d "$PG_DATA" ] || [ -z "$(ls -A "$PG_DATA" 2>/dev/null)" ]; then
    print_info "Inicializando clúster de PostgreSQL..."
    mkdir -p "$PG_DATA"
    initdb -D "$PG_DATA"

    # --- Solicitar credenciales de forma segura ---
    echo ""
    echo -e "${CYAN}Configuración del usuario administrador de PostgreSQL:${NC}"
    read -r -p "$(echo -e "${CYAN}Nombre de usuario para PostgreSQL [txadmin]: ${NC}")" pg_user
    pg_user="${pg_user:-txadmin}"

    # read -s oculta la contraseña mientras se escribe (no aparece en pantalla).
    # Se pide dos veces para confirmar y evitar errores de tipeo.
    while true; do
        read -r -s -p "$(echo -e "${CYAN}Contraseña para '$pg_user': ${NC}")" pg_pass
        echo ""
        read -r -s -p "$(echo -e "${CYAN}Confirma la contraseña: ${NC}")" pg_pass_confirm
        echo ""
        if [ "$pg_pass" = "$pg_pass_confirm" ] && [ -n "$pg_pass" ]; then
            break
        fi
        print_error "Las contraseñas no coinciden o están vacías. Inténtalo de nuevo."
    done

    # Iniciar PostgreSQL temporalmente para crear usuario y base de datos.
    # Se detiene inmediatamente después para que el usuario controle cuándo corre.
    pg_ctl -D "$PG_DATA" start
    sleep 3

    print_info "Creando usuario '$pg_user' y base de datos '$pg_user'..."
    createuser --createdb --superuser "$pg_user" 2>/dev/null || true
    psql -c "ALTER USER $pg_user WITH PASSWORD '$pg_pass';" postgres
    createdb -O "$pg_user" "$pg_user" 2>/dev/null || true

    pg_ctl -D "$PG_DATA" stop
    sleep 2

    # Guardar el nombre de usuario (NO la contraseña) para el resumen final.
    PG_USER_CREATED="$pg_user"
    print_success "PostgreSQL configurado con usuario '$pg_user'."
else
    PG_USER_CREATED=""
    print_success "El clúster de PostgreSQL ya estaba inicializado."
fi

# --- Registrar como servicio gestionado ---
# sv-enable crea un symlink en $PREFIX/var/service/ que permite a
# termux-services gestionar el daemon (sv up/down/restart/status).
sv-enable postgresql 2>/dev/null || true
print_success "Servicio PostgreSQL registrado. Usa 'sv up postgresql' o 'pg-start' para iniciarlo."
echo ""


# ──────────────────────────────────────────────────────────────────────────────
# FASE 5: CONFIGURACIÓN DE NGINX
# ──────────────────────────────────────────────────────────────────────────────
# Nginx actúa como servidor web para proyectos estáticos (React builds),
# apps PHP y como proxy reverso para servicios Node.js.
#
# Configuración:
#   • Puerto: 8080 (Termux no puede usar puertos < 1024 sin root).
#   • Document Root: ~/www (carpeta de proyectos del usuario).
#   • PHP-FPM: Stub comentado, listo para habilitar cuando se necesite.
#   • try_files: Compatible con SPAs (React Router) y Laravel.
#
# Idempotencia:
#   • Solo reescribe nginx.conf si no contiene la ruta correcta de ~/www.
#   • Solo crea index.html si no existe.
# ──────────────────────────────────────────────────────────────────────────────

print_info "Configurando Nginx..."

NGINX_CONF="$PREFIX/etc/nginx/nginx.conf"
WWW_DIR="$HOME/www"

# Crear directorio de proyectos web y página de prueba.
mkdir -p "$WWW_DIR"
if [ ! -f "$WWW_DIR/index.html" ]; then
    cat > "$WWW_DIR/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Termux Workstation</title>
    <style>
        body { font-family: system-ui, sans-serif; max-width: 600px; margin: 60px auto; padding: 0 20px; background: #0d1117; color: #c9d1d9; }
        h1 { color: #58a6ff; }
        code { background: #161b22; padding: 2px 6px; border-radius: 4px; color: #f0883e; }
    </style>
</head>
<body>
    <h1>Termux Workstation</h1>
    <p>Nginx está funcionando correctamente en el puerto <code>8080</code>.</p>
    <p>Coloca tus proyectos en <code>~/www</code> para servirlos.</p>
</body>
</html>
HTMLEOF
    print_success "Página de prueba creada en $WWW_DIR/index.html"
fi

# Escribir configuración de Nginx solo si no está aplicada.
# Se usa la presencia de "root $WWW_DIR" como marcador de idempotencia.
if ! grep -q "root $WWW_DIR;" "$NGINX_CONF" 2>/dev/null; then
    print_info "Escribiendo configuración de Nginx (puerto 8080)..."
    cat > "$NGINX_CONF" << NGINXEOF
# ==============================================================================
# Nginx — Termux Workstation
# Puerto: 8080 | Root: $WWW_DIR
# ==============================================================================

worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    # --- Servidor principal ---
    server {
        listen       8080;
        server_name  localhost;
        root         $WWW_DIR;
        index        index.html index.htm index.php;

        # try_files: Intenta servir el archivo solicitado; si no existe,
        # redirige a index.php (Laravel) o index.html (React SPA).
        location / {
            try_files \$uri \$uri/ /index.php?\$query_string;
        }

        # --- PHP-FPM (FastCGI) ---
        # Descomenta este bloque cuando necesites servir PHP directamente
        # a través de Nginx en lugar de usar 'php artisan serve'.
        #
        # location ~ \.php\$ {
        #     fastcgi_pass   127.0.0.1:9000;
        #     fastcgi_index  index.php;
        #     fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
        #     include        fastcgi_params;
        # }

        # --- Proxy para React Dev Server ---
        # Descomenta para redirigir /app a un servidor de desarrollo React/Vite.
        #
        # location /app/ {
        #     proxy_pass http://127.0.0.1:5173/;
        #     proxy_http_version 1.1;
        #     proxy_set_header Upgrade \$http_upgrade;
        #     proxy_set_header Connection "upgrade";
        # }
    }
}
NGINXEOF
    print_success "Configuración de Nginx aplicada (Puerto 8080, Root: $WWW_DIR)."
else
    print_success "La configuración de Nginx ya estaba aplicada."
fi

# Registrar Nginx como servicio gestionado por termux-services.
sv-enable nginx 2>/dev/null || true
print_success "Servicio Nginx registrado. Usa 'sv up nginx' o 'web-start' para iniciarlo."
echo ""


# ──────────────────────────────────────────────────────────────────────────────
# FASE 6: ENTORNO ZSH + OH MY ZSH + POWERLEVEL10K
# ──────────────────────────────────────────────────────────────────────────────
# Zsh es una shell moderna que supera a Bash en autocompletado, navegación
# y extensibilidad. Con Oh My Zsh como framework y Powerlevel10k como tema,
# se obtiene una terminal informativa y visualmente profesional.
#
# Componentes:
#   • Oh My Zsh  — Framework de plugins y configuración para Zsh.
#   • P10K       — Tema rápido con info de Git, Node, PHP en el prompt.
#   • Plugins    — autosuggestions (sugerencias tipo Fish), syntax-highlighting
#                  (colores en tiempo real), z (navegación por frecuencia),
#                  dirhistory (Alt+← Alt+→ para navegar historial de dirs).
#
# Idempotencia:
#   • chsh solo si la shell actual no es Zsh.
#   • Oh My Zsh solo si ~/.oh-my-zsh no existe.
#   • Plugins y tema solo si sus directorios no existen.
#   • Configuración de .zshrc vía sed (tema, plugins) + marcadores (aliases).
# ──────────────────────────────────────────────────────────────────────────────

print_info "Configurando entorno Zsh..."

# --- Paso 6.1: Establecer Zsh como shell por defecto ---
if [ "$(basename "$SHELL")" != "zsh" ]; then
    print_info "Cambiando la shell por defecto a Zsh..."
    chsh -s zsh
else
    print_success "Zsh ya es la shell por defecto."
fi

# --- Paso 6.2: Instalar Oh My Zsh ---
# RUNZSH=no evita que OMZ abra una nueva sesión Zsh al instalarse.
# CHSH=no evita que intente cambiar la shell (ya lo hicimos arriba).
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    print_info "Instalando Oh My Zsh..."
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    print_success "Oh My Zsh instalado."
else
    print_success "Oh My Zsh ya está instalado."
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# --- Paso 6.3: Instalar Plugins de Zsh ---

# zsh-autosuggestions: Sugiere comandos basándose en el historial.
# Aparecen en gris tenue mientras escribes; presiona → para aceptar.
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    print_info "Instalando plugin: zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
else
    print_success "Plugin zsh-autosuggestions ya existe."
fi

# zsh-syntax-highlighting: Colorea la sintaxis de comandos en tiempo real.
# Comandos válidos se muestran en verde, errores en rojo, paths en subrayado.
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    print_info "Instalando plugin: zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"
else
    print_success "Plugin zsh-syntax-highlighting ya existe."
fi

# --- Paso 6.4: Instalar Tema Powerlevel10k ---
# Tema de prompt extremadamente rápido y configurable. Muestra info contextual:
# branch de Git, estado de cambios, versión de Node/PHP, errores de último comando.
# Requiere una Nerd Font para los iconos (se instala en la Fase 10).
if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
    print_info "Instalando tema Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM}/themes/powerlevel10k"
else
    print_success "Tema Powerlevel10k ya existe."
fi

# --- Paso 6.5: Configurar .zshrc ---
# Modifica el archivo de configuración de Zsh para activar el tema y los plugins.
if [ -f "$HOME/.zshrc" ]; then
    print_info "Ajustando configuración de ~/.zshrc..."

    # Activar tema Powerlevel10k (reemplaza cualquier tema anterior).
    sed -i 's/ZSH_THEME=".*"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$HOME/.zshrc"

    # Activar plugins (solo si aún tiene el valor por defecto).
    # Los plugins se cargan en orden: primero los built-in de OMZ, luego los custom.
    if ! grep -q "zsh-autosuggestions" "$HOME/.zshrc"; then
        sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting z dirhistory)/' "$HOME/.zshrc"
    fi

    print_success "Tema P10K y plugins configurados en .zshrc"
fi
echo ""


# ──────────────────────────────────────────────────────────────────────────────
# FASE 7: ALIASES, FUNCIONES Y CONFIGURACIÓN DE SHELL
# ──────────────────────────────────────────────────────────────────────────────
# Inyecta un bloque completo de aliases y funciones útiles en ~/.zshrc.
#
# Estrategia de idempotencia (patrón de marcadores):
#   Todo el contenido personalizado se envuelve entre dos líneas marcadoras:
#     # --- TERMUX-WS START ---
#     ... contenido ...
#     # --- TERMUX-WS END ---
#   Al re-ejecutar, el bloque anterior se ELIMINA con sed y se reescribe
#   completo. Esto garantiza que:
#     1. Nunca se duplican aliases.
#     2. Los cambios en nuevas versiones del script se aplican automáticamente.
#     3. Cualquier personalización FUERA del bloque se preserva intacta.
#
# Organización de aliases:
#   • Inicialización  — Herramientas que requieren eval (zoxide).
#   • Navegación      — Moverse entre directorios de forma rápida.
#   • Listado (eza)   — Reemplazos de ls con iconos y formato.
#   • Visualización   — bat como reemplazo de cat con syntax highlighting.
#   • Editor          — Atajos para Neovim.
#   • Nginx           — Control del servidor web (sv + directo).
#   • PostgreSQL      — Control de la base de datos (sv + directo).
#   • PHP/Laravel     — Atajos para artisan y composer.
#   • Node/JS         — Atajos para npm.
#   • Git             — Atajos para operaciones frecuentes + lazygit.
#   • Búsqueda        — Reemplazos de grep/find con herramientas modernas.
#   • Android         — Integración con Termux:API (portapapeles, wake-lock).
#   • Productividad   — Mantenimiento del sistema y utilidades.
#   • Dev rápido      — Arrancar/detener todo el stack con un solo comando.
# ──────────────────────────────────────────────────────────────────────────────

print_info "Inyectando aliases y configuración de shell..."

MARKER_START="# --- TERMUX-WS START ---"
MARKER_END="# --- TERMUX-WS END ---"
ZSHRC="$HOME/.zshrc"

# Eliminar bloque anterior si existe (limpieza para re-inyección).
if grep -q "$MARKER_START" "$ZSHRC" 2>/dev/null; then
    sed -i "/$MARKER_START/,/$MARKER_END/d" "$ZSHRC"
fi

# Escribir el bloque completo de configuración.
cat >> "$ZSHRC" << 'ALIASEOF'
# --- TERMUX-WS START ---
# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  Termux Workstation — Aliases y Configuración                              ║
# ║  Este bloque es gestionado automáticamente por termux-workstation.sh       ║
# ║  NO editar manualmente: los cambios se perderán al re-ejecutar.            ║
# ║  Para aliases personalizados, agrégalos DEBAJO de "TERMUX-WS END".         ║
# ╚════════════════════════════════════════════════════════════════════════════╝

# ══════════════════════════════════════════════════════════════
# ⚙️  INICIALIZACIÓN DE HERRAMIENTAS
# ══════════════════════════════════════════════════════════════
# zoxide necesita inicializarse en cada sesión de shell para registrar
# los directorios visitados y proveer navegación inteligente con 'z'.
eval "$(zoxide init zsh)"

# ══════════════════════════════════════════════════════════════
# 📁  NAVEGACIÓN Y SISTEMA
# ══════════════════════════════════════════════════════════════
# z: Salta a directorios por nombre parcial (aprende de tu uso).
# Ejemplo: 'cd proyectos' salta a ~/www/proyectos si lo visitas seguido.
alias cd="z"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias home="cd ~"
alias www="cd ~/www"
alias cls="clear"

# ══════════════════════════════════════════════════════════════
# 📂  LISTADO DE ARCHIVOS (EZA)
# ══════════════════════════════════════════════════════════════
# eza: Reemplazo moderno de ls con iconos, colores y formato Git.
# Requiere Nerd Font para mostrar los iconos correctamente.
alias ls="eza --icons"
alias ll="eza -lh --icons --git"
alias la="eza -lah --icons --git"
alias tree="eza --tree --icons --level=3"

# ══════════════════════════════════════════════════════════════
# 📄  VISUALIZACIÓN DE ARCHIVOS
# ══════════════════════════════════════════════════════════════
# bat: cat con syntax highlighting, números de línea y paginación.
alias cat="bat --paging=never"
alias catp="bat"

# ══════════════════════════════════════════════════════════════
# 🧠  NEOVIM / EDITOR
# ══════════════════════════════════════════════════════════════
# Todos los alias de editor apuntan a Neovim (con LazyVim).
alias v="nvim"
alias vi="nvim"
alias vim="nvim"
alias nv="nvim ."

# ══════════════════════════════════════════════════════════════
# 🌐  NGINX (SERVIDOR WEB)
# ══════════════════════════════════════════════════════════════
# Método 1: Via termux-services (recomendado, gestión centralizada).
alias ng-start="sv up nginx"
alias ng-stop="sv down nginx"
alias ng-restart="sv restart nginx"
alias ng-status="sv status nginx"
# Método 2: Directo (útil si termux-services no está corriendo).
alias web-start="nginx"
alias web-stop="nginx -s stop"
alias web-reload="nginx -s reload"

# ══════════════════════════════════════════════════════════════
# 🗄️  POSTGRESQL
# ══════════════════════════════════════════════════════════════
# Método 1: Via termux-services (recomendado).
alias pg-start="sv up postgresql"
alias pg-stop="sv down postgresql"
alias pg-restart="sv restart postgresql"
alias pg-status="sv status postgresql"
# Método 2: Directo con pg_ctl (control fino, útil para debugging).
alias pg-ctl-start="pg_ctl -D \$PREFIX/var/lib/postgresql start"
alias pg-ctl-stop="pg_ctl -D \$PREFIX/var/lib/postgresql stop"
# Conexión rápida al cliente psql.
alias pg-connect="psql -U txadmin -d txadmin"

# ══════════════════════════════════════════════════════════════
# 🐘  PHP / LARAVEL
# ══════════════════════════════════════════════════════════════
# artisan: CLI de Laravel para migraciones, seeders, queues, etc.
# serve:   Inicia el servidor de desarrollo Laravel accesible desde la red.
#          --host=0.0.0.0 permite acceder desde otros dispositivos en la LAN.
alias artisan="php artisan"
alias serve="php artisan serve --host=0.0.0.0"
alias tinker="php artisan tinker"
alias migrate="php artisan migrate"
alias comp-update="composer update"
alias comp-install="composer install"

# ══════════════════════════════════════════════════════════════
# 🟢  NODE / JAVASCRIPT
# ══════════════════════════════════════════════════════════════
alias npmi="npm install"
alias npms="npm start"
alias npmd="npm run dev"
alias npmb="npm run build"
alias npmt="npm test"

# ══════════════════════════════════════════════════════════════
# 🔧  GIT
# ══════════════════════════════════════════════════════════════
alias gs="git status"
alias ga="git add ."
alias gc="git commit -m"
alias gp="git push"
alias gl="git pull"
alias gcl="git clone"
alias glog="git log --oneline --graph --decorate -20"
alias lg="lazygit"

# ══════════════════════════════════════════════════════════════
# 🔍  BÚSQUEDA Y ARCHIVOS
# ══════════════════════════════════════════════════════════════
# fzf: Buscador fuzzy interactivo para archivos, historial, procesos.
# rg:  ripgrep, búsqueda en contenido de archivos (10x más rápido que grep).
# fd:  Búsqueda de archivos por nombre (más simple y rápido que find).
alias ff="fzf"
alias grep="rg"
alias find="fd"

# ══════════════════════════════════════════════════════════════
# 📱  INTEGRACIÓN CON ANDROID (TERMUX:API)
# ══════════════════════════════════════════════════════════════
# Requiere la app Termux:API instalada en Android.
# copy/paste: Portapapeles del sistema Android desde la terminal.
# lock-on:    Evita que Android suspenda Termux (para procesos largos).
alias copy="termux-clipboard-set"
alias paste="termux-clipboard-get"
alias lock-on="termux-wake-lock"
alias lock-off="termux-wake-unlock"
alias share="termux-share"
alias open="termux-open"

# ══════════════════════════════════════════════════════════════
# ⚙️  PRODUCTIVIDAD Y MANTENIMIENTO
# ══════════════════════════════════════════════════════════════
alias reload="source ~/.zshrc"
alias update="pkg update -y && pkg upgrade -y"
alias cleanup="pkg clean && npm cache clean --force && composer clear-cache 2>/dev/null; echo 'Cache limpiado.'"
alias path='echo $PATH | tr ":" "\n"'
alias ports="netstat -tulnp 2>/dev/null || ss -tulnp"
alias fetch="fastfetch"
alias myip="ifconfig 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print \$2}'"
alias disk="ncdu"

# ══════════════════════════════════════════════════════════════
# 🚀  FLUJO DE DESARROLLO RÁPIDO
# ══════════════════════════════════════════════════════════════
# dev:       Abre el directorio de proyectos web en Neovim.
# serve-all: Enciende PostgreSQL y Nginx de un solo golpe.
# stop-all:  Apaga ambos servicios para ahorrar batería.
alias dev="cd ~/www && nvim ."
alias serve-all="sv up postgresql && sv up nginx && echo 'Servicios iniciados.'"
alias stop-all="sv down postgresql && sv down nginx && echo 'Servicios detenidos.'"

# --- TERMUX-WS END ---
ALIASEOF

print_success "Aliases y configuración inyectados en ~/.zshrc (bloque TERMUX-WS)."
echo ""


# ──────────────────────────────────────────────────────────────────────────────
# FASE 8: NEOVIM + LAZYVIM
# ──────────────────────────────────────────────────────────────────────────────
# LazyVim es una distribución de Neovim preconfigurada que transforma el
# editor en un IDE completo con:
#   • Autocompletado inteligente (nvim-cmp + LSPs).
#   • Navegación de archivos (neo-tree, Telescope).
#   • Git integrado (gitsigns, fugitive).
#   • Debugging, formateo, linting — todo lazy-loaded para velocidad.
#
# Esta fase:
#   1. Hace backup de cualquier configuración anterior de Neovim.
#   2. Clona el starter template de LazyVim.
#   3. Inyecta un archivo de extras que habilita soporte específico para:
#      PHP, TypeScript/JavaScript, JSON, Tailwind CSS y Prettier.
#
# Idempotencia:
#   • Solo clona si ~/.config/nvim no existe.
#   • Solo inyecta extras.lua si no existe.
#   • Los plugins se auto-instalan al abrir nvim por primera vez.
# ──────────────────────────────────────────────────────────────────────────────

print_info "Configurando Neovim con LazyVim..."

NVIM_DIR="$HOME/.config/nvim"

# --- Paso 8.1: Backup de configuración anterior ---
# Si existe una configuración de Neovim que NO parece ser LazyVim
# (no tiene la carpeta lua/plugins típica), se respalda para no perderla.
if [ -d "$NVIM_DIR" ] && [ ! -d "$NVIM_DIR/lua/plugins" ]; then
    NVIM_BACKUP="$HOME/.config/nvim.bak.$(date +%s)"
    print_warning "Configuración de Neovim existente respaldada en: $NVIM_BACKUP"
    mv "$NVIM_DIR" "$NVIM_BACKUP"
fi

# --- Paso 8.2: Clonar LazyVim Starter ---
if [ ! -d "$NVIM_DIR" ]; then
    print_info "Clonando LazyVim starter..."
    git clone https://github.com/LazyVim/starter "$NVIM_DIR"
    # Eliminar el .git del starter para que el usuario pueda iniciar su propio repo.
    rm -rf "${NVIM_DIR:?}/.git"
    print_success "LazyVim starter clonado."
else
    print_success "La configuración de LazyVim ya existe."
fi

# --- Paso 8.3: Inyectar configuración de extras para el stack ---
# Los "extras" de LazyVim son paquetes de plugins preconfigurados para
# lenguajes y herramientas específicas. Se activan con un import simple.
EXTRAS_FILE="$NVIM_DIR/lua/plugins/extras.lua"
if [ ! -f "$EXTRAS_FILE" ]; then
    print_info "Inyectando extras de LazyVim (PHP, TS, Tailwind, Prettier)..."
    mkdir -p "$NVIM_DIR/lua/plugins"
    cat > "$EXTRAS_FILE" << 'LUAEOF'
-- ==============================================================================
-- LazyVim Extras — Termux Workstation
-- ==============================================================================
-- Cada import activa un conjunto de plugins preconfigurados para un lenguaje
-- o herramienta. LazyVim se encarga de instalar y configurar todo.
-- Docs: https://www.lazyvim.org/extras
-- ==============================================================================
return {
  -- PHP: intelephense (LSP), blade templates, phpactor
  { import = "lazyvim.plugins.extras.lang.php" },

  -- TypeScript / JavaScript / React: ts_ls, JSX/TSX support
  { import = "lazyvim.plugins.extras.lang.typescript" },

  -- JSON: schemastore, validación de package.json, tsconfig, etc.
  { import = "lazyvim.plugins.extras.lang.json" },

  -- Tailwind CSS: autocompletado de clases, color preview
  { import = "lazyvim.plugins.extras.lang.tailwind" },

  -- Prettier: formateo automático al guardar (JS, TS, CSS, HTML, JSON, MD)
  { import = "lazyvim.plugins.extras.formatting.prettier" },

  -- Mini-hipatterns: resaltado de colores hex/rgb inline (#ff0000 → rojo)
  { import = "lazyvim.plugins.extras.util.mini-hipatterns" },
}
LUAEOF
    print_success "Extras de LazyVim configurados."
else
    print_success "Los extras de LazyVim ya están configurados."
fi
echo ""


# ──────────────────────────────────────────────────────────────────────────────
# FASE 9: PRE-INSTALACIÓN DE LANGUAGE SERVERS (LSPs)
# ──────────────────────────────────────────────────────────────────────────────
# Los Language Servers proporcionan autocompletado, diagnósticos, go-to-definition,
# rename y otras funciones de IDE a Neovim a través del protocolo LSP.
#
# Al pre-instalarlos globalmente vía npm, evitamos que Neovim/Mason tenga que
# descargarlos la primera vez que se abre un archivo (lo cual puede ser lento
# en conexiones móviles y frustrante para el usuario).
#
# Servers instalados:
#   • typescript-language-server — JS/TS/JSX/TSX autocompletado y diagnósticos.
#   • typescript                — Compilador TS (dependencia del LSP).
#   • tailwindcss-language-server — Autocompletado de clases Tailwind.
#   • vscode-langservers-extracted — HTML, CSS, JSON y ESLint LSPs (4 en 1).
#   • intelephense              — PHP LSP premium (autocompletado, refactoring).
#   • bash-language-server      — Autocompletado y diagnósticos para scripts Bash.
#
# Nota: sql-language-server se excluye porque depende de sqlite3 (addon nativo
# de C) que no tiene binarios precompilados para Android/arm64 y falla al
# compilar con node-gyp en Termux (Python 3.13+ eliminó distutils).
# Para SQL, Mason/LazyVim puede instalar 'sqls' (Go, sin deps nativas) al abrir .sql.
#
# Idempotencia:
#   npm install -g no reinstala paquetes que ya están en la versión correcta.
# ──────────────────────────────────────────────────────────────────────────────

print_info "Pre-instalando Language Servers para Neovim..."

npm install -g \
    typescript-language-server \
    typescript \
    tailwindcss-language-server \
    vscode-langservers-extracted \
    intelephense \
    bash-language-server

print_success "Language Servers instalados globalmente."
echo ""


# ──────────────────────────────────────────────────────────────────────────────
# FASE 10: TEMAS DE TERMINAL (TERMUX THEME SWITCHER)
# ──────────────────────────────────────────────────────────────────────────────
# Instala una colección de 16 temas de color para Termux organizados en
# 8 pares dark/light, con un comando unificado `theme` y aliases rápidos.
#
# Fuente: https://github.com/DeartDev/termux_themes
#
# Qué instala:
#   • 16 archivos .properties en ~/.termux/themes/
#   • Función theme() en ~/.termux/theme.sh (cambiar tema con un comando).
#   • Línea `source ~/.termux/theme.sh` en .zshrc (fuera del bloque TERMUX-WS).
#
# Temas disponibles (8 pares dark/light):
#   1. dark/light      — Zinc (contraste neto con ámbar)
#   2. ocean/sky       — Abismo oceánico / Cielo diurno
#   3. mocha/latte     — Catppuccin oscuro / claro
#   4. forest/meadow   — Bosque nocturno / Pradera soleada
#   5. hati/skoll      — Mitología Nórdica (luna / sol)
#   6. pokedark/pokelight — Pokémon oscuro / claro
#   7. charizard/charizard_shiny — Charizard normal / Shiny
#   8. mega_charizard_x/mega_charizard_y — Megas
#
# Uso después de instalar:
#   theme list         — Ver todos los temas disponibles.
#   theme <nombre>     — Aplicar un tema (ej: theme ocean).
#   theme current      — Ver el tema activo.
#   tdark, tlight...   — Aliases rápidos para cada tema.
#
# Idempotencia:
#   • Solo clona el repo si ~/.termux/themes/ no contiene archivos .properties.
#   • El install.sh del repo usa grep -qF antes de modificar .zshrc.
#   • Se puede re-ejecutar sin duplicar entradas ni romper configuraciones.
# ──────────────────────────────────────────────────────────────────────────────

print_info "Instalando temas de terminal (Termux Theme Switcher)..."

THEMES_DIR="$HOME/.termux/themes"
THEME_SH="$HOME/.termux/theme.sh"
THEMES_REPO_URL="https://github.com/DeartDev/termux_themes.git"
THEMES_TMP_DIR="$HOME/.cache/termux-themes-installer"

# Solo instalar si no hay temas previamente instalados o si falta theme.sh.
# Esto permite re-ejecutar el script sin clonar el repo cada vez.
if [ ! -d "$THEMES_DIR" ] || [ -z "$(ls -A "$THEMES_DIR"/*.properties 2>/dev/null)" ] || [ ! -f "$THEME_SH" ]; then
    print_info "Clonando repositorio de temas..."

    # Limpiar directorio temporal si existe de una ejecución anterior fallida.
    rm -rf "$THEMES_TMP_DIR"
    mkdir -p "$THEMES_TMP_DIR"

    # Clonar solo la última versión (--depth=1) para minimizar uso de datos.
    if git clone --depth=1 "$THEMES_REPO_URL" "$THEMES_TMP_DIR"; then
        print_success "Repositorio de temas clonado."

        # Ejecutar el instalador del repo. Este script:
        #   1. Copia los .properties a ~/.termux/themes/
        #   2. Copia theme.sh a ~/.termux/theme.sh
        #   3. Agrega source ~/.termux/theme.sh a .zshrc (idempotente)
        print_info "Ejecutando instalador de temas..."
        bash "$THEMES_TMP_DIR/install.sh"

        # Limpiar el repositorio temporal (ya no se necesita, los archivos
        # fueron copiados a ~/.termux/themes/ y ~/.termux/theme.sh).
        rm -rf "$THEMES_TMP_DIR"

        print_success "16 temas instalados. Usa 'theme list' para verlos, 'theme <nombre>' para aplicar."
    else
        print_warning "No se pudo clonar el repositorio de temas. Se omite este paso."
        print_info "Puedes instalarlo manualmente después:"
        print_info "  git clone $THEMES_REPO_URL && cd termux_themes && bash install.sh"
        rm -rf "$THEMES_TMP_DIR"
    fi
else
    print_success "Temas de terminal ya están instalados ($(ls \"$THEMES_DIR\"/*.properties 2>/dev/null | wc -l) temas)."
fi
echo ""


# ──────────────────────────────────────────────────────────────────────────────
# FASE 11: NERD FONT, RESUMEN FINAL E INSTRUCCIONES
# ──────────────────────────────────────────────────────────────────────────────
# Instala una Nerd Font (MesloLGS NF) necesaria para que Powerlevel10k y
# LazyVim/eza muestren iconos correctamente. Luego muestra un resumen
# completo de todo lo configurado con los datos relevantes.
#
# Nota sobre fuentes en Termux:
#   Termux usa un archivo único (~/.termux/font.ttf) como fuente de la terminal.
#   Al colocar una Nerd Font ahí y hacer termux-reload-settings, toda la
#   terminal usará esa fuente automáticamente.
# ──────────────────────────────────────────────────────────────────────────────

# --- Paso 11.1: Instalación de Nerd Font ---
FONT_FILE="$HOME/.termux/font.ttf"
if [ ! -f "$FONT_FILE" ]; then
    print_info "Instalando fuente MesloLGS NF (Nerd Font para iconos)..."
    mkdir -p "$HOME/.termux"
    if curl -fsSL "https://raw.githubusercontent.com/romkatv/powerlevel10k-media/master/MesloLGS%20NF%20Regular.ttf" -o "$FONT_FILE"; then
        termux-reload-settings 2>/dev/null || true
        print_success "Nerd Font instalada y aplicada."
    else
        print_warning "No se pudo descargar la fuente. Instálala manualmente después."
    fi
else
    print_success "Nerd Font ya está instalada."
fi

# --- Paso 11.2: Resumen Final ---
echo ""
echo -e "${GREEN}${BOLD}"
cat << "DONE"
  ╔════════════════════════════════════════════════════════════╗
  ║     ✅  CONFIGURACIÓN COMPLETADA EXITOSAMENTE  ✅         ║
  ╚════════════════════════════════════════════════════════════╝
DONE
echo -e "${NC}"

echo -e "${CYAN}${BOLD}═══ Resumen de Servicios ══════════════════════════════════════${NC}"
echo ""
echo -e "  ${BOLD}PostgreSQL:${NC}"
if [ -n "${PG_USER_CREATED:-}" ]; then
echo -e "    Usuario  : ${CYAN}$PG_USER_CREATED${NC}"
echo -e "    Base datos: ${CYAN}$PG_USER_CREATED${NC}"
echo -e "    Contraseña: ${YELLOW}(la que ingresaste durante el setup)${NC}"
fi
echo -e "    Iniciar  : ${CYAN}pg-start${NC}  |  Detener: ${CYAN}pg-stop${NC}"
echo ""
echo -e "  ${BOLD}Nginx:${NC}"
echo -e "    Puerto   : ${CYAN}8080${NC}"
echo -e "    Root     : ${CYAN}$HOME/www${NC}"
echo -e "    Iniciar  : ${CYAN}ng-start${NC}  |  Detener: ${CYAN}ng-stop${NC}"
echo ""
echo -e "  ${BOLD}SSH:${NC}"
if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
echo -e "    Clave    : ${CYAN}~/.ssh/id_ed25519.pub${NC}"
fi
echo ""

echo -e "${CYAN}${BOLD}═══ Aliases Principales ═══════════════════════════════════════${NC}"
echo ""
echo -e "  ${BOLD}Desarrollo:${NC}"
echo -e "    ${CYAN}dev${NC}         → Abre ~/www en Neovim"
echo -e "    ${CYAN}serve-all${NC}   → Inicia PostgreSQL + Nginx"
echo -e "    ${CYAN}stop-all${NC}    → Detiene todos los servicios"
echo -e "    ${CYAN}serve${NC}       → php artisan serve (accesible en LAN)"
echo ""
echo -e "  ${BOLD}Editor:${NC}"
echo -e "    ${CYAN}v${NC} / ${CYAN}nv${NC}      → nvim / nvim ."
echo ""
echo -e "  ${BOLD}Herramientas:${NC}"
echo -e "    ${CYAN}lg${NC}          → lazygit (Git visual)"
echo -e "    ${CYAN}ff${NC}          → fzf (búsqueda fuzzy)"
echo -e "    ${CYAN}fetch${NC}       → Info del sistema"
echo -e "    ${CYAN}reload${NC}      → Recargar .zshrc"
echo ""
echo -e "  ${BOLD}Temas:${NC}"
echo -e "    ${CYAN}theme list${NC}  → Ver todos los temas"
echo -e "    ${CYAN}theme ocean${NC} → Aplicar tema (ejemplo)"
echo -e "    ${CYAN}tdark${NC}       → Alias rápido para tema dark"
echo ""

echo -e "${YELLOW}${BOLD}═══ Pasos Siguientes ═════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BOLD}1.${NC} ${YELLOW}CIERRA Termux por completo${NC} (fuerza la detención desde Android)"
echo -e "     y vuelve a abrirlo para aplicar Zsh como shell por defecto."
echo ""
echo -e "  ${BOLD}2.${NC} Al abrir de nuevo, Powerlevel10k iniciará su asistente de"
echo -e "     configuración (${CYAN}p10k configure${NC}). Sigue las instrucciones."
echo ""
echo -e "  ${BOLD}3.${NC} La primera vez que abras ${CYAN}nvim${NC}, LazyVim descargará e"
echo -e "     instalará todos los plugins automáticamente. Espera a que termine."
echo ""
echo -e "  ${BOLD}4.${NC} Revisa el log completo de esta instalación en:"
echo -e "     ${CYAN}$LOG_FILE${NC}"
echo ""
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ¡Tu mini-workstation de bolsillo está lista!${NC}"
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""
