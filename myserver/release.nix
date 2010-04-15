{ nixpkgs ? ../../nixpkgs }:

let
  meta = {
    description = "GNU MyServer, a powerful and easy to configure web server";

    longDescription = ''
      GNU MyServer is a powerful and easy to configure web server.  Its
      multi-threaded architecture makes it extremely scalable and usable in
      large scale sites as well as in small networks, it has a lot of
      built-in features.  Share your files in minutes!
    '';

    homepage = http://www.gnu.org/software/myserver/;

    license = "GPLv3+";

    # Those who will receive notifications.
    maintainers = [ "myserver-commit@gnu.org" ];
  };

  pkgs = import nixpkgs {};

  inherit (pkgs) releaseTools;

  buildInputsFrom = pkgs: with pkgs;
    [ libgcrypt libevent libidn gnutls libxml2 zlib texinfo cppunit ];

  jobs = rec {

    tarball =
      { myserverSrc ? { outPath = /data/src/myserver; },
        gnulibSrc ? ((import ../gnulib.nix) pkgs)
      }:

      releaseTools.sourceTarball {
	name = "myserver-tarball";
	src = myserverSrc;

        # Somehow "make dist" alone fails.
        dontBuild = false;
        doCheck = false;

        autoconfPhase = ''
          cd myserver

          cp -Rv "${gnulibSrc}" ../gnulib
          chmod -R 755 ../gnulib

          ./bootstrap --gnulib-srcdir=../gnulib --copy
        '';

	buildInputs = (buildInputsFrom pkgs)
          ++ (with pkgs;
              [ autoconf automake111x perl git
                gettext cvs  # cvs is used by `autopoint'
              ]);

        inherit meta;
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "myserver";
          src = tarball;
          buildInputs = buildInputsFrom pkgs;
          inherit meta;
        };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.coverageAnalysis {
	name = "myserver-coverage";
	src = tarball;
	buildInputs = buildInputsFrom pkgs;
        configureFlags = "--with-ncurses-include-dir=${pkgs.ncurses}/include";
        inherit meta;
      };

    manual =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.nixBuild {
        name = "myserver-manual";
        src = tarball;
        buildInputs = (buildInputsFrom pkgs)
          ++ [ pkgs.texinfo pkgs.texLive ];

        buildPhase = "make -C documentation html pdf";
        doCheck = false;
        installPhase =
          '' make -C documentation install-html install-pdf

             ensureDir "$out/nix-support"
             echo "doc manual $out/share/doc/myserver/myserver.html index.html" >> "$out/nix-support/hydra-build-products"
             echo "doc-pdf manual $out/share/doc/myserver/myserver.pdf" >> "$out/nix-support/hydra-build-products"
          '';
        inherit meta;
      };
  };

in jobs
