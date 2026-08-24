{ config, pkgs, ... }:

{
  # SSH config - system level
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
    hostKeys = [];
  };

  # SSH client config for users
  programs.ssh = {
    startAgent = true;
    extraConfig = ''
      Host github.com
        User git
        IdentityFile ~/secrets/github/personal_key
        IdentitiesOnly yes
        
      Host github.com-jijikiki
        User git
        IdentityFile ~/secrets/github/botkey
        IdentitiesOnly yes
    '';
  };

  # Ensure secrets directory exists
  system.activationScripts.ensureSecretsDir = {
    text = ''
      mkdir -p /home/sabotabby/secrets/github
      chown -R sabotabby:users /home/sabotabby/secrets
      chmod 700 /home/sabotabby/secrets
      chmod 700 /home/sabotabby/secrets/github
    '';
    deps = [];
  };

  # Home-manager config for user Git settings
  home-manager.users.sabotabby = { pkgs, ... }: {
    programs.git = {
      enable = true;
      userName = "Salarehman";
      userEmail = "salahdin.ur-rehman@proton.me";
      aliases = {
        co = "checkout";
        br = "branch";
        ci = "commit";
        st = "status";
      };
      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = false;
        core = {
          editor = "nvim";
          autocrlf = "input";
        };
        user = {
          name = "Salarehman";
          email = "salahdin.ur-rehman@proton.me";
        };
      };
    };
  };
}
