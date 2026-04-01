#!/usr/bin/env bash

# ==============================================================================
#  TERWORKS LINUX v1.0.0
#  Entorno Linux Completo en Termux via proot-distro
# ==============================================================================
#  Distros : Debian · Ubuntu · Arch Linux
#  AI Tools: Opencode (opencode.ai) + Crush (charmbracelet/crush)
#  Shell   : Zsh + Oh My Zsh + Powerlevel10k
#  Editor  : Neovim + NvChad
# ------------------------------------------------------------------------------
#  Complementario a termux-workstation.sh (TerWorks v1.0.0).
#  Instala una distro Linux real dentro de Termux usando proot-distro,
#  configura un entorno de desarrollo independiente con toolchain completo,
#  Zsh + P10K, Neovim + NvChad, y dos asistentes AI (Opencode + Crush).
#
#  ¿Por qué una distro Linux?
#  Termux es un entorno Android con limitaciones (Bionic libc, paths no
#  estándar, paquetes nativos reducidos). Una distro proot ofrece:
#    • glibc estándar    → Compatibilidad total con binarios Linux.
#    • build-essential   → Compilación nativa sin errores de node-gyp/python.
#    • Herramientas CLI  → Todo lo que existe en Linux, sin restricciones.
#    • Entorno aislado   → Experimentar sin afectar la instalación de Termux.
#
#  Los archivos de Termux se acceden dentro de la distro via ~/termux
#  (symlink a /data/data/com.termux/files/home), permitiendo compartir
#  proyectos, claves SSH y recursos sin mezclar configuraciones.
# ------------------------------------------------------------------------------
#  Principios de diseño:
#    • Idempotente  — Re-ejecutable sin duplicar ni romper nada.
#    • Multi-distro — Se puede re-ejecutar para instalar distros adicionales.
#    • Independiente — Configs separadas de Termux (editor, shell, plugins).
#    • Documentado  — Cada bloque explica QUÉ hace y POR QUÉ.
# ------------------------------------------------------------------------------
#  Uso:
#    chmod +x terworks-linux.sh
#    bash terworks-linux.sh
# ==============================================================================

SCRIPT_VERSION="1.0.0"

# ──────────────────────────────────────────────────────────────────────────────
# FASE 0: CONFIGURACIÓN GLOBAL, CONSTANTES Y FUNCIONES AUXILIARES
# ──────────────────────────────────────────────────────────────────────────────
# Misma base que termux-workstation.sh: modo estricto, trap de errores,
# log separado, colores y funciones reutilizables.
#
# Funciones especiales para distro:
#   • distro_exec()      — Ejecuta un comando dentro de la distro como root.
#   • distro_installed() — Verifica si una distro está instalada.
#
# Las funciones distro NO usan --termux-home para mantener las
# configuraciones de la distro independientes de Termux. El acceso a
# archivos de Termux se hace via symlink ~/termux creado en la Fase 5.
# ──────────────────────────────────────────────────────────────────────────────

# --- Modo estricto de Bash ---
set -euo pipefail

# --- Trap de errores ---
trap 'echo -e "\n\033[0;31m[FATAL] Error inesperado en la línea $LINENO. Revisa el log.\033[0m"; exit 1' ERR

# --- Log de ejecución (separado del script principal) ---
LOG_FILE="$HOME/.terworks-linux-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo ""
echo "========== Ejecución: $(date '+%Y-%m-%d %H:%M:%S') | TerWorks Linux v$SCRIPT_VERSION =========="

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

# --- Ejecutar un comando dentro de la distro como root ---
# NO usa --termux-home. Las configuraciones de la distro (.zshrc, .config)
# son completamente independientes de Termux. Los archivos compartidos se
# acceden via symlink ~/termux que se crea durante el aprovisionamiento.
distro_exec() {
    proot-distro login "$DISTRO_ID" -- bash -c "$1"
}

# --- Verificar si la distro está instalada ---
distro_installed() {
    proot-distro list 2>/dev/null | grep -q "Alias: $1" && \
    proot-distro list 2>/dev/null | grep -A2 "Alias: $1" | grep -q "Installed: yes"
}


# ──────────────────────────────────────────────────────────────────────────────
# FASE 1: BANNER, VALIDACIÓN E INSTALACIÓN DE PROOT-DISTRO
# ──────────────────────────────────────────────────────────────────────────────
# Muestra el banner de bienvenida, verifica que el entorno sea válido
# (Termux con pkg funcional) e instala proot-distro si no está presente.
#
# proot-distro es la herramienta oficial de Termux para instalar y gestionar
# distribuciones Linux completas sin necesidad de root, usando proot
# (interceptación de syscalls via ptrace). Las distros corren en user-space
# junto a Termux, compartiendo el kernel de Android.
# ──────────────────────────────────────────────────────────────────────────────

clear
echo -e "${CYAN}${BOLD}"
cat << "BANNER"

  ╔════════════════════════════════════════════════════════════╗
  ║         TERWORKS LINUX SETUP v1.0.0                        ║
  ║         Entorno Linux Completo en Termux                   ║
  ║         Debian · Ubuntu · Arch Linux                       ║
  ║         Opencode · Crush · NvChad · Zsh + P10K             ║
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

# --- Paso 1.2: Instalar proot-distro ---
print_info "Verificando proot-distro..."
ensure_pkg proot-distro
echo ""


# ──────────────────────────────────────────────────────────────────────────────
# FASE 2: SELECCIÓN INTERACTIVA DE DISTRIBUCIÓN LINUX
# ──────────────────────────────────────────────────────────────────────────────
# Presenta un menú con 3 distros estables y bien soportadas en proot-distro.
# Cada opción incluye información relevante: tamaño, gestor de paquetes
# y caso de uso principal.
#
# Distros soportadas:
#   • Debian      — La más estable y compatible con proot. Recomendada.
#   • Ubuntu      — Basada en Debian, más paquetes precompilados y PPAs.
#   • Arch Linux  — Rolling release, paquetes más recientes.
#
# Al seleccionar una distro, se configuran las variables necesarias para
# adaptar los comandos de las fases siguientes (gestor de paquetes, flags,
# método de creación de usuario, detección de Node.js, etc.).
# ──────────────────────────────────────────────────────────────────────────────

echo -e "${CYAN}${BOLD}═══ Selección de Distribución Linux ═══════════════════════════${NC}"
echo ""
echo -e "  ${BOLD}1)${NC} ${CYAN}Debian${NC}      — Estable, máxima compatibilidad con proot ${YELLOW}[Recomendada]${NC}"
echo -e "                  Tamaño: ~500 MB | Gestor: apt"
echo ""
echo -e "  ${BOLD}2)${NC} ${CYAN}Ubuntu${NC}      — Popular, amplio soporte de paquetes y PPAs"
echo -e "                  Tamaño: ~800 MB | Gestor: apt"
echo ""
echo -e "  ${BOLD}3)${NC} ${CYAN}Arch Linux${NC}  — Rolling release, paquetes bleeding-edge"
echo -e "                  Tamaño: ~600 MB | Gestor: pacman"
echo ""

# Bucle de validación: solo acepta 1-3.
while true; do
    read -r -p "$(echo -e "${CYAN}Selecciona una distro [1-3]: ${NC}")" distro_choice
    case "$distro_choice" in
        1)
            DISTRO_ID="debian"
            DISTRO_LABEL="Debian"
            PKG_UPDATE="export DEBIAN_FRONTEND=noninteractive && apt-get update -y && apt-get upgrade -y"
            PKG_INSTALL="DEBIAN_FRONTEND=noninteractive apt-get install -y"
            ;;
        2)
            DISTRO_ID="ubuntu"
            DISTRO_LABEL="Ubuntu"
            PKG_UPDATE="export DEBIAN_FRONTEND=noninteractive && apt-get update -y && apt-get upgrade -y"
            PKG_INSTALL="DEBIAN_FRONTEND=noninteractive apt-get install -y"
            ;;
        3)
            DISTRO_ID="archlinux"
            DISTRO_LABEL="Arch Linux"
            PKG_UPDATE="pacman -Syu --noconfirm"
            PKG_INSTALL="pacman -S --noconfirm"
            ;;
        *)
            print_error "Opción inválida. Ingresa un número del 1 al 3."
            continue
            ;;
    esac
    break
done

echo ""
print_info "Distro seleccionada: $DISTRO_LABEL ($DISTRO_ID)"
echo ""


# ──────────────────────────────────────────────────────────────────────────────
# FASE 3: INSTALACIÓN DE LA DISTRIBUCIÓN
# ──────────────────────────────────────────────────────────────────────────────
# Descarga e instala la distro seleccionada usando proot-distro.
# El rootfs se almacena en $PREFIX/var/lib/proot-distro/installed-rootfs/.
#
# Idempotencia:
#   • Verifica si la distro ya está instalada antes de descargar.
#   • Si ya existe, pregunta si el usuario desea reconfigurar o saltar.
#
# Nota sobre proot:
#   proot intercepta syscalls via ptrace para simular un entorno root.
#   NO es root real — es una emulación en user-space. Esto implica:
#     • ~10-30% de overhead en rendimiento vs nativo.
#     • No se pueden usar kernel modules, systemd, ni Docker runtime.
#     • Los procesos mueren al cerrar la sesión (no hay daemons persistentes).
#   Pero SÍ permite instalar prácticamente cualquier software CLI de Linux.
# ──────────────────────────────────────────────────────────────────────────────

print_info "Verificando instalación de $DISTRO_LABEL..."

if distro_installed "$DISTRO_ID"; then
    print_success "$DISTRO_LABEL ya está instalada."
    echo ""
    echo -e "  ${BOLD}1)${NC} Reconfigurar (actualizar paquetes, verificar herramientas)"
    echo -e "  ${BOLD}2)${NC} Saltar instalación (solo actualizar aliases en Termux)"
    echo ""
    read -r -p "$(echo -e "${CYAN}¿Qué deseas hacer? [1-2]: ${NC}")" reconfig_choice
    case "$reconfig_choice" in
        1) print_info "Reconfigurando $DISTRO_LABEL..." ;;
        *)
            print_info "Saltando configuración de $DISTRO_LABEL."
            print_info "Pasando a la inyección de aliases..."
            # Detectar usuario no-root existente para los aliases.
            DISTRO_USER=$(distro_exec "awk -F: '\$3 >= 1000 && \$3 < 65534 {print \$1; exit}' /etc/passwd" 2>/dev/null || echo "dev")
            SKIP_TO_ALIASES=true
            ;;
    esac
else
    print_info "Instalando $DISTRO_LABEL (esto puede tomar varios minutos)..."
    proot-distro install "$DISTRO_ID"
    print_success "$DISTRO_LABEL instalada correctamente."
fi

SKIP_TO_ALIASES="${SKIP_TO_ALIASES:-false}"
echo ""


# ──────────────────────────────────────────────────────────────────────────────
# FASE 4: NOMBRE DE USUARIO
# ──────────────────────────────────────────────────────────────────────────────
# Solicita al usuario el nombre para la cuenta no-root dentro de la distro.
# Este usuario tendrá sudo NOPASSWD para evitar fricción en un entorno proot
# (donde root ya es simulado y no tiene privilegios reales del kernel).
# ──────────────────────────────────────────────────────────────────────────────

if [ "$SKIP_TO_ALIASES" = "false" ]; then

echo ""
read -r -p "$(echo -e "${CYAN}Nombre de usuario para $DISTRO_LABEL [dev]: ${NC}")" user_input
DISTRO_USER="${user_input:-dev}"

# Validar que no sea root ni vacío.
if [ -z "$DISTRO_USER" ] || [ "$DISTRO_USER" = "root" ]; then
    print_error "Nombre de usuario inválido (no puede ser vacío ni 'root')."
    exit 1
fi

print_info "Usuario seleccionado: $DISTRO_USER"
echo ""


# ──────────────────────────────────────────────────────────────────────────────
# FASE 5: APROVISIONAMIENTO INTERNO DE LA DISTRIBUCIÓN
# ──────────────────────────────────────────────────────────────────────────────
# Esta es la fase central del script. Genera un script de aprovisionamiento
# que se inyecta en el rootfs de la distro y se ejecuta via proot-distro login.
#
# El script tiene dos secciones:
#   • Sección Root  — Actualiza sistema, instala toolchain, Node.js, Neovim,
#                     crea usuario y configura sudo.
#   • Sección User  — Configura Zsh/OMZ/P10K, aliases, NvChad, Opencode, Crush.
#                     Se ejecuta via `su - $DISTRO_USER` para que las configs
#                     se generen en el home correcto del usuario.
#
# Por qué generar un script en vez de múltiples distro_exec():
#   • Eficiencia: Un solo login a proot en vez de docenas.
#   • Contexto: Variables de entorno y estado se mantienen entre comandos.
#   • Fiabilidad: Si falla, el script temporal se puede inspeccionar.
#   • Heredoc: Permite generar contenido dinámico (case por distro).
#
# Nota sobre --termux-home:
#   Este script NO usa --termux-home en distro_exec(). Las configuraciones
#   dentro de la distro (.zshrc, .config/nvim, .oh-my-zsh) son INDEPENDIENTES
#   de Termux. El acceso a archivos compartidos (proyectos, SSH keys) se hace
#   via un symlink ~/termux → /data/data/com.termux/files/home creado en la
#   sección del usuario. Esto evita:
#     • Conflictos entre la .zshrc de Termux y la de la distro.
#     • Que plugins de OMZ/P10K de Termux interfieran con los de la distro.
#     • Que NvChad sobrescriba la configuración de LazyVim de Termux.
# ──────────────────────────────────────────────────────────────────────────────

print_info "Generando script de aprovisionamiento para $DISTRO_LABEL..."

DISTRO_ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/$DISTRO_ID"
INIT_SCRIPT="$DISTRO_ROOTFS/root/init_terworks.sh"

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  INICIO DEL SCRIPT DE APROVISIONAMIENTO (se ejecuta DENTRO de la distro)   ║
# ╚════════════════════════════════════════════════════════════════════════════╝
cat << PROVEOF > "$INIT_SCRIPT"
#!/bin/bash
# ==============================================================================
# TerWorks Linux — Script de Aprovisionamiento Interno
# Generado automáticamente por terworks-linux.sh v$SCRIPT_VERSION
# Distro: $DISTRO_LABEL ($DISTRO_ID) | Usuario: $DISTRO_USER
# Fecha: $(date '+%Y-%m-%d %H:%M:%S')
# ==============================================================================

set -e

# --- Colores para salida dentro de la distro ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "\${BLUE}[INFO]\${NC} \$1"; }
ok()      { echo -e "\${GREEN}[  OK]\${NC} \$1"; }
warn()    { echo -e "\${YELLOW}[AVISO]\${NC} \$1"; }

# ══════════════════════════════════════════════════════════════
# SECCIÓN ROOT — Configuración del sistema
# ══════════════════════════════════════════════════════════════

# --- 5.1: Actualizar paquetes del sistema ---
info "Actualizando paquetes de $DISTRO_LABEL..."
$PKG_UPDATE
ok "Sistema actualizado."

# --- 5.2: Instalar paquetes base + toolchain completo ---
# Incluye: sudo, git, curl/wget, compiladores (gcc, g++, make), python3,
# utilidades (jq, unzip, tar), certificados y zsh.
# Esto resuelve problemas como node-gyp que fallan en Termux nativo
# porque aquí se dispone de glibc estándar y build-essential completo.
info "Instalando paquetes base y toolchain..."
case "$DISTRO_ID" in
    debian|ubuntu)
        $PKG_INSTALL sudo curl wget git zsh locales python3 gcc g++ make \\
            unzip jq xz-utils build-essential ca-certificates tar gzip nano
        # Resolver problemas de certificados HTTPS en proot.
        update-ca-certificates 2>/dev/null || true
        ;;
    archlinux)
        $PKG_INSTALL sudo curl wget git zsh python gcc make \\
            unzip jq xz tar gzip base-devel ca-certificates nano
        ;;
esac
ok "Toolchain instalado."

# --- 5.3: Configurar locale UTF-8 ---
# Necesario para que Powerlevel10k muestre iconos correctamente y para
# evitar warnings de locale en herramientas como git y Python.
info "Configurando locale UTF-8..."
case "$DISTRO_ID" in
    debian|ubuntu)
        sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen 2>/dev/null || true
        locale-gen 2>/dev/null || true
        update-locale LANG=en_US.UTF-8 2>/dev/null || true
        ;;
    archlinux)
        sed -i '/en_US.UTF-8/s/^#//g' /etc/locale.gen 2>/dev/null || true
        locale-gen 2>/dev/null || true
        echo "LANG=en_US.UTF-8" > /etc/locale.conf 2>/dev/null || true
        ;;
esac
export LANG=en_US.UTF-8
ok "Locale configurado."

# --- 5.4: Instalar Node.js LTS ---
# Necesario para npm (gestor de paquetes de opencode-ai) y para
# herramientas JavaScript/TypeScript dentro de la distro.
info "Instalando Node.js LTS..."
case "$DISTRO_ID" in
    debian|ubuntu)
        if ! command -v node >/dev/null 2>&1; then
            curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
            $PKG_INSTALL nodejs
        fi
        ;;
    archlinux)
        $PKG_INSTALL nodejs npm
        ;;
esac
if command -v node >/dev/null 2>&1; then
    ok "Node.js instalado: \$(node --version)"
else
    warn "Node.js no pudo instalarse. Algunas herramientas no estarán disponibles."
fi

# --- 5.5: Instalar Neovim desde binarios oficiales ---
# En proot es mejor descargar el binario oficial de GitHub que usar la
# versión de los repositorios (que suele estar desactualizada).
# Se detecta la arquitectura del dispositivo automáticamente.
info "Instalando Neovim..."
if ! command -v nvim >/dev/null 2>&1; then
    ARCH=\$(uname -m)
    NVIM_URL=""
    if [ "\$ARCH" = "aarch64" ]; then
        NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-arm64.tar.gz"
    elif [ "\$ARCH" = "x86_64" ]; then
        NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz"
    fi

    if [ -n "\$NVIM_URL" ]; then
        cd /tmp
        curl -fsSL "\$NVIM_URL" -o nvim.tar.gz
        tar -xzf nvim.tar.gz
        cp -r nvim-*/bin nvim-*/lib nvim-*/share /usr/
        rm -rf /tmp/nvim*
        ok "Neovim instalado desde binario oficial."
    else
        warn "Arquitectura \$ARCH no tiene binario precompilado. Instalando desde repos..."
        case "$DISTRO_ID" in
            debian|ubuntu) $PKG_INSTALL neovim ;;
            archlinux)     $PKG_INSTALL neovim ;;
        esac
    fi
else
    ok "Neovim ya está instalado: \$(nvim --version | head -1)"
fi

# --- 5.6: Crear usuario no-root ---
# En un entorno proot el "root" no tiene privilegios reales del kernel,
# pero crear un usuario separado simula un entorno Linux más realista
# y permite configuraciones de usuario aisladas.
info "Configurando usuario '$DISTRO_USER'..."
if ! id "$DISTRO_USER" >/dev/null 2>&1; then
    useradd -m -s /usr/bin/zsh "$DISTRO_USER"
    ok "Usuario '$DISTRO_USER' creado."
else
    ok "Usuario '$DISTRO_USER' ya existe."
fi

# --- 5.7: Configurar sudo sin contraseña ---
# En proot no hay riesgo de seguridad real (root es simulado).
# NOPASSWD evita fricción al instalar paquetes o ejecutar herramientas.
info "Configurando sudo NOPASSWD..."
mkdir -p /etc/sudoers.d
echo "$DISTRO_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$DISTRO_USER
chmod 440 /etc/sudoers.d/$DISTRO_USER
ok "sudo configurado para '$DISTRO_USER' (sin contraseña)."


# ══════════════════════════════════════════════════════════════
# SECCIÓN USUARIO — Configuración personal
# ══════════════════════════════════════════════════════════════
# Todo lo que sigue se ejecuta como el usuario no-root para que las
# configuraciones (OMZ, P10K, NvChad) se generen en su home correcto.

# Pre-computar alias de update según la distro (se inyecta como string literal
# dentro del heredoc single-quoted, que no expande variables).
case "$DISTRO_ID" in
    debian|ubuntu)
        UPDATE_ALIAS='alias update="sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt clean"'
        ;;
    archlinux)
        UPDATE_ALIAS='alias update="sudo pacman -Syu --noconfirm"'
        ;;
esac

# Escribir el alias de update en un archivo temporal que el user script leerá.
echo "\$UPDATE_ALIAS" > /tmp/terworks_update_alias.txt

cat << 'USEREOF' > /home/$DISTRO_USER/setup_user.sh
#!/bin/bash
set -e

info()    { echo -e "\033[0;34m[INFO]\033[0m \$1"; }
ok()      { echo -e "\033[0;32m[  OK]\033[0m \$1"; }
warn()    { echo -e "\033[1;33m[AVISO]\033[0m \$1"; }

# --- 5.8: Crear symlink a Home de Termux ---
# Permite acceder a ~/www, ~/.ssh, proyectos y recursos de Termux
# desde dentro de la distro sin mezclar configuraciones.
TERMUX_HOME="/data/data/com.termux/files/home"
if [ ! -L "\$HOME/termux" ] && [ ! -d "\$HOME/termux" ]; then
    ln -s "\$TERMUX_HOME" "\$HOME/termux"
    ok "Enlace creado: ~/termux → Home de Termux"
else
    ok "~/termux ya existe."
fi

# --- 5.9: Instalar Oh My Zsh ---
if [ ! -d "\$HOME/.oh-my-zsh" ]; then
    info "Instalando Oh My Zsh..."
    RUNZSH=no CHSH=no sh -c "\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    ok "Oh My Zsh instalado."
else
    ok "Oh My Zsh ya está instalado."
fi

ZSH_CUSTOM="\${ZSH_CUSTOM:-\$HOME/.oh-my-zsh/custom}"

# --- 5.10: Instalar Plugins de Zsh ---
if [ ! -d "\$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    info "Instalando plugin: zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "\$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [ ! -d "\$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    info "Instalando plugin: zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "\$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# --- 5.11: Instalar Powerlevel10k ---
if [ ! -d "\$ZSH_CUSTOM/themes/powerlevel10k" ]; then
    info "Instalando tema Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "\$ZSH_CUSTOM/themes/powerlevel10k"
fi

# --- 5.12: Configurar .zshrc ---
if [ -f "\$HOME/.zshrc" ]; then
    # Activar tema Powerlevel10k.
    sed -i 's/ZSH_THEME=".*"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "\$HOME/.zshrc"

    # Activar plugins (solo si tiene el valor por defecto).
    if ! grep -q "zsh-autosuggestions" "\$HOME/.zshrc"; then
        sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting z dirhistory sudo)/' "\$HOME/.zshrc"
    fi

    # Inyectar aliases de productividad si no existen.
    if ! grep -q "# --- TERWORKS-LINUX-ALIASES ---" "\$HOME/.zshrc"; then
        cat << 'ALIASEOF' >> "\$HOME/.zshrc"

# --- TERWORKS-LINUX-ALIASES ---
# ══════════════════════════════════════════════════════════════
# Aliases de productividad — TerWorks Linux
# Generados automáticamente por terworks-linux.sh
# ══════════════════════════════════════════════════════════════

# ── Navegación ──
alias ll="ls -lh --color=auto"
alias la="ls -lah --color=auto"
alias cls="clear"

# ── Editor (Neovim) ──
alias v="nvim"
alias vi="nvim"
alias vim="nvim"
alias nv="nvim ."

# ── Git ──
alias gs="git status"
alias ga="git add ."
alias gc="git commit -m"
alias gp="git push"
alias gl="git pull"
alias glog="git log --oneline --graph --all"
alias gd="git diff"

# ── Navegación a Termux ──
# Accede al home de Termux y a la carpeta de proyectos web.
alias termux="cd ~/termux"
alias dev="cd ~/termux/www && nvim ."
alias projects="cd ~/termux/www"

# ── AI Tools ──
# Opencode y Crush están instalados globalmente.
# Para configurar, exporta tus API keys:
#   export OPENAI_API_KEY="sk-..."
#   export ANTHROPIC_API_KEY="sk-ant-..."
# Agrega los exports arriba de esta sección en tu .zshrc.

ALIASEOF

        # Inyectar alias de update específico por distro (pre-computado por root).
        if [ -f /tmp/terworks_update_alias.txt ]; then
            cat /tmp/terworks_update_alias.txt >> "\$HOME/.zshrc"
            rm -f /tmp/terworks_update_alias.txt
        fi
        echo '# --- END-TERWORKS-LINUX-ALIASES ---' >> "\$HOME/.zshrc"
        ok "Aliases de productividad inyectados en .zshrc"
    else
        ok "Aliases de productividad ya existen en .zshrc"
    fi
fi

# --- 5.13: Instalar NvChad ---
# NvChad es más estable que LazyVim en entornos proot y proporciona
# un IDE rápido con autocompletado, temas, file explorer y LSPs via Mason.
# Se instala de forma independiente al LazyVim de Termux.
NVIM_DIR="\$HOME/.config/nvim"
if [ ! -d "\$NVIM_DIR" ]; then
    info "Instalando NvChad (IDE rápido y estable)..."
    git clone https://github.com/NvChad/starter "\$NVIM_DIR"
    rm -rf "\$NVIM_DIR/.git"
    ok "NvChad instalado."
else
    ok "Configuración de Neovim ya existe."
fi

# --- 5.14: Instalar Opencode (opencode.ai) ---
# CLI de codificación asistida por IA. Soporta múltiples proveedores
# (OpenAI, Anthropic, etc.) y puede editar archivos, ejecutar comandos,
# navegar repos y explicar código.
if ! command -v opencode >/dev/null 2>&1; then
    info "Instalando Opencode AI CLI..."
    # Intentar via npm primero (más confiable con Node.js ya instalado).
    if command -v npm >/dev/null 2>&1; then
        npm install -g opencode-ai 2>/dev/null && ok "Opencode instalado via npm." || {
            warn "npm falló, intentando instalador directo..."
            curl -fsSL https://opencode.ai/install | bash && ok "Opencode instalado via curl." || {
                warn "No se pudo instalar Opencode automáticamente."
                warn "Instálalo manualmente: npm i -g opencode-ai"
            }
        }
    else
        curl -fsSL https://opencode.ai/install | bash && ok "Opencode instalado via curl." || {
            warn "No se pudo instalar Opencode automáticamente."
            warn "Instálalo manualmente: curl -fsSL https://opencode.ai/install | bash"
        }
    fi
else
    ok "Opencode ya está instalado: \$(opencode --version 2>/dev/null | head -1 || echo 'versión desconocida')"
fi

# --- 5.15: Instalar Crush (charmbracelet/crush) ---
# Crush es el sucesor activo de opencode. Asistente AI de terminal con TUI
# interactiva (Bubble Tea), soporte multi-modelo, herramientas de edición,
# grep, bash, LSP y MCP. Binario Go sin dependencias de runtime.
if ! command -v crush >/dev/null 2>&1; then
    info "Instalando Crush (AI Coding Assistant)..."

    # Detectar arquitectura del dispositivo.
    ARCH=\$(uname -m)
    case "\$ARCH" in
        aarch64) CRUSH_ARCH="arm64" ;;
        armv7l)  CRUSH_ARCH="arm" ;;
        x86_64)  CRUSH_ARCH="amd64" ;;
        i686)    CRUSH_ARCH="386" ;;
        *)       CRUSH_ARCH="arm64" ;;
    esac

    # Intentar descargar binario precompilado desde GitHub Releases.
    LATEST_URL=\$(curl -fsSL -o /dev/null -w '%{redirect_url}' \
        "https://github.com/charmbracelet/crush/releases/latest" 2>/dev/null || true)

    CRUSH_OK=false
    if [ -n "\$LATEST_URL" ]; then
        VERSION=\$(echo "\$LATEST_URL" | grep -oP 'v[\d.]+\$' || echo "")
        if [ -n "\$VERSION" ]; then
            VERSION_NUM="\${VERSION#v}"
            TARBALL="crush_\${VERSION_NUM}_Linux_\${CRUSH_ARCH}.tar.gz"
            DL_URL="https://github.com/charmbracelet/crush/releases/download/\${VERSION}/\${TARBALL}"

            cd /tmp
            if curl -fsSL "\$DL_URL" -o crush.tar.gz 2>/dev/null; then
                tar xzf crush.tar.gz 2>/dev/null || true
                # GoReleaser puede generar el binario directamente o en subcarpeta.
                if [ -f "crush" ]; then
                    sudo mv crush /usr/local/bin/crush
                elif [ -f "crush_\${VERSION_NUM}_Linux_\${CRUSH_ARCH}/crush" ]; then
                    sudo mv "crush_\${VERSION_NUM}_Linux_\${CRUSH_ARCH}/crush" /usr/local/bin/crush
                else
                    FOUND=\$(find /tmp -maxdepth 2 -name "crush" -type f 2>/dev/null | head -1)
                    if [ -n "\$FOUND" ]; then
                        sudo mv "\$FOUND" /usr/local/bin/crush
                    fi
                fi
                rm -f /tmp/crush.tar.gz
                if command -v crush >/dev/null 2>&1; then
                    sudo chmod +x /usr/local/bin/crush
                    CRUSH_OK=true
                fi
            fi
        fi
    fi

    if [ "\$CRUSH_OK" = "true" ]; then
        ok "Crush instalado: \$(crush --version 2>/dev/null | head -1 || echo '\$VERSION')"
    else
        warn "No se pudo descargar el binario de Crush."
        if command -v npm >/dev/null 2>&1; then
            info "Intentando instalación via npm..."
            npm install -g @charmland/crush 2>/dev/null && ok "Crush instalado via npm." || {
                warn "No se pudo instalar Crush automáticamente."
                warn "Instálalo manualmente dentro de la distro."
            }
        else
            warn "npm no disponible. Instala Crush manualmente."
            warn "Visita: https://github.com/charmbracelet/crush"
        fi
    fi
else
    ok "Crush ya está instalado: \$(crush --version 2>/dev/null | head -1 || echo 'versión desconocida')"
fi

echo ""
ok "Aprovisionamiento de usuario completado."
USEREOF

# Ejecutar el script del usuario con los permisos correctos.
chmod +x /home/$DISTRO_USER/setup_user.sh
info "Ejecutando configuración del usuario '$DISTRO_USER'..."
su - $DISTRO_USER -c "bash /home/$DISTRO_USER/setup_user.sh"
rm -f /home/$DISTRO_USER/setup_user.sh

echo ""
ok "Aprovisionamiento de $DISTRO_LABEL completado."
PROVEOF
# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  FIN DEL SCRIPT DE APROVISIONAMIENTO                                       ║
# ╚════════════════════════════════════════════════════════════════════════════╝

# Ejecutar el script de aprovisionamiento dentro de la distro.
chmod +x "$INIT_SCRIPT"

print_info "─────────────────────────────────────────────────────────────"
print_info "Ejecutando aprovisionamiento dentro de $DISTRO_LABEL..."
print_info "Esto puede tomar varios minutos (descarga de paquetes, repos, binarios)."
print_info "─────────────────────────────────────────────────────────────"
echo ""

proot-distro login "$DISTRO_ID" -- bash /root/init_terworks.sh
rm -f "$INIT_SCRIPT"

print_success "Aprovisionamiento de $DISTRO_LABEL completado."
echo ""

# --- Fin del bloque condicional de SKIP_TO_ALIASES ---
fi


# ──────────────────────────────────────────────────────────────────────────────
# FASE 6: INYECCIÓN DE ALIASES EN TERMUX (.zshrc)
# ──────────────────────────────────────────────────────────────────────────────
# Agrega aliases al .zshrc de Termux para acceder rápidamente a la distro
# sin recordar comandos largos de proot-distro.
#
# Estrategia de marcadores:
#   Bloque separado del primer script: TERMUX-LINUX START/END
#   (el primer script usa TERMUX-WS START/END).
#   Ambos bloques coexisten en .zshrc sin interferirse.
#   Al re-ejecutar, el bloque se elimina y reescribe limpio.
#
# Aliases inyectados:
#   • <distro_name> → Entrada directa a la distro como usuario.
#   • linux         → Alias genérico que apunta a la última distro instalada.
#   • linux-root    → Entrar como root (para administración).
#   • linux-run     → Ejecutar un comando dentro de la distro sin entrar.
#   • linux-list    → Listar distros instaladas.
#   • linux-backup  → Hacer backup de la distro activa.
#   • linux-reset   → Resetear la distro activa (con confirmación).
#
# Multi-distro:
#   Si el usuario ejecuta el script varias veces con distros diferentes,
#   cada alias individual se mantiene. La variable TERWORKS_LINUX y los
#   aliases genéricos apuntan a la ÚLTIMA distro instalada.
# ──────────────────────────────────────────────────────────────────────────────

print_info "Configurando aliases de acceso rápido en Termux..."

MARKER_START="# --- TERMUX-LINUX START ---"
MARKER_END="# --- TERMUX-LINUX END ---"
ZSHRC="$HOME/.zshrc"

# Verificar que .zshrc existe (debería existir si se ejecutó termux-workstation.sh).
if [ ! -f "$ZSHRC" ]; then
    print_warning ".zshrc no encontrado. Creando uno básico..."
    touch "$ZSHRC"
fi

# --- Recolectar distros previamente instaladas ---
# Si ya existía un bloque TERMUX-LINUX, extraer los aliases de distros
# anteriores para preservarlos al reescribir el bloque.
EXISTING_DISTRO_ALIASES=""
if grep -q "$MARKER_START" "$ZSHRC" 2>/dev/null; then
    # Extraer líneas de alias de distros individuales (formato: alias debian="...")
    EXISTING_DISTRO_ALIASES=$(sed -n "/$MARKER_START/,/$MARKER_END/p" "$ZSHRC" \
        | grep -E '^alias (debian|ubuntu|arch)=' \
        | grep -v "alias ${DISTRO_ALIAS:-}=" 2>/dev/null || true)

    # Eliminar bloque anterior para reescritura limpia.
    sed -i "/$MARKER_START/,/$MARKER_END/d" "$ZSHRC"
fi

# --- Determinar el alias de entrada para la distro seleccionada ---
case "$DISTRO_ID" in
    archlinux) DISTRO_ALIAS="arch" ;;
    *)         DISTRO_ALIAS="$DISTRO_ID" ;;
esac

# Escribir el bloque completo de aliases.
cat >> "$ZSHRC" << ALIASEOF
$MARKER_START
# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  TerWorks Linux — Aliases de Acceso a Linux                                ║
# ║  Este bloque es gestionado automáticamente por terworks-linux.sh           ║
# ║  NO editar manualmente: los cambios se perderán al re-ejecutar.            ║
# ║  Para aliases personalizados, agrégalos DEBAJO de "TERMUX-LINUX END".      ║
# ╚════════════════════════════════════════════════════════════════════════════╝

# ══════════════════════════════════════════════════════════════
# 🐧  DISTRO ACTIVA
# ══════════════════════════════════════════════════════════════
# Última distro configurada. Usada por los aliases genéricos.
export TERWORKS_LINUX="$DISTRO_ID"
export TERWORKS_LINUX_USER="$DISTRO_USER"

# ══════════════════════════════════════════════════════════════
# 🚪  ENTRADA DIRECTA A DISTROS
# ══════════════════════════════════════════════════════════════
# Alias específico para la distro recién instalada.
alias $DISTRO_ALIAS="proot-distro login $DISTRO_ID -- su - $DISTRO_USER"
$EXISTING_DISTRO_ALIASES

# ══════════════════════════════════════════════════════════════
# 🔧  ALIASES GENÉRICOS (apuntan a la distro activa)
# ══════════════════════════════════════════════════════════════
# linux: Entrar a la distro activa como usuario.
alias linux="proot-distro login \$TERWORKS_LINUX -- su - \$TERWORKS_LINUX_USER"

# linux-root: Entrar como root (para tareas de administración).
alias linux-root="proot-distro login \$TERWORKS_LINUX"

# linux-run: Ejecutar un comando dentro de la distro sin entrar.
# Uso: linux-run 'apt list --installed'
linux-run() { proot-distro login "\$TERWORKS_LINUX" -- bash -c "\$*"; }

# linux-list: Listar distros instaladas en proot-distro.
alias linux-list="proot-distro list"

# linux-backup: Crear backup comprimido de la distro activa.
alias linux-backup="proot-distro backup \$TERWORKS_LINUX"

# linux-reset: Resetear la distro activa a su estado original.
# ⚠️  Esto ELIMINA toda la configuración de la distro.
alias linux-reset="echo '⚠️  Esto reseteará \$TERWORKS_LINUX a su estado original.' && read -r -p '¿Continuar? [s/N]: ' r && [[ \\\$r =~ ^[sS]\$ ]] && proot-distro reset \$TERWORKS_LINUX || echo 'Cancelado.'"

$MARKER_END
ALIASEOF

print_success "Aliases inyectados en ~/.zshrc (bloque TERMUX-LINUX)."
echo ""


# ──────────────────────────────────────────────────────────────────────────────
# FASE 7: RESUMEN FINAL E INSTRUCCIONES
# ──────────────────────────────────────────────────────────────────────────────
# Muestra un resumen completo de lo instalado, aliases disponibles e
# instrucciones para configurar las herramientas AI.
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo -e "${CYAN}${BOLD}"
echo "  ╔════════════════════════════════════════════════════════════╗"
echo "  ║         TERWORKS LINUX — INSTALACIÓN COMPLETADA            ║"
echo "  ╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BOLD}  Componentes Instalados en $DISTRO_LABEL:${NC}"
echo -e "  ─────────────────────────────────────────────────────"
echo -e "  ${GREEN}✓${NC} $DISTRO_LABEL ($DISTRO_ID) via proot-distro"
echo -e "  ${GREEN}✓${NC} Usuario: ${CYAN}$DISTRO_USER${NC} (sudo NOPASSWD)"
echo -e "  ${GREEN}✓${NC} Toolchain: gcc, g++, make, python3, build-essential"
echo -e "  ${GREEN}✓${NC} Node.js LTS + npm"
echo -e "  ${GREEN}✓${NC} Neovim + NvChad (IDE)"
echo -e "  ${GREEN}✓${NC} Zsh + Oh My Zsh + Powerlevel10k"
echo -e "  ${GREEN}✓${NC} Plugins: autosuggestions, syntax-highlighting, z, dirhistory"
echo -e "  ${GREEN}✓${NC} Opencode AI CLI (opencode.ai)"
echo -e "  ${GREEN}✓${NC} Crush (charmbracelet/crush)"
echo -e "  ${GREEN}✓${NC} Enlace ~/termux → Home de Termux"
echo ""

echo -e "${BOLD}  Aliases en Termux (para acceder a la distro):${NC}"
echo -e "  ─────────────────────────────────────────────────────"
echo -e "  ${CYAN}$DISTRO_ALIAS${NC}          Entrar a $DISTRO_LABEL como $DISTRO_USER"
echo -e "  ${CYAN}linux${NC}            Entrar a la distro activa como usuario"
echo -e "  ${CYAN}linux-root${NC}       Entrar como root (administración)"
echo -e "  ${CYAN}linux-run${NC} 'cmd'  Ejecutar un comando sin entrar"
echo -e "  ${CYAN}linux-list${NC}       Listar distros instaladas"
echo -e "  ${CYAN}linux-backup${NC}     Backup de la distro activa"
echo -e "  ${CYAN}linux-reset${NC}      Resetear distro (con confirmación)"
echo ""

echo -e "${BOLD}  Aliases dentro de $DISTRO_LABEL:${NC}"
echo -e "  ─────────────────────────────────────────────────────"
echo -e "  ${CYAN}v / vi / vim${NC}     Neovim"
echo -e "  ${CYAN}nv${NC}               Neovim en directorio actual"
echo -e "  ${CYAN}ll / la${NC}          Listado detallado"
echo -e "  ${CYAN}gs / ga / gc / gp / gl${NC}  Git shortcuts"
echo -e "  ${CYAN}termux${NC}           Ir al home de Termux"
echo -e "  ${CYAN}dev${NC}              Abrir proyectos en ~/termux/www"
echo -e "  ${CYAN}update${NC}           Actualizar paquetes del sistema"
echo -e "  ${CYAN}opencode${NC}         Iniciar Opencode AI"
echo -e "  ${CYAN}crush${NC}            Iniciar Crush AI"
echo ""

echo -e "${YELLOW}${BOLD}  ⚙️  Configurar Herramientas AI:${NC}"
echo -e "  ─────────────────────────────────────────────────────"
echo -e "  Las herramientas AI necesitan una API key para funcionar."
echo -e "  Entra a tu distro y agrega las variables a tu .zshrc:"
echo ""
echo -e "  ${CYAN}$DISTRO_ALIAS${NC}                        # Entrar a la distro"
echo -e "  ${CYAN}echo 'export OPENAI_API_KEY=\"sk-...\"' >> ~/.zshrc${NC}"
echo -e "  ${CYAN}echo 'export ANTHROPIC_API_KEY=\"sk-ant-...\"' >> ~/.zshrc${NC}"
echo -e "  ${CYAN}source ~/.zshrc${NC}"
echo ""
echo -e "  Proveedores soportados por Opencode: OpenAI, Anthropic, Google"
echo -e "  Proveedores soportados por Crush: Anthropic, OpenAI, Gemini, Copilot, Ollama"
echo ""

echo -e "${BOLD}  Ejemplo de uso rápido:${NC}"
echo -e "  ─────────────────────────────────────────────────────"
echo -e "  ${CYAN}$DISTRO_ALIAS${NC}              # Entrar a $DISTRO_LABEL"
echo -e "  ${CYAN}dev${NC}                  # Ir a ~/termux/www y abrir Neovim"
echo -e "  ${CYAN}opencode${NC}             # Asistente AI (Opencode)"
echo -e "  ${CYAN}crush${NC}                # Asistente AI (Crush)"
echo -e "  ${CYAN}exit${NC}                 # Volver a Termux"
echo ""

echo -e "${BOLD}  Multi-distro:${NC}"
echo -e "  ─────────────────────────────────────────────────────"
echo -e "  Puedes re-ejecutar este script para instalar distros adicionales."
echo -e "  Los aliases de cada distro se preservan automáticamente."
echo -e "  Los aliases genéricos (linux, linux-root...) apuntan a la última."
echo ""

echo -e "${BOLD}  Archivos y logs:${NC}"
echo -e "  ─────────────────────────────────────────────────────"
echo -e "  Log de instalación: ${CYAN}~/.terworks-linux-setup.log${NC}"
echo -e "  Aliases de Termux:  ${CYAN}~/.zshrc${NC} (bloque TERMUX-LINUX)"
echo -e "  Rootfs de distro:   ${CYAN}\$PREFIX/var/lib/proot-distro/installed-rootfs/$DISTRO_ID${NC}"
echo ""

echo -e "${GREEN}${BOLD}  ¡TerWorks Linux está listo! Escribe '${CYAN}$DISTRO_ALIAS${GREEN}' para comenzar.${NC}"
echo ""

# Recargar .zshrc si estamos en Zsh para que los aliases estén disponibles.
if [ -n "${ZSH_VERSION:-}" ]; then
    source "$ZSHRC" 2>/dev/null || true
fi
