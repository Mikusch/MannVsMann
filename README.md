# Mann vs. Mann

![Mann vs. Mann Logo](https://repository-images.githubusercontent.com/359592641/ec8bd400-b132-11eb-8ae7-bf0809723735)

**A custom Team Fortress 2 gamemode that mixes Mann vs. Machine mechanics with regular gameplay.**

Mann vs. Mann was originally created by [Serafeline](https://github.com/Serafeline) and [Kenzzer](https://github.com/Kenzzer) in 2018, but development on it stopped very early on and the plugin was never released to the public.

In April 2021, I decided to remake the plugin from the ground up with many fixes and additional gameplay elements.

## Features

- Fully functioning Mann vs. Machine mechanics in regular gameplay
    - Player and Item Upgrades
    - Power Up Canteens
    - Credit Pickups
    - Buybacks
    - Revive Markers
    - ...and much more
- Compatible with all official game modes (except Mann vs. Machine)
- Support for custom upgrade files
- Highly configurable using plugin ConVars

## Requirements

- SourceMod 1.12+
- [TF2 Attributes](https://github.com/FlaminSarge/tf2attributes)
- [Source Scramble](https://github.com/nosoop/SMExt-SourceScramble)
- [Plugin State Manager](https://github.com/Mikusch/PluginStateManager) (compile only)

## Custom Upgrades Files

Without any customization, the plugin will use the default upgrades file shipped with Team Fortress 2.

This repository contains a custom upgrades file that has been successfully used in live servers for several years.

### Installation

1. Download or copy the [custom upgrades file](/scripts/items/mvm_upgrades_custom.txt) from this repository into your server files
2. Give it a unique name to avoid future conflicts, e.g. `mvm_upgrades_myserver_v1.txt`
3. Set the `sm_mvm_custom_upgrades_file` convar to the path of your upgrades file, e.g. `scripts/items/mvm_upgrades_myserver_v1.txt`
4. If you're using FastDL, offer it for download there
