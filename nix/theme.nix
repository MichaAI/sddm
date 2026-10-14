# Тема в $out/share/sddm/themes/bento. settings — ключи theme.conf, они
# лягут в theme.conf.user поверх него. avatar — 3D-модель: balsam прямо
# при сборке делает из неё сцену с анимациями, и avatarModel указывает
# на неё сам
{
  lib,
  stdenvNoCC,
  writeText,
  kdePackages,
  settings ? { },
  avatar ? null,
}:

let
  inherit (kdePackages) qtbase qtquick3d;

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.difference ../. (
      lib.fileset.unions (
        map lib.fileset.maybeMissing [
          ../flake.nix
          ../flake.lock
          ../nix
          ../tools
          ../README.md
        ]
      )
    );
  };

  ext = lib.last (lib.splitString "." (baseNameOf avatar));

  conf =
    lib.optionalAttrs (avatar != null) {
      # balsam называет сцену по файлу: avatar.glb → Avatar.qml
      avatarModel = "avatar/Avatar.qml";
    }
    // settings;

  value =
    v:
    if lib.isBool v then
      lib.boolToString v
    else if lib.isPath v then
      "${v}"
    else
      toString v;

  userConf = writeText "theme.conf.user" (
    lib.generators.toINI { } { General = lib.mapAttrs (_: value) conf; }
  );
in
stdenvNoCC.mkDerivation {
  pname = "sddm-theme-bento";
  version = "1.0";
  inherit src;

  nativeBuildInputs = lib.optional (avatar != null) qtquick3d;

  dontConfigure = true;
  dontBuild = true;
  # Тут нечего оборачивать: balsam нужен только при сборке
  dontWrapQtApps = true;

  installPhase = ''
    runHook preInstall

    dir=$out/share/sddm/themes/bento
    mkdir -p $dir
    cp -r . $dir
  ''
  + lib.optionalString (avatar != null) ''
    cp ${avatar} avatar.${ext}
    HOME=$TMPDIR QT_QPA_PLATFORM=offscreen \
      QT_PLUGIN_PATH=${qtquick3d}/${qtbase.qtPluginPrefix} \
      balsam --manualAnimations -o $dir/avatar avatar.${ext}
    test -f $dir/avatar/Avatar.qml
  ''
  + lib.optionalString (conf != { }) ''
    cp ${userConf} $dir/theme.conf.user
  ''
  + ''
    runHook postInstall
  '';

  meta = {
    description = "Бенто-экран входа SDDM в стиле лока из quickshell";
    platforms = lib.platforms.linux;
  };
}
