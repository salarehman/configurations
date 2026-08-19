{ config, pkgs, ... }:

let
  configDir   = "/home/sabotabby/.config";
  botSshKey   = "/home/sabotabby/secrets/github/botkey";
  botGitName  = "Lily-Jiji";
  botGitEmail = "salahdin.ur-rehman@proton.me";
  repoUrl     = "git@github.com:salarehman/configurations.git";

  backupScript = pkgs.writeShellScript "nixos-config-backup" ''
    set -euo pipefail
    cd "${configDir}"

    export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i ${botSshKey} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

    watch() {
      ${pkgs.inotify-tools}/bin/inotifywait -r -e modify,create,delete,move \
        --exclude '\.git' -t "$1" "${configDir}" >/dev/null 2>&1
    }

    while true; do
      ${pkgs.inotify-tools}/bin/inotifywait -r -e modify,create,delete,move \
        --exclude '\.git' "${configDir}" >/dev/null 2>&1

      while watch 10; do :; done

      ${pkgs.git}/bin/git add -A

      if ! ${pkgs.git}/bin/git diff --cached --quiet; then
        TIMESTAMP="$(date +"%Y-%m-%d_%H-%M-%S")"
        HOST="$(cat /etc/hostname)"
        ${pkgs.git}/bin/git -c user.name="${botGitName}" -c user.email="${botGitEmail}" \
          commit -m "auto-backup: ''${HOST} ''${TIMESTAMP}"
        ${pkgs.git}/bin/git push origin HEAD
      fi
    done
  '';

  setupScript = pkgs.writeShellScript "nixos-config-backup-setup" ''
    set -euo pipefail

    if [ ! -f "${botSshKey}" ]; then
      mkdir -p "$(dirname "${botSshKey}")"
      ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f "${botSshKey}" -C "${botGitName}" -N ""
      chown sabotabby:users "$(dirname "${botSshKey}")" "${botSshKey}" "${botSshKey}.pub"
      chmod 700 "$(dirname "${botSshKey}")"
      chmod 600 "${botSshKey}"
      chmod 644 "${botSshKey}.pub"
      echo "==> Generated new bot SSH key at ${botSshKey}.pub — add it to GitHub as a Deploy Key."
    fi

    if [ ! -d "${configDir}/.git" ]; then
      cd "${configDir}"
      ${pkgs.git}/bin/git init
      ${pkgs.git}/bin/git remote add origin "${repoUrl}"
      echo "==> Initialized git repo in ${configDir} with remote ${repoUrl}"
    fi
  '';
in
{
  system.activationScripts.nixosConfigBackupSetup = {
    text = "${setupScript}";
    deps = [];
  };

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
