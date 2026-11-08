# iphone-radio-player

iPhone listener app for 0hex01 RADIO — counterpart to the Android
`0hex01-apk` listener:

- Play/Stop the public stream `https://radio.primarymail.org/0hex01.mp3`
- Volume slider + mute toggle
- Live status (Stopped / Connecting / Buffering / Playing / Reconnecting)
- Self-heal: reconnects on stream end, failure, or stalled buffer
- Cache-busting stream URL like the website player

## Build (requires a Mac with Xcode)

1. Xcode → **New Project → iOS → App** named `RadioPlayer` (SwiftUI).
2. Replace the generated sources with `RadioPlayer/` from this repo.
3. In the target's **Info** or `Info.plist` add background audio so
   playback continues with the screen locked:
   `UIBackgroundModes` → `audio`
4. Build & run — no token needed; the stream is public.
