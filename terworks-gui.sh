#!/usr/bin/env bash

# ==============================================================================
#  TERWORKS GUI v1.0.0
#  Escritorio XFCE4 con Termux:X11 para distros proot-distro
# ==============================================================================
#  Desktop : XFCE4 + XFCE4-Goodies
#  Display : Termux:X11 (servidor X11 nativo Android)
#  Audio   : PulseAudio (TCP forwarding)
#  Browser : Firefox ESR
#  Theme   : Adwaita-dark
# ------------------------------------------------------------------------------
#  Complementario a termux-workstation.sh y terworks-linux.sh.
#  Instala un escritorio gráfico XFCE4 dentro de una distro Linux ya
#  configurada por terworks-linux.sh, y genera scripts de inicio/parada
#  con ciclo de vida completo (Termux:X11 → PulseAudio → XFCE4).
#
#  ¿Cómo funciona?
#  Termux:X11 actúa como servidor X11 nativo en Android. La distro proot
#  ejecuta XFCE4 conectándose a ese servidor via /tmp compartido
#  (--shared-tmp). PulseAudio reenvía audio por TCP.
#
#  Ciclo de vida:
#    1. El alias `gui` ejecuta ~/.terworks/start-gui.sh
#    2. Se inicia PulseAudio (TCP) y Termux:X11 (:1) en background.
#    3. Se lanza xfce4-session dentro de la distro (BLOQUEA).
#    4. Al cerrar sesión XFCE o usar `gui-stop`, cleanup automático:
#       matar termux-x11, PulseAudio, cerrar actividad Android.
# ------------------------------------------------------------------------------
#  Principios de diseño:
#    • Idempotente  — Re-ejecutable sin duplicar ni romper nada.
#    • Multi-distro — Aliases gui-debian, gui-ubuntu, gui-arch coexisten.
#    • Documentado  — Cada bloque explica QUÉ hace y POR QUÉ.
# ------------------------------------------------------------------------------
#  Uso:
#    chmod +x terworks-gui.sh
#    bash terworks-gui.sh
# ==============================================================================

SCRIPT_VERSION="1.0.0"

# ──────────────────────────────────────────────────────────────────────────────
# FASE 0: CONFIGURACIÓN GLOBAL, CONSTANTES Y FUNCIONES AUXILIARES
# ──────────────────────────────────────────────────────────────────────────────
# Misma base que termux-workstation.sh y terworks-linux.sh: modo estricto,
# trap de errores, log separado, colores y funciones reutilizables.
#
# Funciones especiales para GUI:
#   • distro_exec_gui() — Ejecuta un comando dentro de la distro usando
#                          --shared-tmp (necesario para el socket X11).
#   • distro_installed() — Verifica si una distro está instalada.
# ──────────────────────────────────────────────────────────────────────────────

# --- Modo estricto de Bash ---
set -euo pipefail

# --- Trap de errores ---
trap 'echo -e "\n\033[0;31m[FATAL] Error inesperado en la línea $LINENO. Revisa el log.\033[0m"; exit 1' ERR

# --- Log de ejecución (separado de los otros scripts) ---
LOG_FILE="$HOME/.terworks-gui-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo ""
echo "========== Ejecución: $(date '+%Y-%m-%d %H:%M:%S') | TerWorks GUI v$SCRIPT_VERSION =========="

# --- Constantes de Colores ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- Funciones de impresión ---
print_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[  OK]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Pausa interactiva ---
pause() {
    echo -e "\n${YELLOW}>>> $1 <<<${NC}"
    read -r -p "Presiona ENTER para continuar..."
}

# --- Verificar si un comando existe ---
command_exists() {
    command -v "$1" &> /dev/null
}

# --- Verificar si un paquete de Termux está instalado ---
pkg_installed() {
    dpkg -s "$1" > /dev/null 2>&1
}

# --- Instalar un paquete solo si no está presente ---
ensure_pkg() {
    if pkg_installed "$1"; then
        print_success "$1 ya está instalado."
    else
        print_info "Instalando: $1..."
        pkg install -y "$1"
    fi
}

# --- Ejecutar un comando dentro de la distro como root (con --shared-tmp) ---
# A diferencia de terworks-linux.sh, este script SIEMPRE usa --shared-tmp
# porque Termux:X11 crea el socket X11 en /tmp/.X11-unix/ y la distro
# necesita acceder a él para que el display funcione.
distro_exec_gui() {
    proot-distro login "$DISTRO_ID" --shared-tmp -- bash -c "$1"
}

# --- Verificar si la distro está instalada ---
# Usa la existencia del directorio rootfs en lugar de parsear la salida de
# 'proot-distro list', cuyo formato cambió entre versiones (antes usaba
# "Alias: X / Installed: yes", ahora usa "* Name < alias >").
distro_installed() {
    [ -d "$PREFIX/var/lib/proot-distro/installed-rootfs/$1" ]
}


# ──────────────────────────────────────────────────────────────────────────────
# FASE 1: BANNER, VALIDACIÓN Y PRE-REQUISITOS
# ──────────────────────────────────────────────────────────────────────────────
# Muestra el banner de bienvenida, verifica que el entorno sea válido
# y que terworks-linux.sh haya sido ejecutado previamente (al menos una
# distro Linux debe estar instalada via proot-distro).
# ──────────────────────────────────────────────────────────────────────────────

clear
echo -e "${CYAN}${BOLD}"
cat << "BANNER"

  ╔════════════════════════════════════════════════════════════╗
  ║         TERWORKS GUI SETUP v1.0.0                          ║
  ║         Escritorio XFCE4 con Termux:X11                    ║
  ║         Firefox · PulseAudio · Adwaita-dark                ║
  ╚════════════════════════════════════════════════════════════╝

BANNER
echo -e "${NC}"
print_info "Iniciando configuración — $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# --- Paso 1.1: Validar entorno Termux ---
if [ ! -d "$PREFIX" ] || ! command_exists pkg; then
    print_error "Este script debe ejecutarse dentro de Termux."
    print_error "Descarga Termux desde F-Droid: https://f-droid.org/packages/com.termux/"
    exit 1
fi

# --- Paso 1.2: Verificar que proot-distro existe ---
if ! command_exists proot-distro; then
    print_error "proot-distro no está instalado."
    print_error "Ejecuta primero 'terworks-linux.sh' para configurar una distro Linux."
    print_error "  bash terworks-linux.sh"
    exit 1
fi

# --- Paso 1.3: Verificar que hay al menos una distro instalada ---
INSTALLED_DISTROS=""
for distro in debian ubuntu archlinux; do
    if distro_installed "$distro"; then
        INSTALLED_DISTROS="$INSTALLED_DISTROS $distro"
    fi
done

if [ -z "$INSTALLED_DISTROS" ]; then
    print_error "No hay distribuciones Linux instaladas."
    print_error "Ejecuta primero 'terworks-linux.sh' para instalar una distro."
    print_error "  bash terworks-linux.sh"
    exit 1
fi

print_success "Pre-requisitos verificados."
echo ""


# ──────────────────────────────────────────────────────────────────────────────
# FASE 2: INSTALACIÓN DE PAQUETES TERMUX-SIDE
# ──────────────────────────────────────────────────────────────────────────────
# Instala los componentes que corren en el lado de Termux (no dentro de la
# distro). Estos forman la infraestructura de display y audio:
#
#   • x11-repo             — Repositorio adicional de Termux con paquetes
#                            gráficos (X11, VNC, etc.).
#   • termux-x11-nightly   — Servidor X11 nativo optimizado para Android.
#                            Renderiza la interfaz gráfica como una app.
#   • pulseaudio           — Servidor de audio que reenvía sonido desde la
#                            distro proot hacia Android via TCP.
#
# Después de instalar los paquetes, verifica que la APK de Termux:X11 esté
# instalada en Android (es una app separada que actúa como display).
# ──────────────────────────────────────────────────────────────────────────────

print_info "Instalando componentes gráficos en Termux..."
echo ""

# --- Paso 2.1: Habilitar repositorio gráfico ---
# x11-repo agrega el repositorio x11 a los sources de Termux.
# Sin él, termux-x11-nightly no estará disponible.
if ! pkg_installed "x11-repo"; then
    print_info "Habilitando repositorio x11..."
    pkg install -y x11-repo
    print_success "Repositorio x11 habilitado."
else
    print_success "Repositorio x11 ya está habilitado."
fi

# --- Paso 2.2: Instalar servidor X11 y PulseAudio ---
ensure_pkg termux-x11-nightly
ensure_pkg pulseaudio

echo ""

# --- Paso 2.3: Verificar APK de Termux:X11 ---
# Termux:X11 necesita una app Android separada que actúa como el display.
# Sin ella, termux-x11 inicia el servidor X pero no hay donde renderizar.
APK_INSTALLED=true
if ! pm list packages 2>/dev/null | grep -q "com.termux.x11"; then
    APK_INSTALLED=false
    echo ""
    print_warning "La app Termux:X11 NO está instalada en Android."
    echo ""
    echo -e "  ${BOLD}Descárgala desde:${NC}"
    echo -e "  ${CYAN}https://github.com/termux/termux-x11/releases/tag/nightly${NC}"
    echo ""
    echo -e "  Instala el archivo ${BOLD}app-arm64-v8a-debug.apk${NC} (o ${BOLD}app-universal-debug.apk${NC})"
    echo -e "  y luego reabre este script."
    echo ""
    pause "Instala la APK de Termux:X11 y presiona ENTER para continuar"
fi

print_success "Componentes gráficos de Termux listos."
echo ""


# ──────────────────────────────────────────────────────────────────────────────
# FASE 3: SELECCIÓN DE DISTRIBUCIÓN PARA EL ESCRITORIO
# ──────────────────────────────────────────────────────────────────────────────
# Muestra un menú con las distros ya instaladas por terworks-linux.sh.
# Solo aparecen las distros que realmente están disponibles en el sistema.
# ──────────────────────────────────────────────────────────────────────────────

echo -e "${CYAN}${BOLD}═══ Selección de Distribución para el Escritorio ═════════════${NC}"
echo ""

# Construir arrays paralelos con las distros disponibles.
DISTRO_IDS=()
DISTRO_LABELS=()
menu_idx=1

if echo "$INSTALLED_DISTROS" | grep -q "debian"; then
    DISTRO_IDS+=("debian")
    DISTRO_LABELS+=("Debian")
    echo -e "  ${BOLD}${menu_idx})${NC} ${CYAN}Debian${NC}"
    menu_idx=$((menu_idx + 1))
fi
if echo "$INSTALLED_DISTROS" | grep -q "ubuntu"; then
    DISTRO_IDS+=("ubuntu")
    DISTRO_LABELS+=("Ubuntu")
    echo -e "  ${BOLD}${menu_idx})${NC} ${CYAN}Ubuntu${NC}"
    menu_idx=$((menu_idx + 1))
fi
if echo "$INSTALLED_DISTROS" | grep -q "archlinux"; then
    DISTRO_IDS+=("archlinux")
    DISTRO_LABELS+=("Arch Linux")
    echo -e "  ${BOLD}${menu_idx})${NC} ${CYAN}Arch Linux${NC}"
    menu_idx=$((menu_idx + 1))
fi

total=${#DISTRO_IDS[@]}
echo ""

# Si solo hay una distro, seleccionarla automáticamente.
if [ "$total" -eq 1 ]; then
    DISTRO_ID="${DISTRO_IDS[0]}"
    DISTRO_LABEL="${DISTRO_LABELS[0]}"
    print_info "Única distro disponible: $DISTRO_LABEL — seleccionada automáticamente."
else
    while true; do
        read -r -p "$(echo -e "${CYAN}Selecciona una distro [1-$total]: ${NC}")" distro_choice
        if [[ "$distro_choice" =~ ^[0-9]+$ ]] && [ "$distro_choice" -ge 1 ] && [ "$distro_choice" -le "$total" ]; then
            idx=$((distro_choice - 1))
            DISTRO_ID="${DISTRO_IDS[$idx]}"
            DISTRO_LABEL="${DISTRO_LABELS[$idx]}"
            break
        fi
        print_error "Opción inválida. Ingresa un número del 1 al $total."
    done
fi

# Configurar comandos de paquetes según la distro seleccionada.
case "$DISTRO_ID" in
    debian|ubuntu)
        PKG_UPDATE="export DEBIAN_FRONTEND=noninteractive && apt-get update -y && apt-get upgrade -y"
        PKG_INSTALL="DEBIAN_FRONTEND=noninteractive apt-get install -y"
        ;;
    archlinux)
        PKG_UPDATE="pacman -Syu --noconfirm"
        PKG_INSTALL="pacman -S --noconfirm"
        ;;
esac

# Detectar el alias de entrada (archlinux → arch).
case "$DISTRO_ID" in
    archlinux) DISTRO_ALIAS="arch" ;;
    *)         DISTRO_ALIAS="$DISTRO_ID" ;;
esac

# Detectar el usuario no-root de la distro.
DISTRO_USER=$(distro_exec_gui "awk -F: '\$3 >= 1000 && \$3 < 65534 {print \$1; exit}' /etc/passwd" 2>/dev/null || echo "dev")

echo ""
print_info "Distro seleccionada: $DISTRO_LABEL ($DISTRO_ID)"
print_info "Usuario detectado: $DISTRO_USER"
echo ""


# ──────────────────────────────────────────────────────────────────────────────
# FASE 4: INSTALACIÓN DE XFCE4 + FIREFOX DENTRO DE LA DISTRO
# ──────────────────────────────────────────────────────────────────────────────
# Instala el escritorio XFCE4 y sus dependencias dentro de la distro proot.
# XFCE4 fue elegido por ser el balance óptimo entre rendimiento y
# funcionalidad en entornos proot (~200-300 MB RAM, ~500 MB disco).
#
# Componentes instalados:
#   • xfce4              — Desktop environment base (panel, wm, session).
#   • xfce4-goodies      — Plugins adicionales del panel, captura, etc.
#   • xfce4-terminal     — Terminal gráfica integrada en XFCE.
#   • dbus-x11           — Bus de mensajes para comunicación entre apps.
#   • firefox-esr        — Navegador web (ESR por estabilidad en proot).
#   • fonts              — Fuentes Noto (emoji) y Liberation (compatibilidad).
#   • mesa-utils         — Utilidades OpenGL (glxinfo para diagnóstico).
#
# Idempotencia:
#   Verifica si xfce4-session ya existe en la distro antes de instalar.
#   Si ya está, solo muestra un mensaje y continúa.
# ──────────────────────────────────────────────────────────────────────────────

print_info "Verificando XFCE4 en $DISTRO_LABEL..."

# Comprobar si XFCE4 ya está instalado.
XFCE_EXISTS=false
if distro_exec_gui "command -v xfce4-session" &>/dev/null; then
    XFCE_EXISTS=true
fi

if [ "$XFCE_EXISTS" = "true" ]; then
    print_success "XFCE4 ya está instalado en $DISTRO_LABEL."
    # Asegurar que el cache de gdk-pixbuf esté actualizado (fix: GTK icon crash).
    print_info "Actualizando cache de gdk-pixbuf..."
    distro_exec_gui "gdk-pixbuf-query-loaders --update-cache 2>/dev/null || true"
else
    print_info "Instalando XFCE4 + Firefox en $DISTRO_LABEL..."
    print_info "Esto puede tomar varios minutos (descarga de ~300-500 MB)."
    echo ""

    # Actualizar paquetes del sistema antes de instalar.
    distro_exec_gui "$PKG_UPDATE"

    # Instalar paquetes según la distro.
    case "$DISTRO_ID" in
        debian|ubuntu)
            distro_exec_gui "$PKG_INSTALL xfce4 xfce4-goodies xfce4-terminal dbus-x11 \
                firefox-esr fonts-noto-color-emoji fonts-liberation2 mesa-utils \
                librsvg2-common adwaita-icon-theme-full"
            ;;
        archlinux)
            distro_exec_gui "$PKG_INSTALL xfce4 xfce4-goodies xfce4-terminal dbus \
                firefox noto-fonts-emoji ttf-liberation mesa-utils \
                librsvg adwaita-icon-theme"
            ;;
    esac

    # Reconstruir cache de gdk-pixbuf para que GTK reconozca formatos PNG/SVG.
    # Sin esto, XFCE4 crashea con: "Failed to load image-missing.png:
    # Unrecognized image file format (gdk-pixbuf-error-quark, 3)".
    print_info "Reconstruyendo cache de gdk-pixbuf..."
    distro_exec_gui "gdk-pixbuf-query-loaders --update-cache"

    print_success "XFCE4 + Firefox instalados en $DISTRO_LABEL."
fi
echo ""


# ──────────────────────────────────────────────────────────────────────────────
# FASE 5: CONFIGURACIÓN DEL TEMA ADWAITA-DARK
# ──────────────────────────────────────────────────────────────────────────────
# Configura el tema visual oscuro (Adwaita-dark) para XFCE4. Esto incluye
# el tema GTK (controles, botones, menús) y el tema del window manager
# (bordes de ventana, botones de cerrar/maximizar).
#
# Se genera un archivo XML de configuración directamente en el directorio
# de config de XFCE del usuario dentro de la distro. Esto evita tener que
# ejecutar xfconf-query (que requiere DBus corriendo).
#
# DPI se auto-calcula basándose en la resolución del dispositivo obtenida
# con `wm size` de Android. Esto asegura que las fuentes y controles
# tengan un tamaño legible en pantallas de alta resolución.
# ──────────────────────────────────────────────────────────────────────────────

print_info "Configurando tema Adwaita-dark en $DISTRO_LABEL..."

# --- Paso 5.1: Auto-detectar resolución y calcular DPI ---
SCREEN_WIDTH=1080
SCREEN_DPI=140

if command_exists wm; then
    WM_SIZE=$(wm size 2>/dev/null | grep "Physical size" | grep -oP '\d+x\d+' || echo "")
    if [ -n "$WM_SIZE" ]; then
        SCREEN_WIDTH=$(echo "$WM_SIZE" | cut -d'x' -f1)
        if [ "$SCREEN_WIDTH" -gt 1440 ]; then
            SCREEN_DPI=192
        elif [ "$SCREEN_WIDTH" -gt 1080 ]; then
            SCREEN_DPI=160
        elif [ "$SCREEN_WIDTH" -gt 720 ]; then
            SCREEN_DPI=140
        else
            SCREEN_DPI=120
        fi
        print_info "Pantalla detectada: ${WM_SIZE} → DPI: $SCREEN_DPI"
    fi
fi

# --- Paso 5.2: Crear directorio de configuración XFCE ---
XFCE_CONF_DIR="/home/$DISTRO_USER/.config/xfce4/xfconf/xfce-perchannel-xml"
distro_exec_gui "mkdir -p $XFCE_CONF_DIR && chown -R $DISTRO_USER:$DISTRO_USER /home/$DISTRO_USER/.config"

# --- Paso 5.3: Escribir configuración de xsettings (tema GTK + DPI) ---
distro_exec_gui "cat > $XFCE_CONF_DIR/xsettings.xml << 'XMLEOF'
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<channel name=\"xsettings\" version=\"1.0\">
  <property name=\"Net\" type=\"empty\">
    <property name=\"ThemeName\" type=\"string\" value=\"Adwaita-dark\"/>
    <property name=\"IconThemeName\" type=\"string\" value=\"Adwaita\"/>
  </property>
  <property name=\"Xft\" type=\"empty\">
    <property name=\"DPI\" type=\"int\" value=\"$SCREEN_DPI\"/>
    <property name=\"Antialias\" type=\"int\" value=\"1\"/>
    <property name=\"HintStyle\" type=\"string\" value=\"hintslight\"/>
    <property name=\"RGBA\" type=\"string\" value=\"rgb\"/>
  </property>
  <property name=\"Gtk\" type=\"empty\">
    <property name=\"CursorThemeName\" type=\"string\" value=\"Adwaita\"/>
    <property name=\"CursorThemeSize\" type=\"int\" value=\"24\"/>
    <property name=\"FontName\" type=\"string\" value=\"Noto Sans 10\"/>
  </property>
</channel>
XMLEOF"

# --- Paso 5.4: Escribir configuración del window manager (bordes oscuros) ---
distro_exec_gui "cat > $XFCE_CONF_DIR/xfwm4.xml << 'XMLEOF'
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<channel name=\"xfwm4\" version=\"1.0\">
  <property name=\"general\" type=\"empty\">
    <property name=\"theme\" type=\"string\" value=\"Default\"/>
    <property name=\"title_font\" type=\"string\" value=\"Noto Sans Bold 10\"/>
  </property>
</channel>
XMLEOF"

# --- Paso 5.5: Asegurar permisos correctos ---
distro_exec_gui "chown -R $DISTRO_USER:$DISTRO_USER /home/$DISTRO_USER/.config/xfce4"

print_success "Tema Adwaita-dark configurado (DPI: $SCREEN_DPI)."
echo ""


# ──────────────────────────────────────────────────────────────────────────────
# FASE 6: GENERACIÓN DEL SCRIPT LAUNCHER (~/.terworks/start-gui.sh)
# ──────────────────────────────────────────────────────────────────────────────
# Genera el script que orquesta el inicio del entorno gráfico completo.
# Es un script independiente almacenado en ~/.terworks/ que se invoca
# desde los aliases `gui` / `gui-debian` / etc.
#
# Arquitectura del launcher:
#   1. Auto-detectar resolución y DPI del dispositivo.
#   2. Matar procesos residuales de sesiones anteriores (idempotencia).
#   3. Iniciar PulseAudio en modo TCP para forwarding de audio.
#   4. Iniciar el servidor Termux:X11 en background.
#   5. Lanzar proot-distro con --shared-tmp ejecutando xfce4-session.
#      Este paso BLOQUEA hasta que XFCE termine (logout, kill, gui-stop).
#   6. Al desbloquear, cleanup automático: matar X11, PulseAudio, actividad.
#
# El script acepta un argumento opcional con la distro a usar:
#   start-gui.sh           → usa $TERWORKS_LINUX (la distro activa)
#   start-gui.sh debian    → usa debian explícitamente
#
# Ciclo de vida y detección de cierre:
#   El comando proot-distro con xfce4-session es BLOQUEANTE. Cuando el
#   usuario cierra sesión en XFCE (logout) o XFCE4 muere por cualquier
#   razón, el comando retorna y se ejecuta cleanup(). Además, un trap
#   en EXIT/SIGTERM/SIGINT asegura que cleanup corra incluso si el
#   proceso del launcher es matado externamente (gui-stop, Ctrl+C, kill).
# ──────────────────────────────────────────────────────────────────────────────

print_info "Generando script de inicio del escritorio..."

TERWORKS_DIR="$HOME/.terworks"
mkdir -p "$TERWORKS_DIR"

LAUNCHER="$TERWORKS_DIR/start-gui.sh"

cat > "$LAUNCHER" << 'LAUNCHEREOF'
#!/usr/bin/env bash
# ==============================================================================
#  TerWorks GUI Launcher — Inicio y ciclo de vida del escritorio XFCE4
#  Generado automáticamente por terworks-gui.sh. No editar manualmente.
# ==============================================================================

set -uo pipefail

# --- Colores ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- Funciones ---
info()  { echo -e "${CYAN}[GUI]${NC} $1"; }
ok()    { echo -e "${GREEN}[GUI]${NC} $1"; }
warn()  { echo -e "${YELLOW}[GUI]${NC} $1"; }
err()   { echo -e "${RED}[GUI]${NC} $1"; }

# ──────────────────────────────────────────────────────────────────────────────
# Determinar qué distro usar
# ──────────────────────────────────────────────────────────────────────────────
# Argumento 1: distro_id (opcional). Si no se pasa, usa $TERWORKS_LINUX.
DISTRO="${1:-${TERWORKS_LINUX:-}}"

if [ -z "$DISTRO" ]; then
    err "No se especificó distro y \$TERWORKS_LINUX no está definido."
    err "Uso: start-gui.sh [debian|ubuntu|archlinux]"
    err "O ejecuta 'source ~/.zshrc' para cargar las variables de TerWorks."
    exit 1
fi

# Detectar usuario de la distro.
DISTRO_USER="${TERWORKS_LINUX_USER:-}"
if [ -z "$DISTRO_USER" ]; then
    DISTRO_USER=$(proot-distro login "$DISTRO" --shared-tmp -- \
        bash -c "awk -F: '\$3 >= 1000 && \$3 < 65534 {print \$1; exit}' /etc/passwd" 2>/dev/null || echo "dev")
fi

info "Distro: $DISTRO | Usuario: $DISTRO_USER"

# ──────────────────────────────────────────────────────────────────────────────
# Auto-detectar resolución y calcular DPI
# ──────────────────────────────────────────────────────────────────────────────
DPI=140
if command -v wm &>/dev/null; then
    WM_SIZE=$(wm size 2>/dev/null | grep "Physical size" | grep -oP '\d+x\d+' || echo "")
    if [ -n "$WM_SIZE" ]; then
        WIDTH=$(echo "$WM_SIZE" | cut -d'x' -f1)
        if [ "$WIDTH" -gt 1440 ]; then
            DPI=192
        elif [ "$WIDTH" -gt 1080 ]; then
            DPI=160
        elif [ "$WIDTH" -gt 720 ]; then
            DPI=140
        else
            DPI=120
        fi
        info "Pantalla: $WM_SIZE → DPI: $DPI"
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# Cleanup: función que mata todos los procesos del entorno gráfico
# ──────────────────────────────────────────────────────────────────────────────
# Se ejecuta al terminar XFCE (return normal del comando bloqueante),
# al recibir SIGTERM/SIGINT (gui-stop, Ctrl+C), o al salir por cualquier
# razón (trap EXIT).
CLEANUP_DONE=false

cleanup() {
    if [ "$CLEANUP_DONE" = "true" ]; then
        return
    fi
    CLEANUP_DONE=true

    echo ""
    info "Finalizando entorno gráfico..."

    # 1. Matar servidor X11 de Termux.
    if pkill -f "termux-x11" 2>/dev/null; then
        ok "Servidor Termux:X11 detenido."
    fi

    # 1b. Limpiar sockets y locks X11 para evitar "server already running".
    rm -f /tmp/.X11-unix/X* /tmp/.X*-lock 2>/dev/null || true

    # 2. Detener PulseAudio.
    if pulseaudio --kill 2>/dev/null; then
        ok "PulseAudio detenido."
    fi

    # 3. Cerrar la actividad Android de Termux:X11.
    am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 2>/dev/null || true

    # 4. Limpiar procesos huérfanos de dbus dentro de la distro.
    proot-distro login "$DISTRO" --shared-tmp -- bash -c "pkill -u $DISTRO_USER dbus 2>/dev/null; true" 2>/dev/null || true

    echo ""
    ok "Entorno gráfico finalizado correctamente."
    echo -e "  Escribe ${CYAN}gui${NC} para iniciar de nuevo."
    echo ""
}

# Registrar cleanup en señales de terminación.
trap cleanup EXIT SIGTERM SIGINT SIGHUP

# ──────────────────────────────────────────────────────────────────────────────
# Matar procesos residuales de sesiones anteriores
# ──────────────────────────────────────────────────────────────────────────────
# Si queda un termux-x11 o PulseAudio de una sesión anterior que no se
# cerró limpiamente, los matamos antes de iniciar para evitar conflictos.
pkill -f "termux-x11" 2>/dev/null || true
pulseaudio --kill 2>/dev/null || true
sleep 1

# Eliminar sockets y locks X11 residuales que impiden re-iniciar el servidor.
# Sin esto, termux-x11 falla con "server already running" aunque el proceso
# ya no exista (el lock file persiste en /tmp).
rm -f /tmp/.X11-unix/X* /tmp/.X*-lock 2>/dev/null || true

# ──────────────────────────────────────────────────────────────────────────────
# Iniciar PulseAudio (TCP forwarding de audio)
# ──────────────────────────────────────────────────────────────────────────────
# PulseAudio corre en Termux y acepta conexiones TCP desde la distro proot.
# La distro se conecta a tcp:127.0.0.1:4713 para enviar audio.
# --exit-idle-time=-1 evita que PulseAudio se cierre por inactividad.
info "Iniciando PulseAudio..."
pulseaudio --start \
    --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1" \
    --exit-idle-time=-1 2>/dev/null || true
ok "PulseAudio iniciado (TCP :4713)."

# ──────────────────────────────────────────────────────────────────────────────
# Iniciar servidor Termux:X11
# ──────────────────────────────────────────────────────────────────────────────
# termux-x11 crea el socket X11 en /tmp/.X11-unix/X1 y la distro accede
# a él via --shared-tmp. El flag -dpi ajusta la escala para la pantalla.
info "Iniciando Termux:X11..."
termux-x11 :1 -dpi "$DPI" &
X11_PID=$!
sleep 2

# Verificar que el servidor X11 arrancó correctamente.
if ! kill -0 "$X11_PID" 2>/dev/null; then
    err "Termux:X11 no pudo iniciar. ¿Está la APK de Termux:X11 instalada?"
    err "Descárgala: https://github.com/termux/termux-x11/releases/tag/nightly"
    exit 1
fi
ok "Termux:X11 iniciado en :1 (PID: $X11_PID)."

# Abrir automáticamente la app Termux:X11 en Android.
info "Abriendo app Termux:X11..."
am start --user 0 -n com.termux.x11/.MainActivity 2>/dev/null || true
sleep 1

# ──────────────────────────────────────────────────────────────────────────────
# Lanzar XFCE4 dentro de la distro (BLOQUEANTE)
# ──────────────────────────────────────────────────────────────────────────────
# Este comando BLOQUEA hasta que XFCE termine. Cuando el usuario cierra
# sesión en XFCE (logout), el comando retorna y se ejecuta cleanup().
#
# Variables de entorno pasadas a la distro:
#   DISPLAY=:1              — Conecta al servidor Termux:X11.
#   PULSE_SERVER=tcp:...    — Conecta al PulseAudio de Termux.
#
# dbus-launch inicia un bus de sesión necesario para XFCE.
# --exit-with-session hace que dbus muera cuando XFCE muera.
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}Escritorio XFCE4 iniciando en $DISTRO...${NC}"
echo -e "  La app ${CYAN}Termux:X11${NC} se abrirá automáticamente."
echo -e "  Para cerrar: ${CYAN}Cerrar Sesión${NC} en XFCE, o ${CYAN}gui-stop${NC} en Termux."
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""

proot-distro login "$DISTRO" --shared-tmp -- su - "$DISTRO_USER" -c \
    "export DISPLAY=:1; export PULSE_SERVER=tcp:127.0.0.1:4713; dbus-launch --exit-with-session xfce4-session" \
    2>/dev/null || true

# XFCE ha terminado — cleanup se ejecuta automáticamente via trap EXIT.
LAUNCHEREOF

chmod +x "$LAUNCHER"
print_success "Launcher generado: ~/.terworks/start-gui.sh"
echo ""


# ──────────────────────────────────────────────────────────────────────────────
# FASE 7: GENERACIÓN DEL SCRIPT DE PARADA (~/.terworks/stop-gui.sh)
# ──────────────────────────────────────────────────────────────────────────────
# Script de emergencia que mata el entorno gráfico desde otra sesión de
# Termux. Útil cuando no se puede cerrar sesión desde XFCE (crash,
# pantalla negra, app congelada).
#
# Este script funciona independientemente del launcher: simplemente busca
# y mata los procesos relevantes sin depender de PIDs guardados.
# ──────────────────────────────────────────────────────────────────────────────

print_info "Generando script de parada..."

STOP_SCRIPT="$TERWORKS_DIR/stop-gui.sh"

cat > "$STOP_SCRIPT" << 'STOPEOF'
#!/usr/bin/env bash
# ==============================================================================
#  TerWorks GUI Stop — Parada limpia del escritorio XFCE4
#  Generado automáticamente por terworks-gui.sh. No editar manualmente.
# ==============================================================================

GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${CYAN}[GUI]${NC} $1"; }
ok()   { echo -e "${GREEN}[GUI]${NC} $1"; }

info "Deteniendo entorno gráfico..."
echo ""

# 1. Matar xfce4-session dentro de cualquier distro proot.
#    Esto causa que el comando bloqueante en start-gui.sh retorne,
#    lo que a su vez dispara el cleanup() del launcher.
pkill -f "xfce4-session" 2>/dev/null && ok "XFCE4 session terminada." || true

# 2. Matar servidor Termux:X11 (por si el cleanup del launcher no corrió).
pkill -f "termux-x11" 2>/dev/null && ok "Termux:X11 detenido." || true

# 2b. Limpiar sockets y locks X11 residuales.
rm -f /tmp/.X11-unix/X* /tmp/.X*-lock 2>/dev/null || true

# 3. Detener PulseAudio.
pulseaudio --kill 2>/dev/null && ok "PulseAudio detenido." || true

# 4. Cerrar la actividad Android de Termux:X11.
am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 2>/dev/null || true

echo ""
ok "Entorno gráfico detenido."
echo -e "  Escribe ${CYAN}gui${NC} para iniciar de nuevo."
echo ""
STOPEOF

chmod +x "$STOP_SCRIPT"
print_success "Script de parada generado: ~/.terworks/stop-gui.sh"
echo ""


# ──────────────────────────────────────────────────────────────────────────────
# FASE 8: INYECCIÓN DE ALIASES EN TERMUX (.zshrc)
# ──────────────────────────────────────────────────────────────────────────────
# Agrega aliases al .zshrc de Termux para iniciar y detener el escritorio.
#
# Estrategia de marcadores:
#   Bloque TERMUX-GUI START/END, separado de TERMUX-WS y TERMUX-LINUX.
#   Los tres bloques coexisten en .zshrc sin interferirse.
#   Al re-ejecutar, el bloque se elimina y reescribe limpio.
#
# Aliases inyectados:
#   • gui            → Iniciar escritorio en la distro activa ($TERWORKS_LINUX).
#   • gui-stop       → Detener escritorio desde otra sesión de Termux.
#   • gui-<distro>   → Iniciar escritorio en una distro específica.
#
# Multi-distro:
#   Si el usuario ejecuta el script varias veces con distros diferentes,
#   los aliases gui-<distro> de ejecuciones anteriores se preservan.
# ──────────────────────────────────────────────────────────────────────────────

print_info "Configurando aliases de escritorio en Termux..."

MARKER_START="# --- TERMUX-GUI START ---"
MARKER_END="# --- TERMUX-GUI END ---"
ZSHRC="$HOME/.zshrc"

# Verificar que .zshrc existe.
if [ ! -f "$ZSHRC" ]; then
    print_warning ".zshrc no encontrado. Creando uno básico..."
    touch "$ZSHRC"
fi

# --- Recolectar aliases GUI de distros previamente configuradas ---
EXISTING_GUI_ALIASES=""
if grep -q "$MARKER_START" "$ZSHRC" 2>/dev/null; then
    EXISTING_GUI_ALIASES=$(sed -n "/$MARKER_START/,/$MARKER_END/p" "$ZSHRC" \
        | grep -E '^alias gui-(debian|ubuntu|arch)=' \
        | grep -v "alias gui-${DISTRO_ALIAS}=" 2>/dev/null || true)

    # Eliminar bloque anterior para reescritura limpia.
    sed -i "/$MARKER_START/,/$MARKER_END/d" "$ZSHRC"
fi

# Escribir el bloque completo de aliases.
cat >> "$ZSHRC" << ALIASEOF
$MARKER_START
# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  TerWorks GUI — Aliases de Escritorio XFCE4                               ║
# ║  Este bloque es gestionado automáticamente por terworks-gui.sh             ║
# ║  NO editar manualmente: los cambios se perderán al re-ejecutar.            ║
# ║  Para aliases personalizados, agrégalos DEBAJO de "TERMUX-GUI END".        ║
# ╚════════════════════════════════════════════════════════════════════════════╝

# Variables de entorno de TerWorks GUI.
# Estas variables indican qué distro/usuario usar para el escritorio.
export TERWORKS_GUI_DISTRO="$DISTRO_ID"
export TERWORKS_GUI_USER="$DISTRO_USER"

# Si \$TERWORKS_LINUX no está definida (terworks-linux.sh no inyectó aliases),
# la establecemos con la distro del escritorio para que el alias 'gui' funcione.
export TERWORKS_LINUX="\${TERWORKS_LINUX:-$DISTRO_ID}"
export TERWORKS_LINUX_USER="\${TERWORKS_LINUX_USER:-$DISTRO_USER}"

# ══════════════════════════════════════════════════════════════
# 🖥️  INICIO DEL ESCRITORIO
# ══════════════════════════════════════════════════════════════
# gui: Iniciar escritorio XFCE4 en la distro activa (\$TERWORKS_LINUX).
alias gui="bash $HOME/.terworks/start-gui.sh"

# Aliases específicos para cada distro con GUI instalado.
alias gui-$DISTRO_ALIAS="bash $HOME/.terworks/start-gui.sh $DISTRO_ID"
$EXISTING_GUI_ALIASES

# ══════════════════════════════════════════════════════════════
# 🛑  PARADA DEL ESCRITORIO
# ══════════════════════════════════════════════════════════════
# gui-stop: Detener el escritorio desde otra sesión de Termux.
# Útil cuando XFCE se congela o no responde al logout.
alias gui-stop="bash $HOME/.terworks/stop-gui.sh"

$MARKER_END
ALIASEOF

print_success "Aliases de escritorio inyectados en ~/.zshrc (bloque TERMUX-GUI)."
echo ""


# ──────────────────────────────────────────────────────────────────────────────
# FASE 9: RESUMEN FINAL E INSTRUCCIONES
# ──────────────────────────────────────────────────────────────────────────────
# Muestra un resumen completo de lo instalado, aliases disponibles e
# instrucciones para usar el entorno gráfico.
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo -e "${CYAN}${BOLD}"
echo "  ╔════════════════════════════════════════════════════════════╗"
echo "  ║         TERWORKS GUI — INSTALACIÓN COMPLETADA              ║"
echo "  ╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BOLD}  Componentes Instalados en $DISTRO_LABEL:${NC}"
echo -e "  ─────────────────────────────────────────────────────"
echo -e "  ${GREEN}✓${NC} XFCE4 Desktop Environment + Goodies"
echo -e "  ${GREEN}✓${NC} XFCE4 Terminal"
echo -e "  ${GREEN}✓${NC} Firefox ESR (navegador web)"
echo -e "  ${GREEN}✓${NC} Fuentes: Noto Color Emoji + Liberation"
echo -e "  ${GREEN}✓${NC} Mesa Utils (rendering por software)"
echo -e "  ${GREEN}✓${NC} Tema: Adwaita-dark (DPI: $SCREEN_DPI)"
echo ""

echo -e "${BOLD}  Componentes en Termux:${NC}"
echo -e "  ─────────────────────────────────────────────────────"
echo -e "  ${GREEN}✓${NC} Termux:X11 (servidor X11 nativo)"
echo -e "  ${GREEN}✓${NC} PulseAudio (audio TCP forwarding)"
if [ "$APK_INSTALLED" = "true" ]; then
    echo -e "  ${GREEN}✓${NC} APK Termux:X11 (detectada en Android)"
else
    echo -e "  ${YELLOW}⚠${NC} APK Termux:X11 — ${YELLOW}NO detectada${NC}"
    echo -e "    Descárgala: ${CYAN}https://github.com/termux/termux-x11/releases/tag/nightly${NC}"
fi
echo ""

echo -e "${BOLD}  Aliases disponibles:${NC}"
echo -e "  ─────────────────────────────────────────────────────"
echo -e "  ${CYAN}gui${NC}              Iniciar escritorio (distro activa)"
echo -e "  ${CYAN}gui-$DISTRO_ALIAS${NC}$(printf '%*s' $((14 - ${#DISTRO_ALIAS})) '')Iniciar escritorio en $DISTRO_LABEL"
# Mostrar aliases de otras distros si existen.
if [ -n "$EXISTING_GUI_ALIASES" ]; then
    echo "$EXISTING_GUI_ALIASES" | while IFS= read -r line; do
        alias_name=$(echo "$line" | grep -oP 'alias \Kgui-\w+')
        if [ -n "$alias_name" ]; then
            echo -e "  ${CYAN}$alias_name${NC}$(printf '%*s' $((16 - ${#alias_name})) '')Escritorio en otra distro"
        fi
    done
fi
echo -e "  ${CYAN}gui-stop${NC}         Detener escritorio (desde otra sesión)"
echo ""

echo -e "${BOLD}  Cómo usar:${NC}"
echo -e "  ─────────────────────────────────────────────────────"
echo -e "  ${CYAN}1.${NC} Recarga tu shell o reabre Termux:"
echo -e "     ${CYAN}source ~/.zshrc${NC}"
echo ""
echo -e "  ${CYAN}2.${NC} Inicia el escritorio:"
echo -e "     ${CYAN}gui${NC}"
echo ""
echo -e "  ${CYAN}3.${NC} Abre la app ${BOLD}Termux:X11${NC} en Android para ver el escritorio."
echo ""
echo -e "  ${CYAN}4.${NC} Para cerrar:"
echo -e "     • Desde XFCE: Menú → ${BOLD}Cerrar Sesión${NC}"
echo -e "     • Desde Termux (otra sesión): ${CYAN}gui-stop${NC}"
echo ""

echo -e "${BOLD}  Notas importantes:${NC}"
echo -e "  ─────────────────────────────────────────────────────"
echo -e "  • El escritorio consume ${YELLOW}~300-500 MB${NC} de RAM adicional."
echo -e "  • El rendering es por software (sin GPU). Apps 3D serán lentas."
echo -e "  • Para ajustar la escala: XFCE → Configuración → Apariencia → Fuentes."
echo -e "  • El audio puede tener ${YELLOW}~100ms${NC} de latencia (normal en TCP)."
echo ""

echo -e "${BOLD}  Archivos generados:${NC}"
echo -e "  ─────────────────────────────────────────────────────"
echo -e "  Launcher:     ${CYAN}~/.terworks/start-gui.sh${NC}"
echo -e "  Stop script:  ${CYAN}~/.terworks/stop-gui.sh${NC}"
echo -e "  Log:          ${CYAN}~/.terworks-gui-setup.log${NC}"
echo -e "  Aliases:      ${CYAN}~/.zshrc${NC} (bloque TERMUX-GUI)"
echo ""

echo -e "${GREEN}${BOLD}  ¡TerWorks GUI está listo! Escribe '${CYAN}gui${GREEN}' para iniciar el escritorio.${NC}"
echo ""

# Recargar .zshrc si estamos en Zsh para que los aliases estén disponibles.
if [ -n "${ZSH_VERSION:-}" ]; then
    source "$ZSHRC" 2>/dev/null || true
fi
