# README

This is repository for introduction to cyber security project. The target is to
demonstrate token security within a compromised environment.

## Table Of Contents

<!--toc:start-->

- [README](#readme)
  - [`k3s-token-lab` Virtual Machine Information](#k3s-token-lab-virtual-machine-information)
    - [Setup Instructions](#setup-instructions)
    - [Installation Instructions (Windows)](#installation-instructions-windows)
      - [VirtualBox](#virtualbox)
      - [Nix Package Manager](#nix-package-manager)

<!--toc:end-->

## `k3s-token-lab` Virtual Machine Information

The virtual machine image in this documentation is purpose-built for Oracle
VirtualBox VM manager.

Credentials: `lab` and `lab` are username and password respectively.

Services: K3s cluster, ssh.

Exposed ports: 22/ssh service, and 6443/kubeapi server.

### Setup Instructions

> SKIP TO [VirtualBox](#virtualbox) UNDER IN
> [Installation Instructions (Windows)](#installation-instructions-windows) IF
> YOU ALREADY HAVE `k3s-token-lab.ova`

Software **pre-requesities**:

- Access to `nix` package manager to build VM image.
- Oracle VirtualBox virtual machine manager.
  ([Download link](https://www.virtualbox.org/wiki/Downloads))

Steps to **build** image:

1. Clone this repository

   ```bash
   git clone https://github.com/c8c36/cs2413-SecurityProject.git
   ```

2. Run the build procedures.

   **READ THIS BEFORE RUNNING**: Note that this step may take a while depending
   on hardware. Make sure there is enough storage (~10 Gb of free space on disk)
   for image.

   ```bash
   cd ./cs2413-SecurityProject
   ```

   ```bash
   nix build .#virtualbox-vm
   ```

3. Verify the results.

   The command will create directory `result` which should contain
   `k3s-token-lab.ova`. The ova file is a virtual machine image compatible with
   VirtualBox that has K3s cluster preinstalled and activated.

Steps to **run** image:

1. Open VirtualBox GUI application.
2. Find "import" or "import appliances" button.
3. In the dialogue window point to `k3s-token-lab.ova` image, wherever it is
   located, and import process should begin once the "finish" has been pressed.
4. There should be a VM instance created by the VM manager in runnable state
   given that VirtualBox has been properly installed with necessary bindings.

### Installation Instructions (Windows)

Installation instructions for **Windows 11**. These steps were tested with
**Windows 11**, but they should be compatible with **Windows 10**.

#### VirtualBox

Install `Windows hosts` option for VirtualBox
([VirtualBox downloads page](https://www.virtualbox.org/wiki/Downloads)).

Note that during the installation process, the software installer may warn to
install `win32` bindings. This can be via windows console with the following
command given that python has been installed for the user:

```bash
python -m pip install pywin32
```

#### Nix Package Manager

1. Install WSL2. In case of **Windows 11**, WSL comes pre-installed. From
   `administrator console` run:

   ```
   wsl --install
   ```

   The command will install WSL2 with Ubuntu distro, and it will ask to create a
   user.

2. Install Nix package manager into WSL.

   > MAKE SURE THE FOLLOWING COMMAND IS RUNNED FROM WSL

   ```bash
   curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --daemon
   ```

   (Yes, this is a bash script downloaded from the internet, and fed into shell
   script. Yes, this is _usually_ incredibly bad practice security-wise. Never
   do this unless you have extraordinary trust into the distribution).
