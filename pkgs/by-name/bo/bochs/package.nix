{
  lib,
  SDL2,
  curl,
  darwin,
  docbook_xml_dtd_45,
  docbook_xsl,
  fetchurl,
  gtk3,
  libGL,
  libGLU,
  libX11,
  libXpm,
  libtool,
  ncurses,
  pkg-config,
  readline,
  stdenv,
  wget,
  wxGTK32,
}@packages:

let
  source = {
    pname = "bochs";
    version = "2.8";
    hash = "sha256-qFsTr/fYQR96nzVrpsM7X13B+7EH61AYzCOmJjnaAFk=";  
  };
  
  configuration = {
    enableSDL2 = true;
    enableTerm = true;
    enableWx = !stdenv.hostPlatform.isDarwin;
    enableX11 = !stdenv.hostPlatform.isDarwin;
  };
in
import ./make-bochs.nix packages source configuration
