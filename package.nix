{ lib
, stdenv
, fetchurl
, jdk21
, makeWrapper
, copyDesktopItems
, makeDesktopItem
, unzip
}:

stdenv.mkDerivation rec {
  pname = "ab-download-manager";
  version = "1.6.8";

  # Use pre-built Linux release instead of building from source
  src = fetchurl {
    url = "https://github.com/amir1376/ab-download-manager/releases/download/v${version}/ABDownloadManager-${version}-linux.tar.gz";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Update this
  };

  nativeBuildInputs = [
    makeWrapper
    copyDesktopItems
    unzip
  ];

  unpackPhase = ''
    runHook preUnpack
    tar -xzf $src
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/{bin,lib,share}
    
    # Copy all files
    cp -r * $out/lib/
    
    # Find the main JAR file
    MAIN_JAR=$(find $out/lib -name "*.jar" -type f | head -n1)
    
    if [ -z "$MAIN_JAR" ]; then
      echo "No JAR file found! Contents:"
      find $out/lib -type f
      exit 1
    fi
    
    echo "Found JAR: $MAIN_JAR"
    
    # Create wrapper script
    makeWrapper ${jdk21}/bin/java $out/bin/ab-download-manager \
      --add-flags "-jar $MAIN_JAR" \
      --set JAVA_HOME "${jdk21}" \
      --prefix PATH : "${lib.makeBinPath [ jdk21 ]}"
    
    # Install icon if it exists
    if [ -f $out/lib/icon.png ]; then
      mkdir -p $out/share/pixmaps
      cp $out/lib/icon.png $out/share/pixmaps/ab-download-manager.png
    elif [ -f $out/lib/app_icon.png ]; then
      mkdir -p $out/share/pixmaps
      cp $out/lib/app_icon.png $out/share/pixmaps/ab-download-manager.png
    fi
    
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
