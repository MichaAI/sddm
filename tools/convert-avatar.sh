#!/bin/sh
# Делает из 3D-модели сцену для QtQuick3D с анимациями:
#   tools/convert-avatar.sh ~/avatar.glb [папка]
# balsam лежит в qtquick3d (на NixOS — qt6.qtquick3d). Путь к .qml, который
# он создаст, пиши в avatarModel в theme.conf.
set -eu

src=$1
out=${2:-avatar}

# --manualAnimations: таймлайны без своих TimelineAnimation — какую
# анимацию играть, решает тема (avatarAnimation)
if ! log=$(QT_QPA_PLATFORM=offscreen balsam --manualAnimations -o "$out" "$src" 2>&1); then
    echo "$log" >&2
    exit 1
fi

scene=$(ls "$out"/*.qml | head -n 1)
echo "$scene"
echo "Анимации: $(awk -F'"' '/^    Timeline \{/ { t = 1 } t && /objectName/ { printf "%s ", $2; t = 0 }' "$scene")"
