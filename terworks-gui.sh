#!/usr/bin/env bash
# TERWORKS GUI v2.0.0 — Escritorio XFCE4 con Termux:X11

set -euo pipefail
trap 'echo -e "\n\033[0;31m[FATAL] Error en línea $LINENO\033[0m"; exit 1' ERR

# --- Colores y funciones ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()      { echo -e "${GREEN}[  OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[AVISO]${NC} $1"; }
err()     { echo -e "${RED}[ERROR]${NC} $1"; }

pkg_installed() { dpkg -s "$1" > /dev/null 2>&1; }

ensure_pkg() {
    if pkg_installed "$1"; then ok "$1 ya instalado."
    else info "Instalando: $1..."; pkg install -y "$1"
    fi
}

distro_exec() { proot-distro login "$DISTRO_ID" --shared-tmp -- bash -c "$1"; }
distro_installed() { [ -d "$PREFIX/var/lib/proot-distro/installed-rootfs/$1" ]; }

# ══════════════════════════════════════════════════════════════════════════════
# BANNER Y VALIDACIÓN
# ══════════════════════════════════════════════════════════════════════════════

clear
echo -e "${CYAN}${BOLD}"
cat << "BANNER"

  ╔════════════════════════════════════════════════════════════╗
  ║         TERWORKS GUI SETUP v2.0.0                          ║
  ║         Escritorio XFCE4 con Termux:X11                    ║
  ║         Firefox · PulseAudio                               ║
  ╚════════════════════════════════════════════════════════════╝

BANNER
echo -e "${NC}"
info "Iniciando configuración — $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Validar entorno Termux.
if [ ! -d "$PREFIX" ] || ! command -v pkg &>/dev/null; then
    err "Este script debe ejecutarse dentro de Termux."; exit 1
fi
if ! command -v proot-distro &>/dev/null; then
    err "proot-distro no instalado. Ejecuta primero: bash terworks-linux.sh"; exit 1
fi

# Detectar distros instaladas.
INSTALLED_DISTROS=""
for d in debian ubuntu archlinux; do
    distro_installed "$d" && INSTALLED_DISTROS="$INSTALLED_DISTROS $d"
done
if [ -z "$INSTALLED_DISTROS" ]; then
    err "No hay distros instaladas. Ejecuta primero: bash terworks-linux.sh"; exit 1
fi

ok "Pre-requisitos verificados."
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# PAQUETES TERMUX (x11-repo, termux-x11-nightly, pulseaudio)
# ══════════════════════════════════════════════════════════════════════════════

info "Instalando componentes gráficos en Termux..."
echo ""

if ! pkg_installed "x11-repo"; then
    info "Habilitando repositorio x11..."
    pkg install -y x11-repo
    ok "Repositorio x11 habilitado."
else
    ok "Repositorio x11 ya habilitado."
fi

ensure_pkg termux-x11-nightly
ensure_pkg pulseaudio
echo ""

# Verificar APK de Termux:X11.
APK_INSTALLED=true
if ! pm list packages 2>/dev/null | grep -q "com.termux.x11"; then
    APK_INSTALLED=false
    echo ""
    warn "La app Termux:X11 NO está instalada en Android."
    echo -e "  ${BOLD}Descárgala:${NC} ${CYAN}https://github.com/termux/termux-x11/releases/tag/nightly${NC}"
    echo -e "  Instala ${BOLD}app-arm64-v8a-debug.apk${NC} (o ${BOLD}app-universal-debug.apk${NC})"
    echo ""
    echo -e "\n${YELLOW}>>> Instala la APK y presiona ENTER <<<${NC}"
    read -r -p ""
fi

ok "Componentes gráficos de Termux listos."
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# SELECCIÓN DE DISTRIBUCIÓN
# ══════════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}${BOLD}═══ Selección de Distribución para el Escritorio ═════════════${NC}"
echo ""

DISTRO_IDS=(); DISTRO_LABELS=(); menu_idx=1

for d in debian ubuntu archlinux; do
    if echo "$INSTALLED_DISTROS" | grep -q "$d"; then
        DISTRO_IDS+=("$d")
        case "$d" in
            debian)    DISTRO_LABELS+=("Debian") ;;
            ubuntu)    DISTRO_LABELS+=("Ubuntu") ;;
            archlinux) DISTRO_LABELS+=("Arch Linux") ;;
        esac
        echo -e "  ${BOLD}${menu_idx})${NC} ${CYAN}${DISTRO_LABELS[-1]}${NC}"
        menu_idx=$((menu_idx + 1))
    fi
done

total=${#DISTRO_IDS[@]}
echo ""

if [ "$total" -eq 1 ]; then
    DISTRO_ID="${DISTRO_IDS[0]}"; DISTRO_LABEL="${DISTRO_LABELS[0]}"
    info "Única distro disponible: $DISTRO_LABEL — seleccionada automáticamente."
else
    while true; do
        read -r -p "$(echo -e "${CYAN}Selecciona una distro [1-$total]: ${NC}")" distro_choice
        if [[ "$distro_choice" =~ ^[0-9]+$ ]] && [ "$distro_choice" -ge 1 ] && [ "$distro_choice" -le "$total" ]; then
            idx=$((distro_choice - 1))
            DISTRO_ID="${DISTRO_IDS[$idx]}"; DISTRO_LABEL="${DISTRO_LABELS[$idx]}"
            break
        fi
        err "Opción inválida. Ingresa un número del 1 al $total."
    done
fi

# Comandos de paquetes según distro.
case "$DISTRO_ID" in
    debian|ubuntu)
        PKG_UPDATE="export DEBIAN_FRONTEND=noninteractive && apt-get update -y && apt-get upgrade -y"
        PKG_INSTALL="DEBIAN_FRONTEND=noninteractive apt-get install -y" ;;
    archlinux)
        PKG_UPDATE="pacman -Syu --noconfirm"
        PKG_INSTALL="pacman -S --noconfirm" ;;
esac

case "$DISTRO_ID" in
    archlinux) DISTRO_ALIAS="arch" ;;
    *)         DISTRO_ALIAS="$DISTRO_ID" ;;
esac

DISTRO_USER=$(distro_exec "awk -F: '\$3 >= 1000 && \$3 < 65534 {print \$1; exit}' /etc/passwd" 2>/dev/null || echo "dev")

echo ""
info "Distro: $DISTRO_LABEL ($DISTRO_ID) | Usuario: $DISTRO_USER"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# INSTALACIÓN DE XFCE4 + FIREFOX EN LA DISTRO
# ══════════════════════════════════════════════════════════════════════════════

info "Verificando XFCE4 en $DISTRO_LABEL..."

if distro_exec "command -v xfce4-session" &>/dev/null; then
    ok "XFCE4 ya instalado en $DISTRO_LABEL."
    distro_exec "gdk-pixbuf-query-loaders --update-cache 2>/dev/null || true"
else
    info "Instalando XFCE4 + Firefox en $DISTRO_LABEL (~300-500 MB)..."
    echo ""
    distro_exec "$PKG_UPDATE"

    case "$DISTRO_ID" in
        debian|ubuntu)
            distro_exec "$PKG_INSTALL xfce4 xfce4-goodies xfce4-terminal dbus-x11 \
                firefox-esr fonts-noto-color-emoji fonts-liberation2 mesa-utils \
                librsvg2-common adwaita-icon-theme-full" ;;
        archlinux)
            distro_exec "$PKG_INSTALL xfce4 xfce4-goodies xfce4-terminal dbus \
                firefox noto-fonts-emoji ttf-liberation mesa-utils \
                librsvg adwaita-icon-theme" ;;
    esac

    # Fix: sin esto XFCE crashea con "Failed to load image-missing.png".
    info "Reconstruyendo cache de gdk-pixbuf..."
    distro_exec "gdk-pixbuf-query-loaders --update-cache"

    ok "XFCE4 + Firefox instalados en $DISTRO_LABEL."
fi
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# GENERACIÓN DE start-gui.sh (LAUNCHER)
# ══════════════════════════════════════════════════════════════════════════════
# Orquesta: cleanup residual → PulseAudio → Termux:X11 → XFCE4 (bloqueante)
# Al terminar XFCE, cleanup automático via trap EXIT.

info "Generando launcher..."
TERWORKS_DIR="$HOME/.terworks"
mkdir -p "$TERWORKS_DIR"

cat > "$TERWORKS_DIR/start-gui.sh" << 'LAUNCHEREOF'
#!/usr/bin/env bash
# TerWorks GUI Launcher — Generado por terworks-gui.sh
set -uo pipefail

CYAN='\033[0;36m'; GREEN='\033[0;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

info() { echo -e "${CYAN}[GUI]${NC} $1"; }
ok()   { echo -e "${GREEN}[GUI]${NC} $1"; }
err()  { echo -e "${RED}[GUI]${NC} $1"; }

# --- Distro y usuario ---
DISTRO="${1:-${TERWORKS_LINUX:-}}"
if [ -z "$DISTRO" ]; then
    err "No se especificó distro y \$TERWORKS_LINUX no está definido."
    err "Uso: start-gui.sh [debian|ubuntu|archlinux]"
    exit 1
fi

DISTRO_USER="${TERWORKS_LINUX_USER:-}"
if [ -z "$DISTRO_USER" ]; then
    DISTRO_USER=$(proot-distro login "$DISTRO" --shared-tmp -- \
        bash -c "awk -F: '\$3 >= 1000 && \$3 < 65534 {print \$1; exit}' /etc/passwd" 2>/dev/null || echo "dev")
fi

info "Distro: $DISTRO | Usuario: $DISTRO_USER"

# --- Cleanup ---
CLEANUP_DONE=false
cleanup() {
    [ "$CLEANUP_DONE" = "true" ] && return
    CLEANUP_DONE=true
    echo ""
    info "Finalizando entorno gráfico..."
    pkill -f "termux-x11" 2>/dev/null && ok "Termux:X11 detenido." || true
    rm -f /tmp/.X11-unix/X* /tmp/.X*-lock 2>/dev/null || true
    pulseaudio --kill 2>/dev/null && ok "PulseAudio detenido." || true
    am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 2>/dev/null || true
    proot-distro login "$DISTRO" --shared-tmp -- \
        bash -c "pkill -u $DISTRO_USER dbus 2>/dev/null; true" 2>/dev/null || true
    echo ""
    ok "Entorno gráfico finalizado."
    echo -e "  Escribe ${CYAN}gui${NC} para iniciar de nuevo."
    echo ""
}
trap cleanup EXIT SIGTERM SIGINT SIGHUP

# --- Matar procesos residuales ---
pkill -f "termux-x11" 2>/dev/null || true
pulseaudio --kill 2>/dev/null || true
sleep 1
rm -f /tmp/.X11-unix/X* /tmp/.X*-lock 2>/dev/null || true

# --- PulseAudio (TCP audio forwarding) ---
info "Iniciando PulseAudio..."
pulseaudio --start \
    --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" \
    --exit-idle-time=-1 2>/dev/null || true
ok "PulseAudio iniciado (TCP :4713)."

# --- Termux:X11 ---
export XDG_RUNTIME_DIR=${TMPDIR}
info "Iniciando Termux:X11..."
termux-x11 :0 >/dev/null &
X11_PID=$!
sleep 3

if ! kill -0 "$X11_PID" 2>/dev/null; then
    err "Termux:X11 no pudo iniciar. ¿Está la APK instalada?"
    err "Descárgala: https://github.com/termux/termux-x11/releases/tag/nightly"
    exit 1
fi
ok "Termux:X11 iniciado en :0 (PID: $X11_PID)."

# Abrir la app Termux:X11 en Android.
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 || true
sleep 1

# --- Lanzar XFCE4 (BLOQUEANTE) ---
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}Escritorio XFCE4 iniciando en $DISTRO...${NC}"
echo -e "  Para cerrar: ${CYAN}Cerrar Sesión${NC} en XFCE, o ${CYAN}gui-stop${NC} en Termux."
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""

proot-distro login "$DISTRO" --shared-tmp -- /bin/bash -c \
    "export PULSE_SERVER=127.0.0.1 && export XDG_RUNTIME_DIR=\${TMPDIR} && su - $DISTRO_USER -c 'env DISPLAY=:0 startxfce4'" \
    2>/dev/null || true
LAUNCHEREOF

chmod +x "$TERWORKS_DIR/start-gui.sh"
ok "Launcher generado: ~/.terworks/start-gui.sh"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# GENERACIÓN DE stop-gui.sh
# ══════════════════════════════════════════════════════════════════════════════

info "Generando script de parada..."

cat > "$TERWORKS_DIR/stop-gui.sh" << 'STOPEOF'
#!/usr/bin/env bash
# TerWorks GUI Stop — Generado por terworks-gui.sh
GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
ok() { echo -e "${GREEN}[GUI]${NC} $1"; }

echo -e "${CYAN}[GUI]${NC} Deteniendo entorno gráfico..."
echo ""
pkill -f "xfce4-session" 2>/dev/null && ok "XFCE4 session terminada." || true
pkill -f "termux-x11" 2>/dev/null && ok "Termux:X11 detenido." || true
rm -f /tmp/.X11-unix/X* /tmp/.X*-lock 2>/dev/null || true
pulseaudio --kill 2>/dev/null && ok "PulseAudio detenido." || true
am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 2>/dev/null || true
echo ""
ok "Entorno gráfico detenido."
echo -e "  Escribe ${CYAN}gui${NC} para iniciar de nuevo."
echo ""
STOPEOF

chmod +x "$TERWORKS_DIR/stop-gui.sh"
ok "Script de parada: ~/.terworks/stop-gui.sh"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# ALIASES EN .zshrc (bloque TERMUX-GUI)
# ══════════════════════════════════════════════════════════════════════════════

info "Configurando aliases en .zshrc..."

MARKER_START="# --- TERMUX-GUI START ---"
MARKER_END="# --- TERMUX-GUI END ---"
ZSHRC="$HOME/.zshrc"

[ ! -f "$ZSHRC" ] && touch "$ZSHRC"

# Preservar aliases de otras distros antes de limpiar el bloque.
EXISTING_GUI_ALIASES=""
if grep -q "$MARKER_START" "$ZSHRC" 2>/dev/null; then
    EXISTING_GUI_ALIASES=$(sed -n "/$MARKER_START/,/$MARKER_END/p" "$ZSHRC" \
        | grep -E '^alias gui-(debian|ubuntu|arch)=' \
        | grep -v "alias gui-${DISTRO_ALIAS}=" 2>/dev/null || true)
    sed -i "/$MARKER_START/,/$MARKER_END/d" "$ZSHRC"
fi

cat >> "$ZSHRC" << ALIASEOF
$MARKER_START
# TerWorks GUI — Aliases (gestionado por terworks-gui.sh, no editar)
export TERWORKS_GUI_DISTRO="$DISTRO_ID"
export TERWORKS_GUI_USER="$DISTRO_USER"
export TERWORKS_LINUX="\${TERWORKS_LINUX:-$DISTRO_ID}"
export TERWORKS_LINUX_USER="\${TERWORKS_LINUX_USER:-$DISTRO_USER}"

alias gui="bash $HOME/.terworks/start-gui.sh"
alias gui-$DISTRO_ALIAS="bash $HOME/.terworks/start-gui.sh $DISTRO_ID"
$EXISTING_GUI_ALIASES
alias gui-stop="bash $HOME/.terworks/stop-gui.sh"
$MARKER_END
ALIASEOF

ok "Aliases inyectados en ~/.zshrc (bloque TERMUX-GUI)."
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# RESUMEN FINAL
# ══════════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}${BOLD}"
echo "  ╔════════════════════════════════════════════════════════════╗"
echo "  ║         TERWORKS GUI — INSTALACIÓN COMPLETADA              ║"
echo "  ╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BOLD}  Componentes en $DISTRO_LABEL:${NC}"
echo -e "  ─────────────────────────────────────────────────────"
echo -e "  ${GREEN}✓${NC} XFCE4 Desktop + Goodies + Terminal"
echo -e "  ${GREEN}✓${NC} Firefox ESR"
echo -e "  ${GREEN}✓${NC} Fuentes: Noto Emoji + Liberation"
echo -e "  ${GREEN}✓${NC} Mesa Utils"
echo ""

echo -e "${BOLD}  Componentes en Termux:${NC}"
echo -e "  ─────────────────────────────────────────────────────"
echo -e "  ${GREEN}✓${NC} Termux:X11 (servidor X11)"
echo -e "  ${GREEN}✓${NC} PulseAudio (audio TCP)"
if [ "$APK_INSTALLED" = "true" ]; then
    echo -e "  ${GREEN}✓${NC} APK Termux:X11 (detectada)"
else
    echo -e "  ${YELLOW}⚠${NC} APK Termux:X11 — ${YELLOW}NO detectada${NC}"
    echo -e "    ${CYAN}https://github.com/termux/termux-x11/releases/tag/nightly${NC}"
fi
echo ""

echo -e "${BOLD}  Aliases:${NC}"
echo -e "  ─────────────────────────────────────────────────────"
echo -e "  ${CYAN}gui${NC}              Iniciar escritorio (distro activa)"
echo -e "  ${CYAN}gui-$DISTRO_ALIAS${NC}$(printf '%*s' $((14 - ${#DISTRO_ALIAS})) '')Iniciar en $DISTRO_LABEL"
if [ -n "$EXISTING_GUI_ALIASES" ]; then
    echo "$EXISTING_GUI_ALIASES" | while IFS= read -r line; do
        alias_name=$(echo "$line" | grep -oP 'alias \Kgui-\w+')
        [ -n "$alias_name" ] && echo -e "  ${CYAN}$alias_name${NC}$(printf '%*s' $((16 - ${#alias_name})) '')Otra distro"
    done
fi
echo -e "  ${CYAN}gui-stop${NC}         Detener escritorio"
echo ""

echo -e "${BOLD}  Cómo usar:${NC}"
echo -e "  ─────────────────────────────────────────────────────"
echo -e "  ${CYAN}1.${NC} Recarga tu shell:  ${CYAN}source ~/.zshrc${NC}"
echo -e "  ${CYAN}2.${NC} Inicia escritorio: ${CYAN}gui${NC}"
echo -e "  ${CYAN}3.${NC} Para cerrar: Menú → ${BOLD}Cerrar Sesión${NC} o ${CYAN}gui-stop${NC}"
echo ""

echo -e "${BOLD}  Archivos:${NC}"
echo -e "  ─────────────────────────────────────────────────────"
echo -e "  ${CYAN}~/.terworks/start-gui.sh${NC}  Launcher"
echo -e "  ${CYAN}~/.terworks/stop-gui.sh${NC}   Stop script"
echo -e "  ${CYAN}~/.zshrc${NC}                  Aliases (bloque TERMUX-GUI)"
echo ""

echo -e "${GREEN}${BOLD}  ¡Listo! Escribe '${CYAN}gui${GREEN}' para iniciar el escritorio.${NC}"
echo ""

# Recargar aliases si estamos en Zsh.
[ -n "${ZSH_VERSION:-}" ] && source "$ZSHRC" 2>/dev/null || true
