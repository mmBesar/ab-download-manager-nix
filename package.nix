{ lib
, stdenv
, fetchFromGitHub
, gradle
, jdk21
, makeWrapper
, copyDesktopItems
, makeDesktopItem
}:

stdenv.mkDerivation rec {
  pname = "ab-download-manager";
  version = "1.6.8";

  src = fetchFromGitHub {
    owner = "amir1376";
    repo = "ab-download-manager";
    rev = "v${version}";
    hash = "sha256-bkLnkWdeE2euZR8r43pSMjAFg045lV3msKJPSN9OJJI=";
  };

  nativeBuildInputs = [
    gradle
    jdk21
    makeWrapper
    copyDesktopItems
  ];

  # Allow network access for Gradle to download dependencies
  __darwinAllowLocalNetworking = true;

  buildPhase = ''
    runHook preBuild
    
    export GRADLE_USER_HOME=$(mktemp -d)
    export GRADLE_OPTS="-Dorg.gradle.daemon=false -Dorg.gradle.parallel=false"
    
    # Try to build with more verbose output and proper Java version
    gradle --no-daemon --stacktrace --info createReleaseFolderForCi || {
      echo "First build attempt failed, trying alternative tasks..."
      gradle --no-daemon tasks --all
      echo "Available tasks listed above"
      
      # Try alternative build tasks
      gradle --no-daemon build || gradle --no-daemon assemble
    }
    
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/{bin,lib,share}
    
    echo "Build output directory contents:"
    find build -type f -name "*.jar" || true
    ls -la build/ || true
    
    # Look for output in various possible locations
    if [ -d "build/ci-release" ]; then
      echo "Found ci-release directory"
      cp -r build/ci-release/* $out/lib/
    elif [ -d "build/libs" ]; then
      echo "Found libs directory"  
      cp -r build/libs/* $out/lib/
    elif [ -d "build/distributions" ]; then
      echo "Found distributions directory"
      cp -r build/distributions/* $out/lib/
    else
      echo "Looking for any JAR files..."
      find build -name "*.jar" -exec cp {} $out/lib/ \;
    fi
    
    # Find the main JAR file
    MAIN_JAR=$(find $out/lib -name "*.jar" -type f | head -n1)
    
    if [ -z "$MAIN_JAR" ]; then
      echo "No JAR file found after build!"
      echo "Contents of $out/lib:"
      ls -la $out/lib/ || true
      exit 1
    fi
    
    echo "Using JAR: $MAIN_JAR"
    
    # Create wrapper script
    makeWrapper ${jdk21}/bin/java $out/bin/ab-download-manager \
      --add-flags "-jar $MAIN_JAR" \
      --set JAVA_HOME "${jdk21}" \
      --prefix PATH : "${lib.makeBinPath [ jdk21 ]}"
    
    # Install icon if available
    for icon_path in "shared/resources/icon/app_icon.png" "resources/icon/app_icon.png" "app_icon.png"; do
      if [ -f "$icon_path" ]; then
        mkdir -p $out/share/pixmaps
        cp "$icon_path" $out/share/pixmaps/ab-download-manager.png
        break
      fi
    done
    
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
