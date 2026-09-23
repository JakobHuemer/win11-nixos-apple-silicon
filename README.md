# Windows 11 on nixos apple silicon

This flake recreates the windows 11 virtual machine guide from asahi linux:
https://asahilinux.org/docs/sw/windows-11-vm/

## Install

Add the flake as input:

```nix
  inputs = {
    ...

    win11-nixos-apple-silicon = {
      url = "github:JakobHuemer/win11-nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
```

Import the module into your Home Manager config:

```nix
outputs = { nixpkgs, home-manager, mytool, ... }: {
  homeConfigurations.jdoe = home-manager.lib.homeManagerConfiguration {
    pkgs = nixpkgs.legacyPackages.aarch64-linux;
    modules = [
      win11-nixos-apple-silicon.homeModules.default
      ./home.nix
    ];
  };
};
```

## Setup

You will have to download Windows for ARM64 from 
[here](https://www.microsoft.com/en-us/software-download/windows11arm64) and 
the virtio-drivers from 
[here](https://github.com/virtio-win/kvm-guest-drivers-windows/wiki/Driver-installation)

## Configure

```nix
programs.win11-nixos-apple-silicon = {
  enable = true;
};
```
