# PROJECT_SPEC.md: Local ImageGen UI

This document states what the owner wants. When something here is ambiguous, ask in the PR description or session instead of guessing.

## 1. Vision

A Windows desktop application that makes **locally installed, offline AI models easy to use** through a simple visual interface.

- The user installs it with a normal Windows installer (`LocalImageGen-Setup.exe`), no Python or command line needed.
- On first run it **searches the PC for installed offline models** and shows them in a list (name, type, size, location). The user picks which model to use.
- Works with **several** local models, not one hard-coded model.
- Everything works **offline**. No accounts, no cloud, no telemetry.

## 2. Target user and hardware

- One owner/user, Uzbek-speaking, Windows 11.
- Reference PC: Acer Predator Helios Neo 16, i9-14900HX, **RTX 4060 Laptop 8 GB VRAM**, 32 GB RAM, 512 GB SSD.
- Consequence: low-VRAM is the normal case. Quantized models (GGUF/INT4/INT8), CPU offload, small default resolutions, clear warnings when a request is likely to run out of memory. Disk is limited, so never auto-download large models.

## 3. The interface (already prototyped in `frontend/`)

A node-style canvas, left to right, with link lines between nodes:

1. **Image nodes**: each input image lives in its own separate node. 0 to **10** images max. Drag and drop (also several files at once), click to pick, paste with Ctrl+V. Optional free-text label per node (for the user only, never sent to the model). Empty = text-to-image.
2. **Prompt node**: one separate node. Images are referenced as `image 1`, `image 2`... (chips insert these). Ready-made prompt templates and prompt history.
3. **Model node**: all images and the prompt connect into it. Size (auto from image 1), steps, seed, 1/2/4 variants, Generate/Cancel, progress.
4. **Result node**: separate node. Per result: zoom, download, "use as input" (feed result back as a new image node), reuse seed. Gallery tab keeps history on disk.

General purpose: **any** image task (edit, combine, style transfer, background change, remove/add object, text-to-image). Nothing clothing-specific in the UI or defaults.

New for this phase: a **model picker** in the Model node and a **Models** screen (see 4).

## 4. Model discovery and selection (main new feature)

### 4.1 Scanner

Find offline models already on the PC, without loading them into memory. Search locations:

- ComfyUI install folders (`models/checkpoints`, `unet`, `diffusion_models`, `text_encoders`, `clip`, `vae`, `loras`). Locate ComfyUI via config, common paths, and a bounded search of fixed drives for a folder containing `ComfyUI/main.py`.
- Ollama: `%USERPROFILE%\.ollama\models` and, if running, `http://127.0.0.1:11434/api/tags`.
- LM Studio: `%USERPROFILE%\.lmstudio\models` and `%USERPROFILE%\.cache\lm-studio\models`.
- Hugging Face cache: `%USERPROFILE%\.cache\huggingface\hub` (and `HF_HOME` if set).
- Automatic1111/Forge: `models\Stable-diffusion`, `models\Lora`, `models\VAE`.
- User-added folders (persisted in settings), scanned recursively.

Recognize: `.gguf`, `.safetensors`, `.ckpt`, `.pt`/`.pth`, `.onnx`, diffusers-style folders (`model_index.json`).

Classify **by reading headers only**:
- GGUF: parse metadata (`general.architecture`, `general.name`, quantization/file type).
- safetensors: read the JSON header (tensor names/shapes) to guess family (SD1.5, SDXL, Flux, Qwen-Image, ...) and role (checkpoint, diffusion model, VAE, text encoder, LoRA).
- Unknown files are listed as "unknown", never hidden silently.

Requirements:
- Fast, cancellable, runs in the background with progress; results cached and refreshable ("Rescan").
- Skips system folders and handles permission errors, long paths, spaces and non-ASCII paths.
- Pure-Python, unit-tested with fixture folders on Linux (no real models required).

### 4.2 API

- `GET /api/models` -> list of `{id, name, kind, family, format, size_bytes, path, source, runnable, reason_if_not}`
- `POST /api/models/scan` (start), `GET /api/models/scan/status`
- `POST /api/models/folders` (add/remove custom folders)
- `POST /api/models/select` (choose active model per role)

### 4.3 UI

- Model node gets a dropdown of discovered runnable models plus a "Models" button opening a full list: filter by kind/family, search, sizes, source, "show in folder", Rescan, Add folder.
- Non-runnable models are shown greyed with the reason (for example "no workflow template for this family yet").

### 4.4 Running the selected model

Discovery is not enough, each model family needs a recipe:
- Introduce a **workflow template registry** (`workflows/templates/<family>/manifest.json` + API-format workflow JSON). The manifest declares family, required files/roles, number of image slots, and which nodes take prompt/images/seed/steps/size.
- The engine fills the selected model's file names into the template (loader nodes), then runs it through ComfyUI as today.
- Start with: **Qwen-Image-2.1 (GGUF, edit + text-to-image)**, then **SDXL** and **FLUX** (text-to-image) if templates can be made reliably. Do not pretend to support a family without a template.
- Design the engine interface so another backend (for example Ollama or llama.cpp for LLM/vision models) can be added later **without UI changes**.

## 5. Packaging as a Windows app

- **Window**: native window via pywebview (WebView2) hosting the local UI; fall back to the default browser if WebView2 is missing.
- **Backend**: packaged with PyInstaller (onedir preferred for startup speed and fewer antivirus false positives) into `LocalImageGen`.
- **Installer**: Inno Setup producing `LocalImageGen-Setup.exe` (Start Menu shortcut, optional desktop shortcut, uninstaller, per-user install, no admin rights).
- **User data** (config, outputs, scan cache, logs) in `%APPDATA%\LocalImageGen` / `%USERPROFILE%\Pictures\LocalImageGen`, **not** next to the exe.
- **Does not bundle** models or ComfyUI (too large). The app finds them, and if ComfyUI is missing shows a clear first-run guide (what to install, where to put files).
- **CI**: GitHub Actions workflow on `windows-latest` builds the installer on every tag `v*` and on manual dispatch, uploads it as an artifact / GitHub Release asset. A smoke test runs the built exe headless (`--selftest`) and checks `/api/status`.
- Code signing is out of scope for now (note antivirus false-positive risk in README).

## 6. Non-goals (for now)

- No online/cloud generation, no accounts, no analytics, no auto-updating from the internet.
- No model downloading inside the app.
- No Mac/Linux builds (code should not be gratuitously Windows-only, but only Windows is tested/shipped).
- No chat/LLM UI in this phase (architecture must leave room for it).

## 7. Milestones (one PR each)

**M0: Repo hygiene.** Add `tests/` with pytest (job queue, mock engine, `/api/generate` validation, workflow injection/picking), `.github/workflows/ci.yml` (pytest + `node --check` on ubuntu), rename env var `TRYON_MOCK` to `IMAGEGEN_MOCK` (keep the old name as an alias), move config to a user-data location with a documented override. *Done when:* CI green, mock mode unchanged.

**M1: Model scanner + API.** Section 4.1-4.2 with fixture-based tests for every source (ComfyUI tree, Ollama manifest/API mock, LM Studio tree, HF cache layout, A1111 tree, custom folder), GGUF and safetensors header parsers. *Done when:* tests cover each source and each file format, and a scan of a 10k-file fixture tree stays responsive.

**M2: Models UI.** Section 4.3. Works in mock/DEMO mode with a fake model list. Screenshot in PR. *Done when:* picking a model changes the active model in the Model node and survives restart.

**M3: Template registry + engine routing.** Section 4.4 with the Qwen-Image-2.1 GGUF template first. Backend validates that required files exist before queuing. Clear errors for missing roles (e.g. "text encoder not found"). *Done when:* unit tests with a fake ComfyUI HTTP server prove workflow filling, polling, cancel, and error paths.

**M4: Windows packaging + CI release.** Section 5. *Done when:* the Actions run produces `LocalImageGen-Setup.exe` and the headless `--selftest` passes on the runner.

**M5: First-run experience and polish.** First-run guide, ComfyUI auto-start/stop handling, log viewer/"copy diagnostics" button, English UI option.

## 8. What the owner will test on real hardware

After M3 and M4 the owner will run the installer on the reference PC with a real ComfyUI + GGUF model and report back. Keep `docs/WINDOWS_TEST_CHECKLIST.md` up to date with exact steps and expected results, and make failures diagnosable (a "Copy diagnostics" output with versions, scan result, selected model, last ComfyUI error).

## 9. Known unverified areas in the prototype

- Real ComfyUI behavior: `/upload/image`, `/prompt`, `/history`, `/view`, websocket progress, `/interrupt`, `/free`.
- Automatic detection of prompt/seed/size/image nodes in exported API workflows (naming conventions `PROMPT`, `IMG1..IMG10`, `SIZE` exist as manual overrides).
- Qwen-Image-2.1 on 8 GB VRAM with image inputs (users report out-of-memory risk; resolution/step/offload tuning needed).
- The optional diffusers backend (`"backend": "diffusers"`) has never been run.

## 10. Open questions (ask the owner, do not decide silently)

1. Should LLM/vision chat models (Ollama, LM Studio) get their own UI in a later phase, or stay image-only?
2. Native window (pywebview) vs. always-browser: default plan is native window with browser fallback.
3. Which model families beyond Qwen-Image-2.1 matter most (SDXL, FLUX, others)?
