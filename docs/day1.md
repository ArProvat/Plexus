# Day 1 implementation status

> Archived experiment: this page describes the earlier MobileBERT sample app.
> The current app imports selected files and folders and uses EmbeddingGemma.
> Follow the [README](../README.md) for current setup and testing instructions.

Source files are prepared at the repository root. This is not yet a generated or
validated Flutter Android project. Flutter and adb were unavailable during setup.
No Stitch reference or local model artifact was supplied. The Material layout is
temporary, and device results below remain unmeasured.

## Generate the platform build

With Flutter installed and on PATH, run from `C:\provat\Plexus`:

```powershell
flutter doctor
flutter create --platforms=android --org com.arprovat --project-name pocketsearch .
```

Keep the existing Dart and Kotlin source when generating missing platform files;
do not use `--overwrite`. Review the generated diff. Namespace and application ID
must be `com.arprovat.pocketsearch`. Remove the generated counter test if it tests
the default example instead of PocketSearch. First verify a separate default
Flutter app runs on your phone before attempting this native integration.

In the generated `android/app/build.gradle.kts`, add a pinned compatible version
of `com.google.mediapipe:tasks-text` to `dependencies`, and use the minimum SDK
required by that release (at least API 24). Resolve and record the actual runtime
version before building; no release was downloaded or validated in this session.

In the generated manifest, retain Flutter's application/activity configuration.
Ensure MainActivity uses `singleTop`, and add this inside `application`:

```xml
<receiver android:name=".SearchWidget" android:exported="false">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data android:name="android.appwidget.provider"
        android:resource="@xml/search_widget_info" />
</receiver>
```

## Local model

The initial compatibility spike uses Mobile BERT from the
[MediaPipe sample model configuration](https://github.com/google-ai-edge/mediapipe-samples/blob/main/examples/text_embedder/android/app/download_models.gradle).
This is a Day 1 candidate, not a benchmarked replacement for the planned
EmbeddingGemma evaluation.

Download the artifact into
`android/app/src/main/assets/mobile_bert.tflite` before building:

```text
https://storage.googleapis.com/mediapipe-models/text_embedder/bert_embedder/float32/1/bert_embedder.tflite
```

Record the artifact SHA-256 and runtime version. The native engine uses
MediaPipe tokenization, CPU inference, and explicit L2 normalization. All model
operations use one native worker. The loaded model is reused until activity
destruction. No server fallback exists. See the
[Android Text Embedder guide](https://developers.google.com/edge/mediapipe/solutions/text/text_embedder/android).

## Verification

```powershell
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run
```

Verify the launcher opens Setup, Search focuses the input, and the keyboard
appears. Check empty input, model loading, missing model errors, and retry.
Add the widget through the launcher. Test it after force-stopping the app and
while Setup or Quick Search is already open.

Use the suggested question to rank all three sample passages. These are cosine
rankings with no calibrated relevance threshold. Run once to load and warm the
model, then measure repeated queries. The screen shows model load time and query
time including the platform bridge; use Android Studio's memory profiler to
capture peak process memory. Turn on airplane mode, restart, and repeat search.

| Measurement | Result |
| --- | --- |
| Phone model and RAM | Pending physical device |
| Model | BERT embedder float32, artifact revision 1 (planned) |
| Runtime version | Pending dependency resolution |
| Artifact SHA-256 | Pending download |
| Model loading time | Not measured |
| Warm query time | Not measured |
| Peak process memory | Not measured |
| Agent memory passage ranked first | Not verified |
| Airplane mode | Not verified |

## Completion checklist

- [ ] Flutter app runs on the phone.
- [ ] Setup and Quick Search match the supplied Stitch design.
- [ ] Widget opens Quick Search on cold and warm launches.
- [ ] Local embeddings produce valid vectors on the phone.
- [ ] Sample search works in airplane mode.
- [ ] Model configuration and measurements are recorded.
