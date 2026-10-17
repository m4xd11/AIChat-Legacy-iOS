# AI Chat for Legacy iOS

A small, lightweight AI chat app for jailbroken old iOS devices, using Google's
Gemini API and its free tier. Built and tested on an **iPod touch 5th gen (iOS 9.3.5, armv7)**.

> Made with AI assistance (Claude). Tested only on an iPod touch 5. Bug reports welcome.

## Features
- Dark and light themes (saved between launches)
- Animated chat bubbles and typing indicator
- Chat history saved on the device
- Optional system prompt (e.g. "answer briefly")
- Tap a message to copy it
- Built to stay cool: no blur, shadows, gradients or timers; animations only run on demand

## What you need
- A jailbroken iOS 6+ device (tested on iOS 9.3.5)
- A free Gemini API key from https://aistudio.google.com/apikey
- [Theos](https://theos.dev) to build it, with an iOS SDK that supports armv7 (for example iOS 9.3)

## Build
```
export THEOS=~/theos
make clean
make package
```
This makes a `.deb` in `packages/`. Install it with Filza or `dpkg -i`, then run `uicache`.

To make an `.ipa` instead:
```
make stage
mkdir Payload
cp -r .theos/_/Applications/AIChat.app Payload/
zip -r AIChat.ipa Payload
```
(The staged app path can vary with your Theos version.)

## Use
1. Open the app. Settings opens by itself the first time.
2. Paste your Gemini API key.
3. Set the model name (default: `gemini-3.8-flash`). Google retires models over time, so change this if you get a "model no longer available" error.
4. Chat.

## Privacy and limits
- Your API key is stored unencrypted in the app's preferences on your device.
- Messages are sent to Google's servers. On the free tier, Google may use prompts to improve its models, so don't send private info.
- The free tier has rate limits.
- iOS 9 has old root certificates, so TLS errors are possible on some networks.

## Similar projects
- [ChatGPT for Legacy iOS](https://github.com/bag-xml/ChatGPT-for-Legacy-iOS): an OpenAI client for iOS 6+.

## License
MIT. See `LICENSE`.
