# Модуль NixOS: michaai.sddm
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.michaai.sddm;
  inherit (lib) mkOption mkEnableOption types;
in
{
  options.michaai.sddm = {
    enable = mkEnableOption "SDDM с темой bento";

    settings = mkOption {
      type = types.attrsOf (
        types.oneOf [
          types.str
          types.int
          types.float
          types.bool
          types.path
        ]
      );
      default = { };
      example = lib.literalExpression ''
        {
          background = ./wall.png;
          blur = 64;
          avatarAnimation = "Run";
          locale = "ru_RU";
        }
      '';
      description = ''
        Ключи theme.conf, которые надо заменить: обои, размытие, анимация
        авы, язык даты, размеры сетки. Пути кладутся в стор, откуда их
        прочитает пользователь sddm.
      '';
    };

    avatar = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = lib.literalExpression "./Fox.glb";
      description = ''
        3D-модель вместо аватарки (.glb/.gltf/.fbx/.obj). Сцену с анимациями
        из неё делает balsam при сборке; анимацию выбирает
        settings.avatarAnimation.
      '';
    };

    font = mkOption {
      type = types.bool;
      default = true;
      description = "Поставить JetBrainsMono Nerd Font: без него значки — квадратики.";
    };

    package = mkOption {
      type = types.package;
      readOnly = true;
      description = "Собранная тема.";
    };
  };

  config = lib.mkIf cfg.enable {
    michaai.sddm.package = pkgs.callPackage ./theme.nix { inherit (cfg) settings avatar; };

    services.displayManager.sddm = {
      enable = lib.mkDefault true;
      # Тема на Qt 6
      package = lib.mkDefault pkgs.kdePackages.sddm;
      theme = "bento";
      # Плагины картинок — для обоев в webp, avif и т.п.; QtQuick3D и
      # Timeline — только для 3D-авы
      extraPackages = [
        pkgs.kdePackages.qtimageformats
      ]
      ++ lib.optionals (cfg.avatar != null || cfg.settings ? avatarModel) [
        pkgs.kdePackages.qtquick3d
        pkgs.kdePackages.qtquicktimeline
      ];
    };

    environment.systemPackages = [ cfg.package ];
    fonts.packages = lib.optional cfg.font pkgs.nerd-fonts.jetbrains-mono;
  };
}
