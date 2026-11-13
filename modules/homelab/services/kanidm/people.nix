# Kanidm's people. Each still needs `just invite <name>` to set up their login.
# `allServices` gives a person every service's <name>.access group. `groups` adds single
# groups for people who do not use every service.
{
  mikey = {
    displayName = "Mikey";
    mailAddresses = [ "mikey@mpluta.dev" ];
    allServices = true;
  };
}
