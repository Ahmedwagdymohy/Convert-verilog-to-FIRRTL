# Convert-verilog-to-FIRRTL


## 🎯 Key Features

### 🔍 Pre-flight Validation
- Checks all required arguments before starting any operations.

### 🪵 Detailed Logging
- All output is timestamped, color-coded, and saved to a log file.

### ⚙️ Flexible Modes
- **Full installation + conversion**
- **Installation only** (`--install-only`)
- **Conversion only** (`--convert-only`)

---

## 🛡️ Robust Error Handling
- Exits immediately on errors.  
- Clear error messages with timestamps.  
- Automatic cleanup on failure.  

---

## 📊 Progress Visibility
- Clear section headers.  
- Step-by-step progress indicators.  
- Success, warning, and error messages.  

---

## 📖 Usage Examples

```bash
# Full installation and conversion:
./livehd_complete_setup.sh --input /path/to/design.v --output /path/to/output

# Installation only:
./livehd_complete_setup.sh --install-only

# Conversion only (after installation):
./livehd_complete_setup.sh --convert-only --input design.v --output ./out

# Get help:
./livehd_complete_setup.sh --help
