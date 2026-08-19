{ config, pkgs, ... }:

let
  # -----------------------------------------------------------------
  configDir       = "/home/sabotabby/.config";
  snapshotRepoDir = "/home/sabotabby/config-snapshots";
  botSshKey       = "/home/sabotabby/secrets/github/botkey";
  botGitName      = "Lily-Jiji";
  botGitEmail     = "salahdin.ur-rehman@proton.me";
  repoUrl         = "git@github.com:salarehman/configurations.git";
  # -----------------------------------------------------------------

  backupScript = pkgs.writeShellScript "nixos-config-backup" ''
    set -euo pipefail
    export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i ${botSshKey} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
    export PATH="${pkgs.hostname}/bin:${pkgs.coreutils}/bin:${pkgs.inotify-tools}/bin:${pkgs.rsync}/bin:${pkgs.git}/bin:${pkgs.openssh}/bin:$PATH"

    snapshot() {
      HOST="$(hostname)"
      TIMESTAMP="$(date +"%Y-%m-%d_%H-%M-%S")"
      NAME="''${HOST}_''${TIMESTAMP}"
      DEST="${snapshotRepoDir}/snapshots/''${NAME}"

      mkdir -p "$DEST"
      rsync -a --exclude='.git' "${configDir}/" "$DEST/"

      cd "${snapshotRepoDir}"
      
      # Only add the new snapshot folder, not everything
      git add "snapshots/''${NAME}"
      
      # Check if there are changes to commit
      if ! git diff --cached --quiet; then
        git -c user.name="${botGitName}" -c user.email="${botGitEmail}" \
          commit -m "snapshot: ''${NAME}"
        git push origin HEAD
      else
        # Clean up empty snapshot folder if no changes
        rmdir "$DEST" 2>/dev/null || true
      fi
    }

    watch() {
      inotifywait -r -e modify,create,delete,move \
        --exclude '\.git' -t "$1" "${configDir}" >/dev/null 2>&1
    }

    # Baseline snapshot on startup
    snapshot

    while true; do
      inotifywait -r -e modify,create,delete,move \
        --exclude '\.git' "${configDir}" >/dev/null 2>&1

      # Debounce: keep waiting until a 10s quiet period passes
      while watch 300; do :; done

      snapshot
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

    if [ ! -d "${snapshotRepoDir}/.git" ]; then
      export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i ${botSshKey} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
      mkdir -p "${snapshotRepoDir}"
      ${pkgs.git}/bin/git clone "${repoUrl}" "${snapshotRepoDir}" || true
      cd "${snapshotRepoDir}"
      ${pkgs.git}/bin/git checkout -b main 2>/dev/null || ${pkgs.git}/bin/git checkout main 2>/dev/null || true
      chown -R sabotabby:users "${snapshotRepoDir}"
      echo "==> Cloned snapshot repo into ${snapshotRepoDir}"
    fi
  '';
in
{
  system.activationScripts.nixosConfigBackupSetup = {
    text = "${setupScript}";
    deps = [];
  };

  systemd.services.nixos-config-backup = {
    description = "Snapshot NixOS config to a timestamped folder in GitHub on change";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${backupScript}";
      Restart = "always";
      RestartSec = 5;
      User = "sabotabby";
    };
  };
}
