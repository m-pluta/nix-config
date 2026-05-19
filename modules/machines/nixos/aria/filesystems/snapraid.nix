{ ... }:
{
  services.snapraid = {
    enable = true;
    parityFiles = [ "/mnt/parity1/snapraid.parity" ];
    contentFiles = [
      "/mnt/data3/snapraid.content"
      "/mnt/data4/snapraid.content"
    ];
    dataDisks = {
      d3 = "/mnt/data3";
      d4 = "/mnt/data4";
    };
  };
}
