_This repository aims to document the setup process of my first NAS server._

General information about the hardware used:
- Base: **UGREEN DXP4800 GT** NAS
- 2 x 32 GB RAM ECC DDR4 _(64 GB total)_
- 1 x NvMe 250 GB _(for TrueNAS Scale OS)_
- 1 x NvMe 1 Tb _(for applications, VMs, etc.)_
- 2 x HDD 4 TB _(for data storage)_
- 2 x HDD 8 TB _(for data storage)_

The configuration of my pools is as follows:
```
boot (Stripe)
└─ VDEV 1 x DISK NvMe 250 GB (TrueNAS)

tank (Stripe made of 2 x MIRROR)
├─ VDEV MIRROR 2 x HDD 4 TB
└─ VDEV MIRROR 2 x HDD 8 TB

apps (Stripe)
└─ VDEV 1 x DISK NvMe 1 TB
```

This guide does not cover the TrueNAS installation process. Instead, it explains how to configure it immediately after installation.

The TrueNAS version for which this manual was written is **25.10.4**.

# Steps:

## 1. [Initial setup (set localization settings, create your own admin user)](./truenas-setup/Initial_Setup.md)

## 2. [Pools configuration (create all pools and use the "apps" pool via TrueNAS Apps)](./truenas-setup/Pools_Configuration.md)

## 3. [UGREEN LED Controller support (adding the ability to control LED lights on the front panel of the NAS)](./ugreen-dxp4800-gt/LED_Controller_Support.md)

## 4. [SMB configuration (attach a network drive on Windows OS to access files from NAS)](./truenas-setup/Pools_Configuration.md)