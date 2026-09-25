# GLM-5.3-Flash EXL3 — local config

Repo: ~/miaai_lab/GLM-5.3-Flash-EXL3-2x-DGX-Sparks
(origin = my fork lebidan/..., upstream = MiaAI-Lab/...)

## Update to latest upstream (run in the repo)

    git pull upstream main
    ./scripts/sync-env.sh
    git push origin main

## Local config (this directory, never in git)

- overrides.env           my values (IPs, CX7 interfaces, PORT, SERVED_MODEL_NAME, LIMIT_MM),
                          written over .env.example to produce .env
- baseline.env.example    last .env.example seen; used to warn when upstream
                          changes the default of a key I override (warning only)
