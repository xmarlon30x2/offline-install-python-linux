#!/bin/bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuración
DEPS_DIR="$(pwd)/deps"                 # Usar rutas absolutas
PYTHON_DIR="$(pwd)/python_versions"    # Evitar problemas con rutas relativas
INSTALL_DIR="/usr/local"

# Crear directorios si no existen
mkdir -p "$DEPS_DIR" "$PYTHON_DIR"

check_dependencies() {
    local required_deps=("build-essential" "zlib1g-dev" "libncurses5-dev" 
                         "libgdbm-dev" "libnss3-dev" "libssl-dev" 
                         "libsqlite3-dev" "libreadline-dev" "libffi-dev" 
                         "libbz2-dev" "curl" "wget" "tar" "make")
    
    echo -e "${BLUE}Verificando dependencias...${NC}"
    
    for dep in "${required_deps[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$dep" 2>/dev/null | grep -q "ok installed"; then
            echo -e "${RED}Falta: $dep${NC}"
            return 1
        fi
    done
    echo -e "${GREEN}Todas las dependencias están instaladas!${NC}"
    return 0
}

download_dependencies() {
    echo -e "${BLUE}Descargando dependencias...${NC}"
    mkdir -p "$DEPS_DIR"
    cd "$DEPS_DIR" || { echo -e "${RED}Error al acceder a $DEPS_DIR${NC}"; return 1; }
    
    # Verificar conexión a internet
    if ! curl -Is https://archive.ubuntu.com >/dev/null 2>&1; then
        echo -e "${RED}No hay conexión a internet!${NC}"
        return 1
    fi
    
    sudo apt-get download \
        build-essential \
        zlib1g-dev \
        libncurses5-dev \
        libgdbm-dev \
        libnss3-dev \
        libssl-dev \
        libsqlite3-dev \
        libreadline-dev \
        libffi-dev \
        libbz2-dev \
        curl \
        wget \
        tar \
        make 2>/dev/null
    
    cd ..
    echo -e "${GREEN}Dependencias descargadas en $DEPS_DIR/${NC}"
}

install_dependencies() {
    echo -e "${BLUE}Instalando dependencias...${NC}"
    if [ -z "$(ls -A "$DEPS_DIR"/*.deb 2>/dev/null)" ]; then
        echo -e "${RED}No hay paquetes .deb en $DEPS_DIR/${NC}"
        return 1
    fi
    
    sudo dpkg -i "$DEPS_DIR"/*.deb
    sudo apt-get install -f -y  # Corregir dependencias rotas
    return $?
}

download_python() {
    # Verificar conexión a internet
    if ! curl -Is https://www.python.org >/dev/null 2>&1; then
        echo -e "${RED}No hay conexión a internet!${NC}"
        return 1
    fi
    
    echo -e "\n${BLUE}Versiones disponibles de Python:${NC}"
    versions=$(curl -s https://www.python.org/downloads/source/ | grep -Eo 'Python-3\.[0-9]+\.[0-9]+' | sort -V | uniq)
    echo "$versions"
    
    while true; do
        read -p "Versión a descargar (ej: 3.12.0): " version
        if [[ "$version" =~ ^3\.[0-9]+\.[0-9]+$ ]]; then
            break
        else
            echo -e "${RED}Formato de versión inválido! Use X.X.X${NC}"
        fi
    done
    
    if ! wget "https://www.python.org/ftp/python/$version/Python-$version.tgz" -P "$PYTHON_DIR/"; then
        echo -e "${RED}Error al descargar Python $version!${NC}"
        return 1
    fi
}

install_python() {
    local versions=()
    while IFS= read -r -d $'\0' file; do
        versions+=("$file")
    done < <(find "$PYTHON_DIR" -name 'Python-*.tgz' -print0 2>/dev/null)
    
    if [ ${#versions[@]} -eq 0 ]; then
        echo -e "${RED}No hay versiones de Python descargadas!${NC}"
        return 1
    fi
    
    echo -e "\n${BLUE}Versiones disponibles para instalar:${NC}"
    for i in "${!versions[@]}"; do
        version=$(basename "${versions[$i]}" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+')
        echo "$((i+1)). Python $version"
    done
    
    while true; do
        read -p "Seleccione una versión (1-${#versions[@]}): " num
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#versions[@]} ]; then
            break
        else
            echo -e "${RED}Selección inválida!${NC}"
        fi
    done
    
    selected_file="${versions[$((num-1))]}"
    selected_version=$(basename "$selected_file" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+')
    
    echo -e "${YELLOW}Instalando Python $selected_version...${NC}"
    temp_dir=$(mktemp -d)
    tar -xf "$selected_file" -C "$temp_dir" || { echo -e "${RED}Error al extraer archivo!${NC}"; rm -rf "$temp_dir"; return 1; }
    
    cd "$temp_dir/Python-$selected_version" || { echo -e "${RED}Error al acceder al directorio!${NC}"; rm -rf "$temp_dir"; return 1; }
    
    ./configure --enable-optimizations
    make -j$(nproc)
    sudo make altinstall
    cd ..
    rm -rf "$temp_dir"
    
    echo -e "${GREEN}Python $selected_version instalado!${NC}"
    echo -e "Usa: ${YELLOW}python${selected_version%.*}${NC} o ${YELLOW}python$selected_version${NC}"
}

set_default_python() {
    local versions=()
    while IFS= read -r -d $'\0' file; do
        versions+=("$file")
    done < <(find /usr/local/bin -regex '.*/python3\.[0-9]+\.[0-9]+' -print0 2>/dev/null)
    
    if [ ${#versions[@]} -eq 0 ]; then
        echo -e "${RED}No hay versiones de Python instaladas!${NC}"
        return 1
    fi
    
    echo -e "\n${BLUE}Versiones instaladas:${NC}"
    for i in "${!versions[@]}"; do
        version=$(basename "${versions[$i]}" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+')
        echo "$((i+1)). Python $version"
    done
    
    while true; do
        read -p "Seleccione versión por defecto (1-${#versions[@]}): " num
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#versions[@]} ]; then
            break
        else
            echo -e "${RED}Selección inválida!${NC}"
        fi
    done
    
    selected_version=$(basename "${versions[$((num-1))]}" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+')
    sudo update-alternatives --install /usr/bin/python3 python3 "/usr/local/bin/python$selected_version" 1
    sudo update-alternatives --config python3
    
    echo -e "${GREEN}Versión por defecto actualizada!${NC}"
}

show_menu() {
    clear
    echo -e "${YELLOW}=== Instalador Offline de Python ==="
    echo -e "1. Descargar dependencias (requiere internet)"
    echo -e "2. Instalar dependencias locales"
    echo -e "3. Descargar Python (requiere internet)"
    echo -e "4. Instalar Python desde archivos locales"
    echo -e "5. Establecer versión por defecto"
    echo -e "6. Verificar dependencias del sistema"
    echo -e "7. Salir${NC}"
}

while true; do
    show_menu
    read -p "Seleccione una opción: " choice
    
    case $choice in
        1) download_dependencies ;;
        2) install_dependencies ;;
        3) download_python ;;
        4) install_python ;;
        5) set_default_python ;;
        6) check_dependencies ;;
        7) echo -e "${GREEN}Saliendo...${NC}"; exit 0 ;;
        *) echo -e "${RED}Opción inválida!${NC}"; sleep 1 ;;
    esac
    read -p "Presione enter para continuar..." -r
done
