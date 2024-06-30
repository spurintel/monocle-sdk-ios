# Monocle iOS SDK

This repository provides a Swift software development kit implementing [Monocle](https://spur.us/monocle/) in iOS.  

[SDK interface docs](https://spurintel.github.io/monocle-sdk-ios/)

## Prerequisites
* Xcode - Tested up to Xcode v15.4
* iOS - Emulated in Xcode or physical device tested up to iOS v17.5.
* Spur account - https://app.spur.us/start/create-account
* Monocle Site Token - https://app.spur.us/monocle

## Implementation
1. In the target Xcode iOS Swift project, add a package dependency for [this repository](https://github.com/spurintel/monocle-sdk-ios), with a dependency rule of the `main` branch.
2. import the `Monocle` package in a Swift source file 
3. Get a Monocle **site-token** from the [Monocle management interface](https://app.spur.us/monocle)
4. Create a config object by passing the token to `MonocleConfig()`
5. Instantiate Monocle by passing the config object to `Monocle.setup()`
6. Call `Monocle.shared.assess()` to load and run the assessment.
7. Pass the resulting assessment to your [backend integration](https://docs.spur.us/monocle?id=backend-integration).

## Quick start example
```swift
import SwiftUI
import Monocle

struct ContentView: View {
    @State private var message = "Encrypted Monocle result:\n\n"

    init() {
        let token = "CHANGEME"
        let config = MonocleConfig(token: token)
        Monocle.setup(config)
    }
    var body: some View {
        Text(message).padding().onAppear {
            Task {
                await fetchMessage()
            }
        }
    }

    func fetchMessage() async {
        let result = await Monocle.shared.assess()
        message = message + (result.data ?? "No data available")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
```

## Example app
This example includes collecting host telemetry and geolocation in addition to the Monocle assessment, and provides better UI elements and error handling.
* [Monocle iOS Example App](https://github.com/spurintel/monocle-example-ios)

## Docs
* [Monocle Docs](https://docs.spur.us/monocle)

## Swift Docs

API Docs can be generated from XCode under Product > Build Documentation.  This will produce `Monocle.doccarchive` which will load in XCode and populate context documentation in the editor.

Converting this archive to regular HTML can be achieved with the command line:
```sh
$(xcrun --find docc) process-archive transform-for-static-hosting Monocle.doccarchive --output-path docs --hosting-base-path /monocle-sdk-ios
```

HTML docs have been pre-built and included in this repo.

## FAQ

### Can't I just use the native Swift network state APIs to determine if the device is on a VPN?

   You can and possibly should use native APIs as well, but there are several situations where this information is inaccurate.  These APIs also generally require additional system permissions the user has to approve, and are increasingly restrictive in recent iOS versions.  The native APIs also will not tell you which proxy/VPN service is in use or provide additional enrichment to make more subtle access decisions.  

### Does Monocle support Android?
   Yes. See [Monocle SDK for Android](https://github.com/spurintel/monocle-sdk-android)

### What about Flutter or ReactNative or other frameworks?
   Monocle is lightweight and should work on any platform that can execute Javascript in the client and make standard HTTPS GETs/POSTs, but it is untested at this time.  Please let us know if you try it.

