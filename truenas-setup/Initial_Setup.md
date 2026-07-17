[← Back to the main guide's steps](../README.md)

# Initial TrueNAS Setup

## 1. Setting localization

- Open page: `System` / `General Settings`.

- Find `Localization` widget and press `Settings` button.

- Set `Language` to: `English (en)`.

> [!IMPORTANT]
> Most instructions or troubleshooting methods on the Internet are in English. \
> I also use the English names for pages, options, labels, etc., throughout the whole manual.

- Other settings set based on your localization/preferences.


## 2. Create your own admin user

- Open page: `Credentials` / `Users`

- Press the `Add` button

- Set your username, access rights, a strong password, and your full name. Leave the rest of the settings at their defaults.

    > [!TIP]
    > Set the permissions as in the picture below, you can always change them later if necessary.

    ![Add Admin User](../images/add-admin-user.png)


> [!TIP]
> Optional (but recommended): log in as the new admin user and remove the `truenas_admin` user (as an additional security measure)

<p align="right"><sub>____________</sub></p>
<p align="right">
  <a href="./Pools_Configuration.md">Next step: Pools configuration →</a>
</p>