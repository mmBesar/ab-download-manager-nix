{ lib
, stdenv
, fetchFromGitHub
, gradle
, jdk21
, makeWrapper
, copyDesktopItems
, makeDesktopItem
, cacert
}:

let
  # Create a separate derivation for the Gradle build with network access
  gradleBuild = stdenv.mkDerivation {
    pname = "ab-download-manager-gradle-build";
    version = "1.6.8";
    
    src = fetchFromGitHub {
      owner = "amir1376";
      repo = "ab-download-manager";
      rev = "v1.6.8";
      hash = "sha256-bkLnkWdeE2euZR8r43pSMjAFg045lV3msKJPSN9OJJI=";
    };

    nativeBuildInputs = [ gradle jdk21 cacert ];
    
    # This is a fixed-output derivation that can access network
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = lib.fakeHash; # Will be replaced with real hash
    
    buildPhase = ''
      export GRADLE_USER_HOME=$(mktemp -d)
      export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
      
      # Use system Gradle, not wrapper (avoids download)
      gradle --no-daemon createReleaseFolderForCi
    '';
    
    installPhase = ''
      mkdir -p $out
      cp -r build/ci-release/* $out/ 2>/dev/null || cp -r build/libs/* $out/ 2>/dev/null || cp -r build/* $out/
    '';
  };
in
stdenv.mkDerivation rec {
  pname = "ab-download-manager";
  version = "1.6.8";

  src = gradleBuild;

  nativeBuildInputs = [
    makeWrapper
    copyDesktopItems
  ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/{bin,share/ab-download-manager}
    
    # Copy the pre-built files
    cp -r $src/* $out/share/ab-download-manager/
    
    # Find the JAR file
    JAR_FILE=$(find $out/share/ab-download-manager -name "*.jar" | head -1)
    
    if [ -z "$JAR_FILE" ]; then
      echo "No JAR file found! Available files:"
      find $out/share/ab-download-manager -type f
      exit 1
    fi
    
    echo "Found JAR: $JAR_FILE"
    
    # Create wrapper script
    makeWrapper ${jdk21}/bin/java $out/bin/ab-download-manager \
      --add-flags "-jar $JAR_FILE" \
      --set JAVA_HOME "${jdk21}"
    
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
