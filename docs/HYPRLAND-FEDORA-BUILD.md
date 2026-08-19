# Building Hyprland from source on Fedora

Fedora does not ship Hyprland in its official repositories. The [Hyprland wiki](https://wiki.hypr.land/Getting-Started/Installation/#fedora)
points Fedora users at the third-party `lionheartp/Hyprland` COPR, or a stale 2022 HOWTO that predates
the current CMake build system. This guide documents a reproducible local source build, tested on
**Fedora 44** with **gcc 16.1.1** and **cmake 4.3.0**.

The official repos also ship the Hypr ecosystem *libraries* (`hyprlang`, `hyprutils`, `hyprgraphics`,
`hyprcursor`, `hyprwayland-scanner`), but in versions too old for current Hyprland. We therefore build
the whole stack from source, in dependency order.

> [!WARNING]
> The wiki explicitly warns against manual compilation: Hyprland's dependency ecosystem is vast and
> intertwined, and stale/mismatched `.so` files are your own problem. This guide works, but keep the
> whole stack updated together — never mix git builds with distro-packaged libraries.

## Requirements

- Fedora 44+ (Hyprland requires C++26: `gcc >= 16` or `clang >= 19`)
- `cmake`, `ninja`, `pkg-config`, `git`

## 1. Install build dependencies

```bash
sudo dnf install \
  gcc-c++ cmake ninja-build pkgconf git cpio \
  wayland-devel wayland-protocols-devel \
  libxkbcommon-devel libXcursor-devel libxcb-devel \
  xcb-util-devel xcb-util-errors-devel xcb-util-wm-devel xcb-util-renderutil-devel \
  mesa-libEGL-devel mesa-libGL-devel mesa-libgbm-devel glslang-devel \
  libdrm-devel pixman-devel \
  cairo-devel pango-devel lcms2-devel re2-devel muParser-devel \
  libjpeg-turbo-devel libwebp-devel file-devel libpng-devel librsvg2-devel \
  libinput-devel libseat-devel libdisplay-info-devel hwdata \
  libuuid-devel systemd-devel glib2-devel libffi-devel udis86-devel \
  lua-devel hyprcursor-devel \
  xorg-x11-server-Xwayland
```

Notes:

- **Lua**: Hyprland's `CMakeLists.txt` searches for `lua>=5.5 lua<5.6`. Fedora ships Lua **5.4**
  (`lua-devel`), which still resolves correctly through the `<5.6` term — no custom Lua 5.5 build is
  needed.
- **XWayland**: compiled in by default against the `xcb*` deps; the `xorg-x11-server-Xwayland`
  binary is required at runtime.
- Optional/extra formats: `libheif-devel` and `libjxl-devel` enable extra image decoders in
  `hyprgraphics`; `vulkan-loader-devel` enables the Vulkan renderer.

## 2. Build the dependency stack

All Hypr projects use CMake. Clone, configure, build, and install each in order. The stack is
installed to `/usr` to match the system prefix:

```bash
cmake -B build -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)
sudo cmake --install build
```

### 2.1 hyprwayland-scanner

Required by everything else to generate wayland protocol headers.

```bash
git clone https://github.com/hyprwm/hyprwayland-scanner
cd hyprwayland-scanner
cmake -B build -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)
sudo cmake --install build
```

### 2.2 hyprutils

```bash
git clone https://github.com/hyprwm/hyprutils
cd hyprutils
cmake -B build -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)
sudo cmake --install build
```

### 2.3 hyprlang

Depends on `hyprutils >= 0.7.1`.

```bash
git clone https://github.com/hyprwm/hyprlang
cd hyprlang
cmake -B build -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)
sudo cmake --install build
```

### 2.4 hyprgraphics

Depends on `hyprutils`, `libdrm`, `pixman`, `cairo`, `pangocairo`, `libjpeg`, `libwebp`, `libmagic`,
`libpng`, `librsvg`.

```bash
git clone https://github.com/hyprwm/hyprgraphics
cd hyprgraphics
cmake -B build -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)
sudo cmake --install build
```

### 2.5 hyprwire

Depends on `hyprutils >= 0.9.0` and `libffi`.

```bash
git clone https://github.com/hyprwm/hyprwire
cd hyprwire
cmake -B build -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)
sudo cmake --install build
```

### 2.6 aquamarine

The rendering/backend library. Depends on `hyprwayland-scanner >= 0.4.0`, `hyprutils >= 0.8.0`,
`libseat`, `libinput`, `wayland-client`, `wayland-protocols`, `pixman`, `libdrm`, `gbm`, `libudev`,
`libdisplay-info`, `hwdata`.

```bash
git clone https://github.com/hyprwm/aquamarine
cd aquamarine
cmake -B build -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)
sudo cmake --install build
```

### 2.7 hyprcursor

The Fedora package (`hyprcursor-devel`, 0.1.13) satisfies Hyprland's requirement (`>= 0.1.7`), so the
distro version is fine. If you prefer a matching git build:

```bash
git clone https://github.com/hyprwm/hyprcursor
cd hyprcursor
cmake -B build -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)
sudo cmake --install build
```

## 3. Build Hyprland

`--recursive` is required — it pulls the pinned submodules (`hyprland-protocols`, `tracy`, `udis86`).

```bash
git clone --recursive https://github.com/hyprwm/Hyprland
cd Hyprland
make release     # cmake Release build into ./build, PREFIX=/usr
sudo make install
sudo make installheaders   # headers for hyprpm plugin builds
```

Run `sudo ldconfig` afterwards.

## 4. Verify

```bash
hyprctl version
```

Expect output like:

```
Hyprland 0.55.0 built from branch main at commit <hash> clean
Tag: v0.55.0-<n>-g<hash>, commits: <n>
```

Check that every library reports the version it was *built against*:

```
Hyprgraphics: built against X, system has X
Hyprutils:    built against X, system has X
Hyprcursor:   built against X, system has X
Hyprlang:     built against X, system has X
Aquamarine:   built against X, system has X
```

If any line shows a mismatch, rebuild that library and Hyprland (see next section). Also verify the
wayland session file is discoverable: `/usr/share/wayland-sessions/hyprland-uwsm.desktop`.

## 5. Updating

Pull and rebuild in the same order. Doing this in one `git pull && rebuild && reinstall` pass keeps
the ABI in sync across the stack.

```bash
for repo in hyprwayland-scanner hyprutils hyprlang hyprgraphics hyprwire aquamarine; do
  cd "$HOME/$repo"
  git pull
  cmake --build build -j$(nproc)
  sudo cmake --install build
done

cd "$HOME/Hyprland"
git pull --recurse-submodules
make release
sudo make install
sudo ldconfig
```

## 6. Uninstall

```bash
cd Hyprland
sudo make uninstall        # removes files listed in build/install_manifest.txt
# remove /usr/share/wayland-sessions/hyprland-uwsm.desktop if left behind
```

For each dependency, `sudo cmake --uninstall build` (build dirs must still exist).

## 7. Troubleshooting

- **`.so` mismatch / missing shared library errors**: a dependency library was updated without
  rebuilding Hyprland, or a distro update replaced a library. Rebuild the whole stack.
- **`wayland-server` not found at configure time**: `wayland-devel` is missing or was autoremoved.
  Reinstall it (Fedora 44 ships wayland 1.25 >= the required 1.22.91).
- **`xcb-errors` not found**: install `xcb-util-errors-devel` (available since Fedora 38).
- **Configure fails on `udis86`/`glslang`**: install `udis86-devel` / `glslang-devel`.
- **Lua configure errors**: ensure `lua-devel` is installed; Lua 5.4 is sufficient despite the
  `>= 5.5` constraint in `CMakeLists.txt`.
- **Hyprland crashes on first launch**: the wiki documents this on some systems — relaunch once from
  the login screen.