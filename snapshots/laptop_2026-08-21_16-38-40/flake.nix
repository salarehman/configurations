{



	description = "my first flake";


	inputs = {
		
		nixpkgs = {
			url = "github:NixOS/nixpkgs/nixos-26.05";
		};

		home-manager = {
		    url = "github:nix-community/home-manager/release-26.05";
		    inputs.nixpkgs.follows = "nixpkgs";
		};

		nix-doom-emacs-unstraightened = {
    			url = "github:marienz/nix-doom-emacs-unstraightened";
    			inputs = {
				doomdir.url = "/home/sabotabby/.config/doom/doom.d";
     			};
		};
		
	};
	

	outputs = {self, nixpkgs, home-manager, ...}:
	let
	  lib = nixpkgs.lib;
	in {

		nixosConfigurations = {

			laptop = lib.nixosSystem {
				system = "x86_64-linux";
				modules = [

					./configuration.nix
					./config-backup.nix
					home-manager.nixosModules.home-manager
				];
			};
		};
	};





}
