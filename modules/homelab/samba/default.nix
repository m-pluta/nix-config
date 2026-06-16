{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  hl = config.homelab;
  cfg = hl.samba;
in
{
  options.homelab.samba = {
    enable = lib.mkEnableOption {
      description = "Samba shares for the homelab";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "samba";
      description = "User for SMB authentication";
    };
    globalSettings = lib.mkOption {
      description = "Global Samba parameters";
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        "browseable" = "yes";
        "writeable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
      };
    };
    commonSettings = lib.mkOption {
      description = "Parameters applied to each share";
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        "security" = "user";
        "invalid users" = [ "root" ];
      };
      apply =
        old:
        lib.attrsets.mergeAttrsList [
          {
            "preserve case" = "yes";
            "short preserve case" = "yes";
            "browseable" = "yes";
            "guest ok" = "no";
            "create mask" = "0644";
            "directory mask" = "0755";
            "valid users" = cfg.user;
            "fruit:aapl" = "yes";
            "vfs objects" = "catia fruit streams_xattr";
          }
          old
        ];
    };
    shares = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            path = lib.mkOption {
              type = lib.types.str;
            };
            readOnly = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
            extraSettings = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
            };
          };
        }
      );
      default = { };
    };
  };
  config = lib.mkIf cfg.enable {
    age.secrets.samba-password.file = "${inputs.secrets}/services/samba/password.age";

    environment.systemPackages = [ config.services.samba.package ];

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = "media";
    };

    systemd.services.samba-smbd.preStart = ''
      smb_password=$(cat "${config.age.secrets.samba-password.path}")
      echo -e "$smb_password\n$smb_password\n" | ${lib.getExe' pkgs.samba "smbpasswd"} -a -s ${cfg.user}
    '';

    networking.firewall = {
      allowedTCPPorts = [ 5357 ];
      allowedUDPPorts = [ 3702 ];
    };

    services = {
      samba = {
        enable = true;
        openFirewall = true;
        settings = {
          global = lib.mkMerge [
            {
              workgroup = lib.mkDefault "WORKGROUP";
              "server string" = lib.mkDefault config.networking.hostName;
              "netbios name" = lib.mkDefault config.networking.hostName;
              "security" = lib.mkDefault "user";
              "invalid users" = [ "root" ];
              "guest account" = lib.mkDefault "nobody";
              "map to guest" = lib.mkDefault "bad user";
              "passdb backend" = lib.mkDefault "tdbsam";
            }
            cfg.globalSettings
          ];
        }
        // builtins.mapAttrs (
          _name: share:
          cfg.commonSettings
          // {
            "path" = share.path;
            "read only" = if share.readOnly then "yes" else "no";
          }
          // share.extraSettings
        ) cfg.shares;
      };
      samba-wsdd.enable = true; # make shares visible for windows 10 clients
      avahi = {
        enable = true;
        nssmdns4 = true;
        publish = {
          enable = true;
          addresses = true;
          domain = true;
          hinfo = true;
          userServices = true;
          workstation = true;
        };
        extraServiceFiles = {
          smb = ''
            <?xml version="1.0" standalone='no'?><!--*-nxml-*-->
            <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
            <service-group>
            <name replace-wildcards="yes">%h</name>
            <service>
            <type>_smb._tcp</type>
            <port>445</port>
            </service>
            </service-group>
          '';
        };
      };
    };
  };
}
