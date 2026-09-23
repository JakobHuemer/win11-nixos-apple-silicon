{
  description = "A Flake for running a windows virtual machine on nixos apple silicon";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = {
    nixpkgs,
    self,
    ...
  }: {
    homeModules.default = {
      pkgs,
      lib,
      config,
      ...
    }: {
      options.programs.win11-nixos-apple-silicon = {
        enable = lib.mkEnableOption "win11-nixos-apple-silicon";

        memory = lib.mkOption {
          type = lib.types.ints.positive;
          default = 4096;
          description = "Guest RAM in MiB";
        };

        virtio-iso-path = lib.mkOption {
          type = lib.types.nullOr lib.types.externalPath;
          default = null;
        };
        win11-iso-path = lib.mkOption {
          type = lib.types.nullOr lib.types.externalPath;
          default = null;
        };
        bios-fd-path = lib.mkOption {
          type = lib.types.path;
          default = "${pkgs.OVMF.fd}/FV/QEMU_EFI.fd";
          defaultText = lib.literalExpression ''"''${pkgs.OVMF.fd}/FV/QEMU_EFI.fd"'';
        };

        qemu-package = lib.mkPackageOption pkgs "qemu" {};

        diskImage = lib.mkOption {
          type = lib.types.nullOr lib.types.externalPath;
          default = null;
        };
        diskSize = lib.mkOption {
          type = lib.types.ints.positive;
          default = 1024 * 20;
          description = "Size of disk in MiB";
        };
      };

      config = let
        cfg = config.programs.win11-nixos-apple-silicon;

        appName = "win11-nixos-apple-silicon";

        prestartText = ''
          disk=${
            if cfg.diskImage != null
            then lib.escapeShellArg cfg.diskImage
            else ''"''${XDG_STATE_HOME:-$HOME/.local/state}/${appName}/disk.qcow2"''
          }
          if [ ! -e "$disk" ]; then
            mkdir -p "$(dirname "$disk")"
            qemu-img create -f qcow2 "$disk" ${toString cfg.diskSize}M
          fi
        '';

        qemuArgs =
          [
            "-display gtk,gl=on"
            "-cpu host"
            "-M virt"
            "-enable-kvm"
            "-m ${toString cfg.memory}M"
            "-smp 2"
            "-bios ${lib.escapeShellArg cfg.bios-fd-path}"
            ''-hda "$disk"''
            "-device qemu-xhci"
            "-device ramfb"
            "-device virtio-gpu-pci,edid=on"
          ]
          ++ lib.optionals (cfg.win11-iso-path != null) [
            "-device usb-storage,drive=install"
            "-drive if=none,id=install,format=raw,media=cdrom,file=${lib.escapeShellArg cfg.win11-iso-path}"
          ]
          ++ lib.optionals (cfg.virtio-iso-path != null) [
            "-device usb-storage,drive=virtio-drivers"
            "-drive if=none,id=virtio-drivers,format=raw,media=cdrom,file=${lib.escapeShellArg cfg.virtio-iso-path}"
          ]
          ++ [
            "-object rng-random,filename=/dev/urandom,id=rng0"
            "-device virtio-rng-pci,rng=rng0"
            "-audio driver=pipewire,model=virtio"
            "-device usb-kbd"
            "-device usb-tablet"
            "-nic user,model=virtio-net-pci"
          ];
      in
        lib.mkIf cfg.enable {
          home.packages = [
            (pkgs.writeShellApplication {
              name = "win11-vm";

              runtimeInputs = [
                pkgs.util-linux
                cfg.qemu-package
              ];

              text = ''
                ${prestartText}

                performance_cores=$(awk '
                  /^processor/ { proc=$3 }
                  /^CPU part/ {
                    if ($4 == "0x023" || $4 == "0x025" || $4 == "0x029" || $4 == "0x033" || $4 == "0x035" || $4 == "0x039")
                      procs=procs ? procs","proc : proc
                  } END { print procs }
                ' /proc/cpuinfo)

                taskset -c "$performance_cores" \
                  qemu-system-aarch64 \
                    ${lib.concatStringsSep " " qemuArgs}
              '';
            })
          ];
        };
    };
  };
}
