{ cloudflareAccountId, ... }:
{
  resource = {
    cloudflare_zone.ld-linux-x86-64_so = {
      account.id = cloudflareAccountId;
      name = "ld-linux-x86-64.so";
      type = "full";
      # Deleting a zone loses every record and setting in it, so OpenTofu refuses to.
      lifecycle.prevent_destroy = true;
    };

    # Proxied placeholder address, so requests reach Cloudflare's redirect rule.
    cloudflare_dns_record.ld-linux-x86-64_so = {
      zone_id = "\${cloudflare_zone.ld-linux-x86-64_so.id}";
      name = "ld-linux-x86-64.so";
      type = "A";
      content = "192.0.2.1";
      proxied = true;
      ttl = 1;
    };

    cloudflare_ruleset.ld-linux-x86-64_so_redirects = {
      zone_id = "\${cloudflare_zone.ld-linux-x86-64_so.id}";
      name = "default";
      kind = "zone";
      phase = "http_request_dynamic_redirect";
      rules = [
        {
          description = "Rickroll";
          expression = "true";
          action = "redirect";
          action_parameters.from_value = {
            status_code = 302;
            preserve_query_string = true;
            target_url.value = "https://youtu.be/dQw4w9WgXcQ";
          };
        }
      ];
    };
  };
}
