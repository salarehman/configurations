{



	description = "my first flake";


	inputs = {
		
		nixpkgs = {
			url = "github:NixOS/nixpkgs/nixos-26.05";
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
					
				];
			};
		};
	};





}
