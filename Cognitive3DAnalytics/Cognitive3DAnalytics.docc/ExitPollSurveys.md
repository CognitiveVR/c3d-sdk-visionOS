# Exit Poll Surveys

@Metadata {
   @TitleHeading(Framework)
   @PageImage(purpose: icon, source: C3D-logo.svg, alt: "Cognitive3D Analytics icon")
}

## Overview

Exit poll surveys allows you to directly ask questions to your users. This only requires a few lines and some options on your Cognitive3D dashboard. This page will walk you through the process of enabling and configuring an ExitPoll in your application.

The types of questions are:

* boolean: true / false
* happy / sad (boolean internally)
* thumbs up / thumbs down (boolean internally)
* multiple choice with 2 to 4 choices
* scale: with a numeric range like 1 to 10
* voice: the user records audio

```swift
public enum QuestionType: String, Codable {
    case boolean = "BOOLEAN"
    case happySad = "HAPPYSAD"
    case thumbs = "THUMBS"
    case multiple = "MULTIPLE"
    case scale = "SCALE"
    case voice = "VOICE"
}
```

For recording audio, an entitlement with a description needs to be added to the application info.plist.

```XML
<key>NSMicrophoneUsageDescription</key>
<string>We need access to the microphone for audio recording.</string>
```

 [Exit poll survey - view model](EPSViewModel.md)
 
 [Exit poll questions SwiftUI views](EPSSwiftUIViews.md)
