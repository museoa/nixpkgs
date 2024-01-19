/* Version string functions. */
{ lib }:

rec {

  /* Break a version string into its component parts.

     Example:
       splitVersion "1.2.3"
       => ["1" "2" "3"]
  */
  splitVersion = builtins.splitVersion;

  /* Get the major version string from a string.

    Example:
      major "1.2.3"
      => "1"
  */
  major = v: builtins.elemAt (splitVersion v) 0;

  /* Get the minor version string from a string.

    Example:
      minor "1.2.3"
      => "2"
  */
  minor = v: builtins.elemAt (splitVersion v) 1;

  /* Get the patch version string from a string.

    Example:
      patch "1.2.3"
      => "3"
  */
  patch = v: builtins.elemAt (splitVersion v) 2;

  /* Get string of the first two parts (major and minor)
     of a version string.

     Example:
       majorMinor "1.2.3"
       => "1.2"
  */
  majorMinor = v:
    builtins.concatStringsSep "."
    (lib.take 2 (splitVersion v));

  /* Pad a version string with zeros to match the given number of components.

     Example:
       pad 3 "1.2"
       => "1.2.0"
       pad 3 "1.3-rc1"
       => "1.3.0-rc1"
       pad 3 "1.2.3.4"
       => "1.2.3"
  */
  pad = n: version: let
    numericVersion = lib.head (lib.splitString "-" version);
    versionSuffix = lib.removePrefix numericVersion version;
  in lib.concatStringsSep "." (lib.take n (lib.splitVersion numericVersion ++ lib.genList (_: "0") n)) + versionSuffix;

  # lib.compareVersions, extended to allow `null` as the maximal version
  compare = v1: v2:
    if      v1==null && v2==null then 0
    else if v1==null             then 1
    else if             v2==null then -1
    else builtins.compareVersions v1 v2;

  # Check if a version matches a versionSpec.  A versionSpec is
  # either:
  # - a string consisting of a version prefixed with one of: ">=", "<=", "<", ">", or "="
  # - a list of versionSpecs, interpreted as a disjunction (logical-or)
  match = versionSpec: version:
    if lib.isList versionSpec
    then lib.any (spec: match spec version) versionSpec
    else if lib.hasPrefix "<=" versionSpec
    then lib.versions.compare version (lib.removePrefix "<=" versionSpec) <= 0
    else if lib.hasPrefix ">=" versionSpec
    then lib.versions.compare version (lib.removePrefix ">=" versionSpec) >= 0
    else if lib.hasPrefix "<" versionSpec
    then lib.versions.compare version (lib.removePrefix "<" versionSpec) < 0
    else if lib.hasPrefix ">" versionSpec
    then lib.versions.compare version (lib.removePrefix ">" versionSpec) > 0
    else if lib.hasPrefix "=" versionSpec
    then lib.versions.compare version (lib.removePrefix "=" versionSpec) == 0
    else throw "unrecognized versionSpec: ${versionSpec}";

  # makeVersioned: constructs a pkg.__versions set, and returns its
  # best element.
  #
  # This function takes a recursive attrset
  #
  #   versionsFunc :: AttrsOf<Pkg> -> AttrsOf<Pkg>
  #
  # whose fixpoint will be the __versions attribute of each Pkg.
  # Specifically, this function will tie the fixpoint knot, insert
  # the final __versions attribute into each versioned package, and
  # project out the best version __versions.best.
  #
  # pkg.__versions has the following attributes which may be
  # overridden using pkg.__versions.extends:
  #
  # - unstable : String or null = the least unstable version
  #   identifier (which need not be present in the attrNames of
  #   __versions).  All versions greater than or equal to this are
  #   considered unstable; all versions strictly less than this are
  #   considered stable.  The `null` value means "infinity"
  #   (i.e. there are no unstable versions)
  #
  # __versions has the following attributes which should not be
  # overridden using pkg.__versions.extends:
  #
  # - best : Pkg = the newest stable package (i.e. attrvalue whose
  #   attrname is lib.versions.compare-wise largest but strictly
  #   less than __versions.unstable).
  #
  # - require : VersionSpec -> Pkg = a function which accepts a
  #   VersionSpec string (see lib.versions.match), deletes from
  #   __versions all versions which do not match the specification,
  #   and then returns the .best attribute of the resulting
  #   __versions.
  #
  makeVersioned = let

    # insert the __versions attrset into passthru of each package
    lastOverlay = final: prev:
      lib.flip lib.mapAttrs prev
        (ver: pkg:
          if !(lib.isDerivation pkg) then pkg
          # stdenv doesn't have .overrideAttrs....
          else if !(pkg?overrideAttrs) then pkg // { __versions = final; }
          else pkg.overrideAttrs (previousAttrs: {
            passthru = previousAttrs.passthru // {
              __versions = final;
            };
          }));

    # find the package with maximal version less than `unstable`
    findBest = final: lib.pipe final [
      (lib.filterAttrs (ver: pkg: ver != "best" && lib.isDerivation pkg))
      lib.attrNames
      (lib.filter (ver: lib.versions.compare (final.unstable or null) ver >= 0))
      (lib.sort (v1: v2: builtins.compareVersions v1 v2 < 0))
      (list:
        assert list == [] -> throw "no versions remain after filtering!";
        lib.last list)
      (attrName: final.${attrName})
    ];

    # filter a __versions set, leaving only the versions which match `versionSpec`
    require = final: versionSpec:
      final.extends (final: prev:
        lib.flip lib.mapAttrs prev
          (ver: pkg:
            if !(lib.isDerivation pkg) then pkg
            else if lib.versions.match versionSpec ver then pkg
            else null));

  in versionsFunc:
    lib.makeExtensible' {
      postFunc = final: final.best;
      inherit lastOverlay;
    }
      (final: {
        unstable = null;
        best = findBest final;
        require = require final;
      } // versionsFunc final);
}
