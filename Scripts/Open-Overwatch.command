#!/bin/bash
set -euo pipefail
GAME_IMAGE='/Volumes/名称未設定/OverwatchGames.sparsebundle'
GAME_VOLUME='/Volumes/OverwatchMac'
if ! /sbin/mount | /usr/bin/grep -Fq " on $GAME_VOLUME ("
then
    if [ ! -d "$GAME_IMAGE" ]
    then
        printf '%s\n' '外付けSSD「名称未設定」を接続してください。'
        read -r -p 'Enterで閉じます。' _
        exit 1
    fi
    /usr/bin/hdiutil attach -nobrowse "$GAME_IMAGE"
fi
if [ ! -d /Applications/Recall.app ]
then
    printf '%s\n' 'RecallがApplicationsフォルダに見つかりません。'
    read -r -p 'Enterで閉じます。' _
    exit 1
fi
/usr/bin/open /Applications/Recall.app
