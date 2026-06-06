"""Production entrypoint for Render and other PaaS hosts.

Binds to 0.0.0.0 and reads the port from the PORT environment variable
(set automatically by Render).
"""

from __future__ import annotations

import os

import uvicorn

if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8000"))
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=port,
        log_level="info",
    )
