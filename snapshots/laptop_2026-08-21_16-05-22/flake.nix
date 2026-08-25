{



	description = "my first flake";


	inputs = {
		
		nixpkgs = {
			url = "github:NixOS/nixpkgs/nixos-26.05";
		};

		nix-doom-emacs-unstraightened = {
    			url = "github:marienz/nix-doom-emacs-unstraightened";
    			inputs = {
			doomdir.url = "/home/sabotabby/.config/doom/doom.d";
     };
  };
	};

	

	outputs = {self, nixpkgs, ...}:
	let
	  lib = nixpkgs.lib;
	in {

		nixosConfigurations = {

			laptop = lib.nixosSystem {
				system = "x86_64-linux";
				modules = [

					./configuration.nix
					./config-backup.nix	
				];
			};
		};
	};





}
