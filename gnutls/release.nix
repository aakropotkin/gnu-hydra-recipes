{ nixpkgs ? ../../nixpkgs }:

let
  meta = {
    description = "The GNU Transport Layer Security Library";

    longDescription = ''
       GnuTLS is a project that aims to develop a library which
       provides a secure layer, over a reliable transport
       layer. Currently the GnuTLS library implements the proposed
       standards by the IETF's TLS working group.

       Quoting from the TLS protocol specification:

       "The TLS protocol provides communications privacy over the
       Internet. The protocol allows client/server applications to
       communicate in a way that is designed to prevent eavesdropping,
       tampering, or message forgery."
    '';

    homepage = http://www.gnu.org/software/gnutls/;
    license = "LGPLv2.1+";

    # Where notification emails go.
    maintainers = [ "gnutls-commits@gnu.org" ];
  };

  pkgs = import nixpkgs {};

  inherit (pkgs) releaseTools;

  buildInputsFrom = pkgs:
    with pkgs; [ zlib lzo guile gettext pkgconfig perl ];

  jobs = rec {

    tarball =
      { gnutlsSrc ? { outPath = /data/src/gnutls; }
      , libtasn1 ? pkgs.libtasn1
      , libgcrypt ? pkgs.libgcrypt
      }:

      releaseTools.sourceTarball {
	name = "gnutls-tarball";
	src = gnutlsSrc;

        # "make dist" alone won't work (`doc/error_codes.texi' depends on
        # `doc/errcodes', which depends on `libgnutls.la'), so run "make"
        # before.
        dontBuild = false;

        patchPhase =
          # Remove occurrences of /usr/bin/perl and /bin/bash.
          '' for i in                           \
                tests/nist-pkits/build-chain    \
                doc/scripts/sort2.pl            \
                doc/scripts/gdoc                \
                doc/doxygen/Doxyfile.orig       \
                doc/doxygen/Doxyfile.in
             do
               echo "patching \`/usr/bin/perl' in \`$i'..."
               sed -i "$i" -e's|/usr/bin/perl|${pkgs.perl}/bin/perl|g'
             done

             for i in "tests/"*"/"*
             do
               if grep -q /bin/bash "$i"
               then
                 echo "patching \`/bin/bash' in \`$i'..."
                 sed -i "$i" -e's|/bin/bash|/bin/sh|g'
               fi
             done
          '';

        doCheck = false;

        autoconfPhase = "make";
        configureFlags =
          "--with-lzo --with-libtasn1-prefix=${libtasn1} --enable-guile"
          + " --enable-gtk-doc";
	buildInputs = (buildInputsFrom pkgs)
          ++ [ libtasn1 libgcrypt ]
          ++ (with pkgs;
              [ autoconf automake111x git
                texinfo help2man
                cvs # for `autopoint'
                gnome.gtkdoc docbook_xsl
                libxml2 # for its setup-hook
                texinfo texLive
              ]);

        inherit meta;
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      , libtasn1 ? pkgs.libtasn1
      , libgcrypt ? pkgs.libgcrypt
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "gnutls";
          src = tarball;
          configureFlags =
            "--with-lzo --with-libtasn1-prefix=${libtasn1} --enable-guile";
          buildInputs = (buildInputsFrom pkgs) ++ [ libtasn1 libgcrypt ];
          inherit meta;
        };

    coverage =
      { tarball ? jobs.tarball {}
      , libtasn1 ? pkgs.libtasn1
      , libgcrypt ? pkgs.libgcrypt
      }:

      releaseTools.coverageAnalysis {
	name = "gnutls-coverage";
	src = tarball;
        configureFlags =
          "--with-lzo --with-libtasn1-prefix=${libtasn1} --enable-guile";
        buildInputs = (buildInputsFrom pkgs) ++ [ libtasn1 libgcrypt ];
        inherit meta;
      };

    manual =
      { tarball ? jobs.tarball {}
      , libtasn1 ? pkgs.libtasn1
      , libgcrypt ? pkgs.libgcrypt
      }:

      releaseTools.nixBuild {
        name = "gnutls-manual";
        src = tarball;
        configureFlags =
          "--with-lzo --with-libtasn1-prefix=${libtasn1} --enable-guile";
        buildInputs = (buildInputsFrom pkgs)
          ++ [ libtasn1 libgcrypt ]
          ++ [ pkgs.texinfo pkgs.texLive ];

        buildPhase = "make -C doc html pdf";
        doCheck = false;
        installPhase =
          '' make -C doc install-html install-pdf

             ensureDir "$out/nix-support"
             echo "doc manual $out/share/doc/gnutls/gnutls.html" >> "$out/nix-support/hydra-build-products"
             echo "doc-pdf manual $out/share/doc/gnutls/gnutls.pdf" >> "$out/nix-support/hydra-build-products"
          '';
        inherit meta;
      };
  };

in jobs