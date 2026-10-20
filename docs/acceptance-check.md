# Android acceptance check — 20 October 2026

Tested the installed PocketSearch `0.1.0` debug APK on the
`sdk_gphone64_x86_64` emulator (Android API 37). The APK declares a minimum
Android API of 26. This was an emulator check, not a physical-phone benchmark.

I generated two selectable-text English PDFs (one with two distinct pages), one
UTF-8 Bengali TXT document, one Markdown document, and one image-only PDF.
The sources were placed in `Documents/PocketSearchAcceptance` on the emulator.
I inspected the app's SQLite database using `run-as` after each operation.

| Check | Result | Evidence |
| --- | --- | --- |
| Text and source locations | Pass | Four text files became `searchable`. The two-page PDF had two passages with physical pages 1 and 2; the second PDF had page 1. Bengali and Markdown passage offsets recovered the original text. Each saved vector was 1,024 bytes (256 float32 values). |
| Scanned PDF explanation | Pass | The image-only PDF had zero passages and showed `No selectable text found; this file may need OCR`. |
| Unsupported format explanation | Needs rebuilt APK | Selecting a test RTF in the installed APK showed only `0 supported files found`. `setup_screen.dart` now states the supported extensions and reports skipped files, but that change has not been deployed to the emulator. |
| Restart persistence | Pass | Force-stopping and reopening the app retained five file records, five passages, and their statuses. |
| Repeat selection | Pass | Re-selecting the two-page PDF retained one file record and exactly two passages; its active revision advanced from 1 to 2. |
| Retry without duplicates | Pass | Retrying that PDF retained exactly two passages; its active revision advanced to 3. |
| Remove without deleting original | Pass | Removing the PDF deleted its file, job, and passages from SQLite. The 1,954-byte original still existed in the emulator's Documents folder. |
| Offline import | Pass | With `airplane_mode_on=1`, a fresh local TXT file became `searchable` with a 1,024-byte vector. Airplane mode was restored to `0` afterward. |
| Responsive during extraction | Pass on emulator | A 250-page image-only PDF was at 18% in `extracting` when Quick Search was tapped; the search screen opened. The PDF later failed with the expected OCR explanation. This checks interaction, not frame rate. |

The focused snapshot assertions also passed for the imported, restarted,
re-selected, retried, offline, removed, and completed 30-page stress states.
The local test fixtures and SQLite snapshots are in `.tools/acceptance/` and are
ignored by Git. Test sources remain in the emulator's Documents folder so they
can be inspected manually.

## Defects found and source fixes

1. **Folder selection:** the installed APK rejected a granted folder tree URI
   with `PICKER_ERROR: Unsupported Uri`. `DocumentAccess.kt` now derives the
   folder label from the tree document ID instead of querying the tree URI as
   an ordinary document. Folder import needs a rebuilt APK and a device retest.
2. **Unsupported file message:** the installed APK did not explain why a
   selected RTF was skipped. `setup_screen.dart` now lists supported formats
   and reports the number of unsupported files skipped. Device retest pending.
3. **Search result sorting:** an offline search in the installed APK reported
   `Unsupported operation: read-only`. `search_engine.dart` now copies SQLite's
   result list before sorting. Device retest pending; the search query itself
   was not marked as passed.

The corrected APK could not be built in this sandbox: Flutter could not write
its SDK cache lock, and Gradle could not write its user cache outside the
workspace. On a normal development terminal, run:

```powershell
flutter analyze
flutter test
flutter run
```

Then recheck folder selection, unsupported-file messaging, and Quick Search.
