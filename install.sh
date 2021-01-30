#!/bin/sh

# Maintainer: Sibren Vasse <arch@sibrenvasse.nl>
# Contributor: Ilya Gulya <ilyagulya@gmail.com>
pkgname="deezer"
pkgver=4.32.0 
srcdir="$PWD"

install_dependencies() {
    # Manually install Node.js 12 since the version provided in some Ubuntu distros
    # is older than 10.13.0 which prettier requires.
    curl -sL https://rpm.nodesource.com/setup_12.x | sudo -E bash -
    sudo dnf check-update
    sudo dnf install p7zip p7zip-plugins ImageMagick nodejs wget g++ make patch
    sudo npm install -g electron@^6 --unsafe-perm=true
    sudo npm install -g --engine-strict asar
    sudo npm install -g prettier
}

prepare() {
    # Download installer
    wget "https://www.deezer.com/desktop/download/artifact/win32/x86/$pkgver" -O "$pkgname-$pkgver-setup.exe"
    # Extract app from installer
    7z x -so $pkgname-$pkgver-setup.exe "\$PLUGINSDIR/app-32.7z" > app-32.7z
    # Extract app archive
    7z x -y -bsp0 -bso0 app-32.7z

    # Extract png from ico container
    convert resources/win/app.ico resources/win/deezer.png

    cd resources/
    rm -rf app "$srcdir/npm_temp" || true
    asar extract app.asar app

    mkdir -p app/resources/linux/
    cp win/systray.png app/resources/linux/systray.png

    # Remove NodeRT from package (-205.72 MiB)
    rm -r app/node_modules/@nodert

    # Install extra node modules for mpris-service
    mkdir "$srcdir/npm_temp"; cd "$srcdir/npm_temp"
    npm install  --prefix ./ mpris-service

    for d in node_modules/*; do
        if [ ! -d "$srcdir/resources/app/node_modules/$(basename $d)" ]
        then
            mv "$d" "$srcdir/resources/app/node_modules/"
        fi
    done

    cd "$srcdir/resources/app"

    prettier --write "build/*.js"
    prettier --write "build/assets/cache/js/route-naboo*ads*.js"
    # Disable menu bar
    patch -p1 < "$srcdir/menu-bar.patch"
    # Hide to tray (https://github.com/SibrenVasse/deezer/issues/4)
    patch -p1 < "$srcdir/quit.patch"

    # Monkeypatch MPRIS D-Bus interface
    patch -p1 < "$srcdir/0001-MPRIS-interface.patch"

    cd ..
    asar pack app app.asar
}

package() {
    cd "$srcdir"
    sudo mkdir -p "$pkgdir"/usr/share/deezer
    sudo mkdir -p "$pkgdir"/usr/share/applications
    sudo mkdir -p "$pkgdir"/usr/bin/
    for size in 16 32 48 64 128 256 512; do
        sudo mkdir -p "$pkgdir"/usr/share/icons/hicolor/${size}x${size}/apps/
    done

    sudo install -Dm644 resources/app.asar "$pkgdir"/usr/share/deezer/
    sudo install -Dm644 resources/win/deezer-0.png "$pkgdir"/usr/share/icons/hicolor/16x16/apps/deezer.png
    sudo install -Dm644 resources/win/deezer-1.png "$pkgdir"/usr/share/icons/hicolor/32x32/apps/deezer.png
    sudo install -Dm644 resources/win/deezer-2.png "$pkgdir"/usr/share/icons/hicolor/48x48/apps/deezer.png
    sudo install -Dm644 resources/win/deezer-3.png "$pkgdir"/usr/share/icons/hicolor/64x64/apps/deezer.png
    sudo install -Dm644 resources/win/deezer-4.png "$pkgdir"/usr/share/icons/hicolor/128x128/apps/deezer.png
    sudo install -Dm644 resources/win/deezer-5.png "$pkgdir"/usr/share/icons/hicolor/256x256/apps/deezer.png
    sudo install -Dm644 "$pkgname".desktop "$pkgdir"/usr/share/applications/
    sudo install -Dm755 deezer "$pkgdir"/usr/bin/

    # Make sure the deezer:// protocol handler is immediately registered as it's needed for login 
    sudo update-desktop-database --quiet
}

install_dependencies && prepare && package
echo "Successfully installed Deezer Desktop!"
