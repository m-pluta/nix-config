{ pkgs, ... }:
{
  hardware.graphics.enable = true;

  hardware.amdgpu = {
    initrd.enable = true;
    # opencl.enable = true; # ML/compute workloads
  };

  environment.systemPackages = with pkgs; [
    libva-utils # vainfo to verify VAAPI codec support
    nvtopPackages.amd
    # rocmPackages.rocm-smi # ML/compute workloads
  ];
}
