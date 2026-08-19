
{ config, pkgs, ... }:

let
  # -----------------------------------------------------------------
  # EDIT THESE FOUR VALUES FOR YOUR SETUP
  # -----------------------------------------------------------------
  configDir   = "/home/sabotabby/.config";                      # folder to watch & push
  botSshKey   = "/home/sabotabby/secrets/github/botkey";    # PRIVATE key path, kept outside configDir
  botGitName  = "Lily-Jiji";
  botGitEmail = "salahdin.ur-rehman@proton.me";
  repoUrl     = "git@github.com:salarehman/configurations.git"; 
  # -----------------------------------------------------------------

  gitBotConfig = pkgs.writeText "git-bot-config" ''
    [user]
      name = ${botGitName}
      email = ${botGitEmail}
    [core]
      sshCommand = "${pkgs.openssh}/bin/ssh -i ${botSshKey} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
  '';

  backupScript = pkgs.writeShellScript "nixos-config-backup" ''
    set -euo pipefail
    cd "${configDir}"

    watch() {
      ${pkgs.inotify-tools}/bin/inotifywait -r -e modify,create,delete,move \
        --exclude '\.git' -t "$1" "${configDir}" >/dev/null 2>&1
    }

    while true; do
      ${pkgs.inotify-tools}/bin/inotifywait -r -e modify,create,delete,move \
        --exclude '\.git' "${configDir}" >/dev/null 2>&1

      # Debounce: keep waiting until a 10s quiet period passes
      while watch 10; do :; done

      ${pkgs.git}/bin/git add -A

      if ! ${pkgs.git}/bin/git diff --cached --quiet; then
        TIMESTAMP="$(date +"%Y-%m-%d_%H-%M-%S")"
        HOST="$(cat /etc/hostname)"
        ${pkgs.git}/bin/git commit -m "auto-backup: ''${HOST} ''${TIMESTAMP}"
        ${pkgs.git}/bin/git push origin HEAD
      fi
    done
  '';

  setupScript = pkgs.writeShellScript "nixos-config-backup-setup" ''
    set -euo pipefail

    # 1. Generate the bot's SSH key, only if it doesn't already exist.
    if [ ! -f "${botSshKey}" ]; then
      mkdir -p "$(dirname "${botSshKey}")"
      ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f "${botSshKey}" -C "${botGitName}" -N ""
      chmod 700 "$(dirname "${botSshKey}")"
      chmod 600 "${botSshKey}"
      chmod 644 "${botSshKey}.pub"
      echo "==> Generated new bot SSH key at ${botSshKey}.pub — you still need to add it to GitHub as a Deploy Key."
    fi

    # 2. Turn configDir into a git repo pointed at your GitHub repo,
    #    only if it isn't one already.
    if [ ! -d "${configDir}/.git" ]; then
      cd "${configDir}"
      ${pkgs.git}/bin/git init
      ${pkgs.git}/bin/git remote add origin "${repoUrl}"
      echo "==> Initialized git repo in ${configDir} with remote ${repoUrl}"
    fi
  '';
in
{
  # Runs on every `nixos-rebuild switch`, but both steps inside are
  # idempotent (check-before-act), so it's safe to rebuild repeatedly.
  system.activationScripts.nixosConfigBackupSetup = {
    text = "${setupScript}";
    deps = [];
  };

  # Applies the bot identity + SSH key ONLY when git is run inside
  # configDir — your normal git usage elsewhere is untouched.
  # NOTE: this manages the whole /etc/gitconfig file. If you later add
  # other global git settings, add them here too or they'll be
  # overwritten on rebuild.
  environment.etc."gitconfig".text = ''
    [includeIf "gitdir:${configDir}/"]
      path = ${gitBotConfig}
  '';

  systemd.services.nixos-config-backup = {
    description = "Auto-commit and push NixOS config changes to GitHub";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "sabotabby";
      Group = "users";
      Environment = "HOME=/home/sabotabby";
      ExecStart = "${backupScript}";
      Restart = "always";
      RestartSec = 5;
    };
  };
}

# Hellooo test test test
