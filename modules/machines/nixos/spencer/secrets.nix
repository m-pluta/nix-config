{ inputs, lib, ... }:
{
  age.secrets = {
    wireguardPrivateKeySpencer = {
      file = "${inputs.secrets}/wireguardPrivateKeySpencer.age";
      owner = "systemd-network";
    };
    matrixRegistrationSecret = {
      owner = "matrix-synapse";
      group = "matrix-synapse";
      file = "${inputs.secrets}/matrixRegistrationSecret.age";
    };
    plausibleSecretKeybaseFile = {
      owner = "plausible";
      group = "plausible";
      file = "${inputs.secrets}/plausibleSecretKeybaseFile.age";
    };
    forgejoRunnerTokenSpencer = {
      owner = "gitea-runner";
      group = "gitea-runner";
      file = "${inputs.secrets}/forgejoRunnerTokenSpencer.age";
    };
    atticTokenSpencer = {
      owner = "atticd";
      group = "atticd";
      file = "${inputs.secrets}/atticTokenFile.age";
    };
    smtpPassword = {
      owner = "notthebee";
      group = lib.mkForce "forgejo";
      mode = "0440";
    };
    fmatrixSecretsFile.file = "${inputs.secrets}/fmatrixSecretsFile.age";
    cloudflareDnsApiCredentialsNotthebee.file = "${inputs.secrets}/cloudflareDnsApiCredentialsNotthebee.age";
  };
}
