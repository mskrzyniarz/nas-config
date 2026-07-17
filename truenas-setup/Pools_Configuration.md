[← Back to the main guide's steps](../README.md) \
<sup>____________</sup>

# TrueNAS Pools Configuration

## 1. Creating a `tank` pool

- Open `Storage` page.

- Press the `Create Pool` button.

- In section `General Info`, set:
    
    Name: `tank`

    Encryption: `unchecked` (disabled)

> [!NOTE]
> If there is a warning "Warning: There are 2 disks available that have non-unique serial numbers. Non-unique serial numbers can be caused by a cabling issue and adding such disks to a pool can result in lost data."
>
> Select `Don't Allow`


- Press the `Next` button

- In section `Data`, set:

    Layout: `MIRROR`

    From the `Advanced Options` section, select `Manual Selection`
    - press the `Add` button to create new MIRROR VDEV
    - select 2 x 4TB HDDs
    - press the `Add` button to create new MIRROR VDEV
    - select 2 x 8TB HDDs

- Leave the remaining sections unchanged

- Press the `Save And Go To Review`

- Check the `tank` pool configuration and if everything is OK, press the `Create Pool` button

- Confirm disk erasing. 


## 2. Creating a `apps` pool

- Open `Storage` page.

- Press the `Create Pool` button.

- In section `General Info`, set:
    
    Name: `apps`

    Encryption: `unchecked` (disabled)

> [!NOTE]
> If there is a warning "Warning: There are 2 disks available that have non-unique serial numbers. Non-unique serial numbers can be caused by a cabling issue and adding such disks to a pool can result in lost data."
>
> Select `Don't Allow`

- Press the `Next` button

- In section `Data`, set:

    Layout: `STRIPE`

    Inside the `Automated Disk Selection` section, from the `Disk Size` dropdown list select the 1 TB NvMe disk

- Leave the remaining sections unchanged

- Press the `Save And Go To Review`

- Check the `apps` pool configuration and if everything is OK, press the `Create Pool` button

- Confirm disk erasing. 


## 3. Set the `apps` pool as the pool that native TrueNAS Apps will use

- Open `Apps` page.

- From the `Configuration` dropdown, select the `Choose Pool` option

- Select the `apps` pool inside the dialog that appeared and press the `Choose` button

> [!NOTE]
> From now on, all applications will be installed in the `apps` pool. \
> Also TrueNAS automatically mounted the Docker infrastructure under `/mnt/.ix-apps`.

<p align="right">__________</p>
<p align="right">
  <a href="../ugreen-dxp4800-gt/LED_Controller_Support.md">Next step: UGREEN LED Controller support →</a>
</p>
