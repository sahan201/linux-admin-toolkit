# Linux Admin Toolkit

A robust, interactive Bash script designed to easily control system monitoring, health checks, and active maintenance tasks for Linux servers.

Perfect for homelabs, VPS management, or as a daily utility for system administrators and cloud engineers.

## Features

The toolkit is divided into three main modules:

### 1. Passive Monitoring
Quickly check the status of your system without digging through multiple commands.
* **System Info:** OS, Kernel, Uptime, and Architecture.
* **Resource Usage:** Real-time CPU load, Memory/Swap usage, and Disk space.
* **Network Status:** Private/Public IPs and active listening ports.
* **User & Log Management:** View currently logged-in users and fetch the last 10 critical system logs (`journalctl`).

### 2. Health & Service Checks
* **Threshold Alerts:** Automatically calculates Disk and RAM usage. If they exceed predefined thresholds (default: 90%), the tool flags them in **RED**.
* **Failed Services:** Scans for any crashed `systemd` units.
* **Critical Services Monitor:** Verifies if essential services (e.g., SSH, Docker, Nginx, MySQL) are running, stopped, or not installed.

### 3. Active Maintenance (Requires Sudo)
Safely perform routine maintenance with built-in confirmation prompts to prevent accidental executions.
* **System Updates:** Automatically detects your package manager (`apt` or `dnf`) to update and upgrade packages.
* **System Cleanup:** Clears package caches, removes unused dependencies, and vacuums old journal logs to free up disk space.
* **Memory Flush:** Drops kernel caches (`/proc/sys/vm/drop_caches`) to instantly free up RAM buffers.

---

## Getting Started

### Prerequisites
* A Linux-based operating system (Ubuntu, Debian, CentOS, Fedora, etc.)
* `bash` shell
* `sudo` privileges (required for the Active Maintenance module and some log viewing)

### Installation & Usage

1. **Clone the repository or download the script:**
   ```bash
   git clone [https://github.com/sahan201/linux-admin-toolkit.git]
   cd linux-admin-toolkit
   chmod +x admin_toolkit.sh (make the Script Executable)
   ./admin_toolkit.sh