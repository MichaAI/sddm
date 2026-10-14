# Bento — тема SDDM

Экран входа в том же виде, что и экран блокировки из quickshell:
бенто из двух колонок, пружинные анимации, градиентные часы, точки пароля.

Отличия от лока — под логику грейтера:

- пароль проверяет SDDM (`sddm.login`), а не PAM из шелла;
- вместо плитки музыки — выбор сессии (стрелки как «пред./след. трек»);
- на плитке аватара — выбор пользователя (стрелки или Tab / Shift+Tab),
  имя хоста и кнопки сна, перезагрузки и выключения;
- раскладка и Caps Lock — от SDDM; клик по значку раскладки её переключает;
- аватар — иконка пользователя от SDDM (AccountsService или `~/.face.icon`),
  3D-модель задаётся в `theme.conf`.

Нужны SDDM ≥ 0.21 с грейтером на Qt 6 и шрифт JetBrainsMono Nerd Font.
Для 3D-авы — QtQuick3D, для анимаций в ней ещё QtQuick.Timeline.

## Установка

```sh
sudo cp -r . /usr/share/sddm/themes/bento
```

```ini
# /etc/sddm.conf.d/theme.conf
[Theme]
Current=bento
```

На NixOS: `services.displayManager.sddm.theme` — путь к папке темы,
а `qt6.qtquick3d` (и `qt6.qtquicktimeline` для анимаций) — в `extraPackages`,
если нужна 3D-ава.

## 3D-ава с анимацией

RuntimeLoader из QtQuick3D анимации не проигрывает, поэтому модель
один раз прогоняется через balsam:

```sh
tools/convert-avatar.sh Fox.glb avatar
# avatar/Fox.qml
# Анимации: Survey Walk Run
```

В `theme.conf`: `avatarModel=avatar/Fox.qml`, `avatarAnimation=Run`.
Папку с результатом держи там, где её прочитает пользователь sddm,
например в папке темы.

## Проверка без выхода из сессии

```sh
sddm-greeter-qt6 --test-mode --theme .
```

## Настройки

Всё в `theme.conf`: обои и их размытие, 3D-модель, язык даты, размеры сетки.
Цвета (Catppuccin Mocha), пружины и дизеринг — в `config/`.
