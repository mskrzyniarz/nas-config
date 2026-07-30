[← Back to the main guide's steps](../README.md)

# ARR Stack: General

**Table of Contents**   
[1. Storage structure](#1-storage-structure)  

## 1. Storage structure

Here is my datasets structure

```js
tank [POOL]
|
├── configs [DATASET] - 'Dataset Preset': 'Apps'
|   ├─ bazarr [DATASET] - 'Dataset Preset': 'Apps'
|   ├─ dozzle [DATASET] - 'Dataset Preset': 'Apps'
|   ├─ jellyfin [DATASET] - 'Dataset Preset': 'Apps'
|   ├─ jellyseerr [DATASET] - 'Dataset Preset': 'Apps'
|   ├─ prowlarr [DATASET] - 'Dataset Preset': 'Apps'
|   ├─ qbittorrent [DATASET] - 'Dataset Preset': 'Apps'
|   ├─ radarr [DATASET] - 'Dataset Preset': 'Apps'
|   ├─ recyclarr [DATASET] - 'Dataset Preset': 'Apps'
|   ├─ sonarr [DATASET] - 'Dataset Preset': 'Apps'
|   └─ tdarr [DATASET] - 'Dataset Preset': 'Apps'
|
└── data [DATASET] - 'Dataset Preset': 'Apps'
    |
    ├── media [DATASET] - 'Dataset Preset': 'Apps'
    |   ├─ books [FOLDER]
    |   ├─ movies [FOLDER]
    |   ├─ music [FOLDER]
    |   └─ tv [FOLDER]
    |
    ├── torrents [DATASET] - 'Dataset Preset': 'Apps'
    |   ├─ books [FOLDER]
    |   ├─ movies [FOLDER]
    |   ├─ music [FOLDER]
    |   └─ tv [FOLDER]
    |
    └── usenet [DATASET] - 'Dataset Preset': 'Apps'
        |
        ├─ incomplete [FOLDER]
        |  ├─ books [FOLDER]
        |  ├─ movies [FOLDER]
        |  ├─ music [FOLDER]
        |  └─ tv [FOLDER]
        |
        └─ complete [FOLDER]
           ├─ books [FOLDER]
           ├─ movies [FOLDER]
           ├─ music [FOLDER]
           └─ tv [FOLDER]
```

- Create datasets:
  ```
  /mnt/tank/data
  /mnt/tank/data/media
  /mnt/tank/data/torrents
  /mnt/tank/data/usenet
  ```

- Create folders according to the structure shown above. Just open a shell and enter these commands:
  ```bash
  mkdir -p /mnt/tank/data/{usenet/{incomplete,complete}/{books,movies,music,tv},media/{books,movies,music,tv}}
  ```
  ```bash
  mkdir -p /mnt/tank/data/{torrents/{books,movies,music,tv},media/{books,movies,music,tv}}
  ```

- The easiest way to do this is to edit the permissions of the `data` dataset and recursively apply the permissions to all of its children:
  - select the `Apply permissions recursively` checkbox \
    If a dialog box appears with the warning "Setting permissions recursively affects this directory and any others below it. This can make data inaccessible." confirm the change in the dialog box.

  - select the `Apply permissions to child datasets` checkbox \
    this checkbox will appear after selecting the first one

  - press the `Save Access Control List` button

    ![ACL of media dataset](../images/acl-of-data-dataset.png)

