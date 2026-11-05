{ cloudflareAccountId, ... }:
{
  resource.cloudflare_zone.mpluta_dev = {
    account.id = cloudflareAccountId;
    name = "mpluta.dev";
    type = "full";
    # Deleting a zone loses every record and setting in it, so OpenTofu refuses to.
    lifecycle.prevent_destroy = true;
  };
}
