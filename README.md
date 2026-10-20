# PocketSearch

PocketSearch is an Android Flutter app for searching the text inside documents you select. It currently accepts PDF, TXT, Markdown, DOC, DOCX, PPT, and PPTX files, including files inside a selected folder. Audio, video, and OCR are planned but not implemented.

For implementation details and current verification status, see the [developer guide](docs/developer.md).
The latest emulator results are in the [acceptance check](docs/acceptance-check.md).

## Run on Android

The Android build requires API 26 (Android 8.0) or newer because Apache POI's
legacy DOC/PPT extractor uses `MethodHandle.invoke`.

1. Run `flutter pub get` and `flutter run` from this directory with an Android phone or emulator connected.
2. In Setup, choose **Download search model** once while online. The app stores the EmbeddingGemma task file in its private storage. The model source is the [MediaPipe Text Embedder model](https://developers.google.com/edge/mediapipe/solutions/text/text_embedder/index).
3. Choose files or a folder. Wait for the file status to become **searchable**, then use Quick Search. Later indexing and searches work offline for locally available files.

The Android document picker controls access. Some folder roots cannot be selected. PocketSearch retains granted URI access where the provider permits it. Imported content and embeddings stay in the app's SQLite database; originals remain in place.

## Current limits

- Scanned PDFs require OCR, which is not implemented. Encrypted, corrupt, or inaccessible files show an error in file details.
- TXT and Markdown must be UTF-8 and are limited to 16 MB each. Large Office files can use substantial memory during extraction. Legacy DOC and PPT extraction uses Apache POI and still needs Android device validation.
- Passage sizing is bounded by characters. Exact EmbeddingGemma token counts are not yet exposed by this integration; the model task has a 512-token input limit.
- Indexing resumes when the app is reopened. It does not continue after Android terminates the app.
- Search uses SQLite full-text matching and an exact cosine scan over SQLite-stored vectors. Performance with very large collections has not been benchmarked.
