# AI Chat for Legacy iOS

A small, lightweight AI chat app for jailbroken old iOS devices, using Google's
Gemini API and its free tier. Built and tested on an **iPod touch 5th gen (iOS 9.3.5)**.

> Made with AI assistance (Claude). Tested only on an iPod touch 5. Bug reports welcome.

## Download
Get the latest `.ipa` or `.deb` from the
[Releases page](https://github.com/m4xd11/AIChat-Legacy-iOS/releases/latest).

## Features
- Dark and light themes (saved between launches)
- Animated chat bubbles and typing indicator
- Chat history saved on the device
- Optional system prompt (e.g. "answer briefly")
- Tap a message to copy it
- Built to stay cool: no blur, shadows, gradients or timers

## Install
You need a jailbroken device.

**.ipa:** install **AppSync Unified** from Cydia/Sileo first, then open the `.ipa`
in Filza and tap Install.

**.deb:** open it in Filza and tap Install (no AppSync needed), then respring or run `uicache`.

## First-time setup
1. Get a free API key at https://aistudio.google.com/apikey
2. Open the app (Settings opens by itself the first time) and paste your key.
3. Leave the model as `gemini-3.8-flash`. Google retires models over time, so change
   it if you see a "model no longer available" error.
4. Chat!

## Privacy and limits
- Your API key is stored unencrypted in the app's preferences on your device.
- Messages go to Google's servers. On the free tier, Google may use prompts to improve
  its models, so don't send private info.
- The free tier has rate limits.
- iOS 9 has old root certificates, so TLS errors are possible on some networks.

## Build from source (developers)
Needs [Theos](https://theos.dev) and an armv7-capable iOS SDK (e.g. iOS 9.3).
```
export THEOS=~/theos
make clean
make package
```
For an `.ipa`: run `make stage`, copy the staged `AIChat.app` into a `Payload` folder, and zip it.

## Similar projects
- [ChatGPT for Legacy iOS](https://github.com/bag-xml/ChatGPT-for-Legacy-iOS): an OpenAI client for iOS 6+.

## License
MIT. See `LICENSE`.
