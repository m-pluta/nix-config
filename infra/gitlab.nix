{ gitlabUrl, ... }:
let
  # main only takes merge requests
  branchProtection = {
    allowed_to_push = [ "no one" ];
    allowed_to_merge = [ "maintainer" ];
    allow_force_push = false;
    developer_can_initial_push = false;
  };
in
{
  terraform.required_providers.gitlab = {
    source = "gitlabhq/gitlab";
    version = "~> 19.5";
  };

  # The API token comes from GITLAB_TOKEN.
  provider.gitlab.base_url = "https://${gitlabUrl}/api/v4";

  resource.gitlab_application_settings.this = {
    signup_enabled = false;
    gravatar_enabled = false;
    usage_ping_enabled = false;
    auto_devops_enabled = false;
    import_sources = [ ];
    default_branch_name = "main";
    default_project_visibility = "private";
    default_group_visibility = "private";
  };

  resource.gitlab_group.homelab = {
    name = "homelab";
    path = "homelab";
    description = "Homelab configuration, secrets and CI";
    # Flake inputs are fetched without a token
    visibility_level = "public";
    default_branch = "main";
    auto_devops_enabled = false;
    request_access_enabled = false;
    default_branch_protection_defaults = branchProtection;
  };

  data.gitlab_user.mikey.username = "mikey";

  resource.gitlab_group_membership.homelab_mikey = {
    group_id = "\${gitlab_group.homelab.id}";
    user_id = "\${data.gitlab_user.mikey.id}";
    access_level = "owner";
  };
}
