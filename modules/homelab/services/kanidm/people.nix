# Kanidm's people. Each still needs `just invite <name>` to set up their login, and
# `groups` decides which services they can use, through each service's <name>.access group.
{
  mikey = {
    displayName = "Mikey";
    mailAddresses = [ "mikey@mpluta.dev" ];
    groups = [
      "immich.access"
      "grafana.access"
    ];
  };
}
