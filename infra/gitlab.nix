{ gitlabUrl, ... }:
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
}
