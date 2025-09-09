{ lib
, stdenv
, fetchFromGitHub
, gradle
, jdk21
, makeWrapper
, copyDesktopItems
, makeDesktopItem
, wrapGAppsHook
, gtk3
, gsettings-desktop-schemas
}:

stdenv.mkDerivation rec {
  pname = "ab-download-manager";
  version = "1.6.8";

  src = fetchFromGitHub {
    owner = "amir1376";
    repo = "ab-download-manager";
    rev = "v${version}";
    # Update this hash after first build attempt
    hash = "sha256-bkLnkWdeE2euZR8r43pSMjAFg045lV3msKJPSN9OJJI=";
  };

  nativeBuildInputs = [
    gradle
    jdk21
    makeWrapper
    copyDesktopItems
    wrapGAppsHook
  ];

  buildInputs = [
    gtk3
    gsettings-desktop-schemas
  ];

  __darwinAllowLocalNetworking = true;

  gradleFlags = [ "--no-daemon" ];

  buildPhase = ''
    runHook preBuild
    
    export GRADLE_USER_HOME=$(mktemp -d)
    gradle $gradleFlags createReleaseFolderForCi
    
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/{bin,lib,share}
    
    # Copy the built application
    cp -r build/ci-release/* $out/lib/
    
    # Create wrapper script
    makeWrapper ${jdk21}/bin/java $out/bin/ab-download-manager \
      --add-flags "-jar $out/lib/ABDownloadManager.jar" \
      --set JAVA_HOME "${jdk21}" \
      --prefix PATH : "${lib.makeBinPath [ jdk21 ]}"
    
    # Install icon
    mkdir -p $out/share/pixmaps
    cp shared/resources/icon/app_icon.png $out/share/pixmaps/ab-download-manager.png
    
    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "ab-download-manager";
      desktopName = "AB Download Manager";
      comment = "A download manager that speeds up your downloads";
      exec = "ab-download-manager";
      icon = "ab-download-manager";
      categories = [ "Network" "FileTransfer" ];
      mimeTypes = [ "x-scheme-handler/http" "x-scheme-handler/https" ];
      startupNotify = true;
    })
  ];

  meta = with lib; {
    description = "A download manager that speeds up your downloads";
    homepage = "https://abdownloadmanager.com";
    license = licenses.asl20;
    maintainers = [ ];
    platforms = platforms.linux;
    mainProgram = "ab-download-manager";
  };
}
