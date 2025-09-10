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

  # Enable network access for Gradle
  __darwinAllowLocalNetworking = true;
  
  # Set up Gradle environment properly
  GRADLE_USER_HOME = "gradle-home";
  
  configurePhase = ''
    runHook preConfigure
    
    # Set up Gradle home
    export GRADLE_USER_HOME=$PWD/gradle-home
    mkdir -p $GRADLE_USER_HOME
    
    # Configure Gradle to use included wrapper if available
    if [ -f ./gradlew ]; then
      chmod +x ./gradlew
      export GRADLE_CMD="./gradlew"
    else
      export GRADLE_CMD="gradle"
    fi
    
    # Set Gradle options
    export GRADLE_OPTS="-Dorg.gradle.daemon=false -Dorg.gradle.parallel=false -Dorg.gradle.configureondemand=false"
    
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    
    echo "Starting Gradle build..."
    echo "Available tasks:"
    $GRADLE_CMD tasks --console=plain || true
    
    echo "Attempting to build..."
    $GRADLE_CMD --no-daemon --stacktrace --info createReleaseFolderForCi || {
      echo "createReleaseFolderForCi failed, trying alternatives..."
      
      # Try other common tasks
      $GRADLE_CMD --no-daemon build || \
      $GRADLE_CMD --no-daemon assemble || \
      $GRADLE_CMD --no-daemon jar || {
        echo "All build attempts failed. Checking what we have..."
        find . -name "*.jar" -type f || true
        exit 1
      }
    }
    
    echo "Build completed, checking outputs..."
    find build -type f -name "*.jar" || true
    
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/{bin,lib,share}
    
    # Look for build outputs in order of preference
    BUILD_OUTPUT=""
    if [ -d "build/ci-release" ]; then
      echo "Found ci-release directory"
      BUILD_OUTPUT="build/ci-release"
    elif [ -d "build/libs" ]; then
      echo "Found libs directory"
      BUILD_OUTPUT="build/libs"
    elif [ -d "build/distributions" ]; then
      echo "Found distributions directory"  
      BUILD_OUTPUT="build/distributions"
    elif [ -d "build/install" ]; then
      echo "Found install directory"
      BUILD_OUTPUT="build/install"
    else
      echo "No standard build directory found, looking for JARs..."
      find build -name "*.jar" -exec cp {} $out/lib/ \; 2>/dev/null || true
    fi
    
    # Copy build output if found
    if [ -n "$BUILD_OUTPUT" ]; then
      cp -r $BUILD_OUTPUT/* $out/lib/ 2>/dev/null || {
        echo "Failed to copy from $BUILD_OUTPUT, trying individual files..."
        find $BUILD_OUTPUT -name "*.jar" -exec cp {} $out/lib/ \;
      }
    fi
    
    # Find the main executable JAR
    MAIN_JAR=""
    
    # Look for common main JAR names
    for jar_name in "ABDownloadManager.jar" "ab-download-manager.jar" "app.jar" "main.jar"; do
      if [ -f "$out/lib/$jar_name" ]; then
        MAIN_JAR="$out/lib/$jar_name"
        echo "Found main JAR: $jar_name"
        break
      fi
    done
    
    # Fallback: find any executable JAR
    if [ -z "$MAIN_JAR" ]; then
      MAIN_JAR=$(find $out/lib -name "*.jar" -type f | head -n1)
      if [ -n "$MAIN_JAR" ]; then
        echo "Using first available JAR: $(basename $MAIN_JAR)"
      fi
    fi
    
    if [ -z "$MAIN_JAR" ]; then
      echo "ERROR: No JAR files found!"
      echo "Contents of $out/lib:"
      ls -la $out/lib/ 2>/dev/null || echo "lib directory is empty"
      echo "Searching entire build directory:"
      find build -name "*.jar" -type f 2>/dev/null || echo "No JAR files in build directory"
      exit 1
    fi
    
    # Create the wrapper script
    makeWrapper ${jdk21}/bin/java $out/bin/ab-download-manager \
      --add-flags "-jar $MAIN_JAR" \
      --set JAVA_HOME "${jdk21}" \
      --prefix PATH : "${lib.makeBinPath [ jdk21 ]}"
    
    # Install application icon
    for icon_path in "shared/resources/icon/app_icon.png" "resources/icon/app_icon.png" "icon/app_icon.png" "app_icon.png"; do
      if [ -f "$icon_path" ]; then
        mkdir -p $out/share/pixmaps
        cp "$icon_path" $out/share/pixmaps/ab-download-manager.png
        echo "Installed icon from $icon_path"
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
