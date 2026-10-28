# CLAUDE.md

Standing instructions for Claude Code in this repository. Read this first, then `PROJECT_SPEC.md`.

## What this project is

**Local ImageGen UI**: a local, offline-first Windows desktop app with a visual node-style UI for using AI models installed on the user's own PC. Inputs: 0-10 images (each in its own node) + one prompt node -> model node -> result node. General purpose (editing, combining images, background replacement, style transfer, text-to-image, ...), not clothing-specific.

Current state: a working prototype (FastAPI backend + vanilla JS frontend) that drives a local **ComfyUI** over `127.0.0.1`. It has been tested **only in mock mode**. Real ComfyUI calls and workflow injection are unverified. See `PROJECT_SPEC.md` for the goal and milestones.

## Repository layout

```
backend/app.py            FastAPI server, job queue, API (/api/generate, /api/jobs, /api/gallery, /api/status)
backend/comfy_engine.py   ComfyUI client: picks a workflow from workflows/*.json, injects prompt/images/seed/steps/size
backend/engine.py         BaseEngine, MockEngine (no GPU), optional diffusers engine, make_engine()
frontend/index.html       UI shell + CSS
frontend/app.js           UI logic, node link drawing, DEMO mode (window.DEMO_MODE)
workflows/                ComfyUI API-format workflows (user-provided, not committed except examples)
outputs/                  generated images (gitignored)
config.json               settings
install.bat / run.bat / run_mock.bat   Windows helpers for the prototype
```

## Environment you are running in (important)

Cloud sessions run on **Linux with no GPU and no Windows**. Therefore:
- Always develop and test against the **mock engine**: `TRYON_MOCK=1 TRYON_NO_BROWSER=1 python backend/app.py` (serves on http://127.0.0.1:7860).
- Test model discovery with **fixture directories** you create in tests (fake `.gguf`/`.safetensors` headers, fake Ollama/LM Studio/ComfyUI folder trees). Never assume real models exist.
- The Windows `.exe`/installer is built by **GitHub Actions on `windows-latest`**, not locally. Iterate by reading Actions logs.
- You cannot verify real GPU generation. Say so clearly in PR descriptions and list what the user must test on their PC (`docs/WINDOWS_TEST_CHECKLIST.md`).

## Commands

- Install deps: `pip install -r requirements.txt` (add `pytest` for tests)
- Run (mock): `TRYON_MOCK=1 TRYON_NO_BROWSER=1 python backend/app.py`
- Tests: `pytest -q` (create `tests/` as part of the work; keep it fast and GPU-free)
- JS syntax check: `node --check frontend/app.js`
- Do not kill the server with `pkill -f backend/app.py` from inside the same shell command line (it matches itself); kill by PID.

## Conventions

- Python 3.10+ compatible, type hints where cheap, no heavy dependencies without a reason.
- Backend must work fully **offline**: the only network calls allowed are to `127.0.0.1` (ComfyUI, Ollama). No telemetry, no cloud APIs.
- UI language: Uzbek (Latin). Keep all UI strings easy to find (single dictionary) so English can be added later. Prompts sent to models stay in English.
- Mock mode and DEMO mode must keep working after every change.
- Frontend is plain HTML/CSS/JS (no build step) unless the spec says otherwise.
- Never commit models, outputs, `.venv`, build artifacts, or user paths. Never hardcode `C:\Users\...`.
- Windows paths: use `pathlib`, handle spaces and non-ASCII characters in paths.
- Keep changes small and reviewable: one milestone (or sub-task) per branch/PR.

## Licensing note

The default model family (Qwen-Image-2.1) is under the Qwen Research License (non-commercial). Do not add text implying commercial use is allowed.

## Definition of done for any task

1. Mock mode runs; `pytest -q` passes; `node --check frontend/app.js` passes.
2. UI change -> verify with a headless-browser screenshot (Playwright) in DEMO or mock mode.
3. README/docs updated if behavior changed.
4. PR description lists: what changed, what was tested, what still needs testing on real Windows hardware.
