#!/bin/bash

################################################################################
# Complete LiveHD Installation and Verilog-to-FIRRTL Conversion Script
# 
# This script performs:
# 1. GCC-14 installation
# 2. LiveHD installation with Bazel
# 3. Yosys installation
# 4. Verilog to FIRRTL conversion workflow
#
# Usage: 
#   ./livehd_complete_setup.sh [options]
#
# Options:
#   --install-only          Only install dependencies and LiveHD
#   --convert-only          Only run conversion (requires INPUT_FILE and OUTPUT_DIR)
#   --input FILE            Input Verilog file for conversion
#   --output DIR            Output directory for conversion results
#   --help                  Show this help message
################################################################################

set -e  # Exit on any error
set -o pipefail  # Exit on pipe failures

################################################################################
# COLOR DEFINITIONS AND LOGGING FUNCTIONS
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${CYAN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

log_step() {
    echo -e "${MAGENTA}▶${NC} $1"
}

################################################################################
# GLOBAL VARIABLES
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/livehd_setup_$(date +%Y%m%d_%H%M%S).log"
LIVEHD_DIR="$HOME/livehd"
INSTALL_ONLY=false
CONVERT_ONLY=false
INPUT_FILE=""
OUTPUT_DIR="/workspace/livehd_examples/out"

# Redirect all output to both terminal and log file
exec > >(tee -a "$LOG_FILE")
exec 2>&1

################################################################################
# ARGUMENT PARSING
################################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-only)
                INSTALL_ONLY=true
                shift
                ;;
            --convert-only)
                CONVERT_ONLY=true
                shift
                ;;
            --input)
                INPUT_FILE="$2"
                shift 2
                ;;
            --output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Complete LiveHD Setup and Conversion Script

Usage: $0 [options]

OPTIONS:
  --install-only          Only install dependencies and LiveHD (skip conversion)
  --convert-only          Only run conversion (requires --input)
  --input FILE            Input Verilog file for conversion
  --output DIR            Output directory (default: /workspace/livehd_examples/out)
  --help                  Show this help message

EXAMPLES:
  # Full installation and conversion:
  $0 --input /path/to/design.v --output /path/to/output

  # Installation only:
  $0 --install-only

  # Conversion only (after installation):
  $0 --convert-only --input /path/to/design.v --output /path/to/output

EOF
}

validate_arguments() {
    log_header "Validating Arguments"
    
    if [[ "$INSTALL_ONLY" == true ]] && [[ "$CONVERT_ONLY" == true ]]; then
        log_error "Cannot use --install-only and --convert-only together"
        exit 1
    fi
    
    if [[ "$CONVERT_ONLY" == true ]]; then
        if [[ -z "$INPUT_FILE" ]]; then
            log_error "Conversion mode requires --input argument"
            show_help
            exit 1
        fi
        
        if [[ ! -f "$INPUT_FILE" ]]; then
            log_error "Input file does not exist: $INPUT_FILE"
            exit 1
        fi
        
        log_success "Conversion mode validated"
        log_info "Input file: $INPUT_FILE"
        log_info "Output directory: $OUTPUT_DIR"
    elif [[ "$INSTALL_ONLY" == false ]] && [[ -z "$INPUT_FILE" ]]; then
        log_warning "No input file specified. Will only perform installation."
        INSTALL_ONLY=true
    fi
    
    if [[ -n "$INPUT_FILE" ]]; then
        log_info "Input file: $INPUT_FILE"
        log_info "Output directory: $OUTPUT_DIR"
    fi
}

################################################################################
# INSTALLATION FUNCTIONS
################################################################################

install_gcc14() {
    log_header "Installing GCC-14 and G++-14"
    
    if command -v g++-14 &> /dev/null && command -v gcc-14 &> /dev/null; then
        log_success "GCC-14 and G++-14 already installed"
        g++-14 --version | head -1
        return 0
    fi
    
    log_step "Adding Ubuntu toolchain PPA repository..."
    sudo add-apt-repository ppa:ubuntu-toolchain-r/test -y
    
    log_step "Updating package lists..."
    sudo apt update
    
    log_step "Installing gcc-14 and g++-14..."
    sudo apt install -y g++-14 gcc-14
    
    log_step "Verifying installation..."
    if ! command -v g++-14 &> /dev/null; then
        log_error "g++-14 installation failed"
        exit 1
    fi
    
    local gcc14_path=$(which g++-14)
    log_success "GCC-14 installed successfully at: $gcc14_path"
    
    g++-14 --version | head -1
    gcc-14 --version | head -1
}

setup_compiler_environment() {
    log_header "Setting Up Compiler Environment"
    
    export CXX=/usr/bin/g++-14
    export CC=/usr/bin/gcc-14
    
    log_step "Setting environment variables..."
    log_info "CXX=$CXX"
    log_info "CC=$CC"
    
    # Create aliases for the current session
    alias g++="g++-14" 2>/dev/null || true
    alias gcc="gcc-14" 2>/dev/null || true
    
    # Add to bashrc if not already present
    if ! grep -q "export CXX=/usr/bin/g++-14" ~/.bashrc; then
        log_step "Adding compiler settings to ~/.bashrc..."
        cat >> ~/.bashrc << 'EOF'

# GCC-14 Compiler Settings
export CXX=/usr/bin/g++-14
export CC=/usr/bin/gcc-14
alias g++="g++-14"
alias gcc="gcc-14"
EOF
        log_success "Compiler settings added to ~/.bashrc"
    else
        log_info "Compiler settings already in ~/.bashrc"
    fi
}

verify_cpp23_support() {
    log_header "Verifying C++23 Support"
    
    cat > /tmp/cpp23_test.cpp << 'EOF'
#include <iostream>
#include <format>
int main() {
    std::string msg = std::format("C++23 with <format> supported");
    std::cout << msg << std::endl;
    return 0;
}
EOF
    
    log_step "Testing C++23 compilation with <format> header..."
    if $CXX -std=c++23 /tmp/cpp23_test.cpp -o /tmp/cpp23_test 2>/dev/null; then
        log_success "✓ C++23 with <format> header verified"
        /tmp/cpp23_test
        rm -f /tmp/cpp23_test.cpp /tmp/cpp23_test
        export HAS_FORMAT_HEADER="yes"
    else
        log_warning "✗ <format> header NOT available"
        log_warning "This may cause build issues - will attempt to patch"
        rm -f /tmp/cpp23_test.cpp /tmp/cpp23_test
        export HAS_FORMAT_HEADER="no"
    fi
}

install_basic_tools() {
    log_header "Installing Basic Development Tools"
    
    log_step "Updating package manager..."
    sudo apt update
    
    log_step "Installing essential tools..."
    sudo apt install -y \
        git \
        curl \
        wget \
        python3 \
        python3-pip \
        unzip \
        pkg-config \
        build-essential
    
    log_success "Basic tools installed"
}

install_bazel() {
    log_header "Installing Bazel 8.4.1"
    
    local bazel_version="8.4.1"
    local bazel_installer="bazel-${bazel_version}-installer-linux-x86_64.sh"
    
    if command -v bazel &> /dev/null; then
        local current_version=$(bazel --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
        if [[ "$current_version" == "$bazel_version" ]]; then
            log_success "Bazel $bazel_version already installed"
            return 0
        else
            log_warning "Found Bazel $current_version, installing $bazel_version"
        fi
    fi
    
    log_step "Downloading Bazel $bazel_version..."
    if ! wget -q "https://github.com/bazelbuild/bazel/releases/download/${bazel_version}/${bazel_installer}"; then
        log_error "Failed to download Bazel installer"
        exit 1
    fi
    
    log_step "Installing Bazel..."
    chmod +x "$bazel_installer"
    ./"$bazel_installer" --user
    
    # Add Bazel to PATH
    if ! grep -q 'export PATH="$PATH:$HOME/bin"' ~/.bashrc; then
        echo 'export PATH="$PATH:$HOME/bin"' >> ~/.bashrc
    fi
    export PATH="$PATH:$HOME/bin"
    
    rm -f "$bazel_installer"
    
    log_step "Verifying Bazel installation..."
    "$HOME/bin/bazel" --version
    
    log_success "Bazel installed successfully"
}

create_bazel_config() {
    log_header "Creating Bazel Configuration"
    
    cd "$LIVEHD_DIR"
    
    log_step "Creating .bazelrc.local with compiler settings..."
    cat > .bazelrc.local << EOF
# Local Bazel configuration for LiveHD
build --action_env=CC=$CC
build --action_env=CXX=$CXX
build --cxxopt="-std=c++23"
build --host_cxxopt="-std=c++23"
build --cxxopt="-Wno-error"
build --linkopt="-fuse-ld=gold" --incompatible_linkopts_to_linklibs
build --local_ram_resources=HOST_RAM*.8
build --local_cpu_resources=HOST_CPUS*.8
EOF
    
    log_success "Bazel configuration created"
}

patch_vcd_reader() {
    local vcd_reader_file="$LIVEHD_DIR/core/vcd_reader.cpp"
    
    if [[ "$HAS_FORMAT_HEADER" == "no" ]] && [[ -f "$vcd_reader_file" ]]; then
        log_header "Patching vcd_reader.cpp"
        
        cp "$vcd_reader_file" "$vcd_reader_file.backup"
        sed -i '/#include <format>/d' "$vcd_reader_file"
        
        log_success "Patched vcd_reader.cpp (removed <format> include)"
    fi
}

install_livehd() {
    log_header "Installing LiveHD"
    
    if [[ -d "$LIVEHD_DIR" ]]; then
        log_warning "LiveHD directory already exists at $LIVEHD_DIR"
        log_info "Using existing directory"
        cd "$LIVEHD_DIR"
    else
        log_step "Cloning LiveHD repository..."
        git clone https://github.com/masc-ucsc/livehd.git "$LIVEHD_DIR"
        cd "$LIVEHD_DIR"
        log_success "Repository cloned"
    fi
    
    patch_vcd_reader
    create_bazel_config
    
    # Determine which bazel to use
    local bazel_cmd="bazel"
    if [[ -f "$HOME/bin/bazel" ]]; then
        bazel_cmd="$HOME/bin/bazel"
    fi
    
    log_step "Building LiveHD (this may take 15-30 minutes)..."
    log_info "Using bazel: $bazel_cmd"
    log_info "Using compilers: CC=$CC, CXX=$CXX"
    
    export CC="$CC"
    export CXX="$CXX"
    
    log_step "Building core components..."
    if ! $bazel_cmd build //core/... --verbose_failures; then
        log_error "Core build failed"
        exit 1
    fi
    
    log_step "Building main LiveHD shell..."
    $bazel_cmd build //main:lgshell --verbose_failures
    
    log_success "LiveHD built successfully!"
    log_info "Executable: $LIVEHD_DIR/bazel-bin/main/lgshell"
}

create_convenience_script() {
    log_header "Creating Convenience Scripts"
    
    mkdir -p "$HOME/bin"
    
    cat > "$HOME/bin/livehd" << 'EOF'
#!/bin/bash
LIVEHD_HOME="$HOME/livehd"
if [[ ! -d "$LIVEHD_HOME" ]]; then
    echo "Error: LiveHD not found at $LIVEHD_HOME"
    exit 1
fi
cd "$LIVEHD_HOME"
exec ./bazel-bin/main/lgshell "$@"
EOF
    
    chmod +x "$HOME/bin/livehd"
    
    log_success "Convenience script created at $HOME/bin/livehd"
}

install_yosys() {
    log_header "Installing Yosys"
    
    if command -v yosys &> /dev/null; then
        log_success "Yosys already installed"
        yosys -V | head -1
        return 0
    fi
    
    log_step "Installing Yosys via apt..."
    sudo apt install -y yosys
    
    log_step "Verifying Yosys installation..."
    yosys -V | head -1
    
    log_success "Yosys installed successfully"
}

################################################################################
# CONVERSION FUNCTIONS
################################################################################

run_conversion() {
    log_header "Running Verilog to FIRRTL Conversion"
    
    # Validate inputs
    if [[ ! -f "$INPUT_FILE" ]]; then
        log_error "Input file not found: $INPUT_FILE"
        exit 1
    fi
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    log_info "Output directory: $OUTPUT_DIR"
    
    local input_basename=$(basename "$INPUT_FILE")
    local input_name="${input_basename%.v}"
    local opt_verilog="$OUTPUT_DIR/${input_basename}"
    local output_firrtl="$OUTPUT_DIR/${input_name}.fir"
    
    # Step 1: LiveHD Optimization
    log_step "[Step 1/3] Running LiveHD optimization..."
    cd "$LIVEHD_DIR"
    
    cat > /tmp/livehd_commands.txt << EOF
inou.liveparse path:./lgdb_temp files:${INPUT_FILE} |> inou.verilog |> pass.compiler |> inou.cgen.verilog odir:${OUTPUT_DIR}
EOF
    
    if ! ./bazel-bin/main/lgshell < /tmp/livehd_commands.txt; then
        log_error "LiveHD optimization failed"
        exit 1
    fi
    
    log_success "LiveHD optimization completed"
    
    # Step 2: Convert to FIRRTL using Yosys
    log_step "[Step 2/3] Converting to FIRRTL using Yosys..."
    
    if [[ ! -f "$opt_verilog" ]]; then
        log_error "Optimized Verilog not found: $opt_verilog"
        exit 1
    fi
    
    if ! yosys -p "read_verilog -sv ${opt_verilog}; write_firrtl ${output_firrtl}"; then
        log_error "Yosys conversion failed"
        exit 1
    fi
    
    log_success "FIRRTL conversion completed"
    
    # Step 3: Verify outputs
    log_step "[Step 3/3] Verifying outputs..."
    
    if [[ -f "$output_firrtl" ]]; then
        log_success "FIRRTL file created: $output_firrtl"
        log_info "File size: $(du -h "$output_firrtl" | cut -f1)"
    else
        log_error "FIRRTL file not created"
        exit 1
    fi
    
    log_header "Conversion Complete!"
    echo ""
    log_info "Input Verilog:     $INPUT_FILE"
    log_info "Optimized Verilog: $opt_verilog"
    log_info "Output FIRRTL:     $output_firrtl"
    echo ""
}

################################################################################
# MAIN EXECUTION
################################################################################

print_summary() {
    log_header "Installation Summary"
    
    cat << EOF
✅ Installation completed successfully!

📁 Installed Components:
   • GCC-14:     $(which g++-14)
   • Bazel:      $(which bazel 2>/dev/null || echo "$HOME/bin/bazel")
   • Yosys:      $(which yosys)
   • LiveHD:     $LIVEHD_DIR
   • Executable: $LIVEHD_DIR/bazel-bin/main/lgshell

📝 Log file saved to: $LOG_FILE

🚀 Next Steps:
   1. Reload your shell: source ~/.bashrc
   2. Run LiveHD: livehd
   3. Or convert a file: $0 --convert-only --input your_file.v

📚 Documentation: https://github.com/masc-ucsc/livehd

EOF
}

main() {
    log_header "LiveHD Complete Setup Script"
    log_info "Script started at $(date)"
    log_info "Log file: $LOG_FILE"
    
    parse_arguments "$@"
    validate_arguments
    
    if [[ "$CONVERT_ONLY" == true ]]; then
        # Only run conversion
        run_conversion
    else
        # Run full installation
        install_gcc14
        setup_compiler_environment
        verify_cpp23_support
        install_basic_tools
        install_bazel
        install_livehd
        create_convenience_script
        install_yosys
        
        print_summary
        
        # Run conversion if input file was provided
        if [[ -n "$INPUT_FILE" ]]; then
            run_conversion
        fi
    fi
    
    log_success "All operations completed successfully!"
    log_info "Script finished at $(date)"
}

# Trap errors and cleanup
trap 'log_error "Script failed at line $LINENO"; exit 1' ERR

# Run main function
main "$@"