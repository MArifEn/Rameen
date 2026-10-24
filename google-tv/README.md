# Google TV home screen cleanup

`gtv-cleanup.sh` connects to a Google TV device (Chromecast with Google TV, Google TV Streamer, Sony/TCL Google TV sets) over ADB. It turns off the apps that fill the home screen with promos and recommendations. Every change can be undone with `restore`.

## 1. Turn on debugging on the TV

1. **Settings → System → About**: select **Android TV OS build** 7 times until it says you are a developer.
2. **Settings → System → Developer options**: turn on **USB debugging** (on some models it's called **Network debugging** or **Wireless debugging**).
3. Find the TV's IP address under **Settings → Network & Internet → (your Wi-Fi)**.

## 2. Install ADB on your computer

- macOS: `brew install android-platform-tools`
- Windows: `winget install Google.PlatformTools` (run the script from Git Bash or WSL)
- Linux: `sudo apt install adb`

## 3. Run it

```bash
cd google-tv
./gtv-cleanup.sh connect 192.168.1.50   # use your TV's IP; accept the prompt on the TV
#   Using Wireless debugging instead? First run:
#   ./gtv-cleanup.sh pair 192.168.1.50:<pair-port> <code>
#   then connect with the port shown on that screen.
./gtv-cleanup.sh status                 # see what's installed
./gtv-cleanup.sh clean                  # shows the list, asks before changing anything
```

`clean` does three things:
- Disables the apps listed in `packages.txt`, for your user only. Nothing is uninstalled.
- Sets UI animations to half length so menus feel faster.
- Restarts the launcher so the changes show up.

To also hide partner apps you never use, such as Netflix or Prime Video, delete the `#` in front of them in `packages.txt` before running `clean`.

## 4. Settings you can only change on the TV

- **Apps only mode** (Settings → Accounts & sign-in → your account): removes the For You rows and the sponsored banner, leaving just your apps.
- **Your services** (same menu): stops chosen streaming services from feeding the home screen.

## Undo

```bash
./gtv-cleanup.sh restore
```

This turns back on every app the script disabled (they're recorded in `.disabled-packages`) and resets animation speed. A factory reset also restores everything.
