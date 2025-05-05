# Session Properties

@Metadata {
   @TitleHeading(Framework)
   @PageImage(purpose: icon, source: C3D-logo.svg, alt: "Cognitive3D Analytics icon")
}

## Overview

You can insert custom properties that are inserted into sessions at run-time.

### Session Properties

You add data to a session using `SessionProperties`.  For example, if you are testing a QA build and want to be able categorize the data in the C3D dashboard.


```swift
Cognitive3DAnalyticsCore.shared.setSessionProperty(key: "testSession", value: True)
```


Properties can be added at any time during a session; the data gets include with the gaze data stream.  At this time, the supported value types are: String, Boolean, Numeric.


```swift
Cognitive3DAnalyticsCore.shared.setSessionProperty(key: "myKey1", value: "Jibber Jabber")
```

```swift
Cognitive3DAnalyticsCore.shared.setSessionProperty(key: "myKey2", value: True)
```

```swift
Cognitive3DAnalyticsCore.shared.setSessionProperty(key: "myKey3", value: 42)
```


> Note: the data is cleared at the end of a session.


## Participants

The core data to submit is:

  *`name` : the full name of the participant
  *`participantId` : an unique id for the participant

```swift
let idValue = "11112222"
Cognitive3DAnalyticsCore.shared.setParticipantId(idValue)
```

```swift
let fullName = "Jack Jones"
Cognitive3DAnalyticsCore.shared.setParticipantFullName(fullName)
```
 
The participant API is using `setSessionProperty` internally.


You add custom data as well that gets associated with a participant.

```swift
Cognitive3DAnalyticsCore.shared.setParticipantProperty(keySuffix: "someAttribute", value: "someValue")
```

The data gets posted with the key starting with `c3d.participant.`; the key suffix is appended to it.


