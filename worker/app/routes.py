from pydantic import BaseModel, Field

from app.auth import verify_worker_token
from app.config import get_settings
from fastapi import APIRouter, Depends

from shared.imbai_tools.executor import ToolError, ToolExecutor

router = APIRouter(tags=["worker"])


class ExecuteRequest(BaseModel):
    tool: str = Field(..., min_length=1)
    arguments: dict = Field(default_factory=dict)
    workspace: str | None = None


@router.get("/health")
async def health():
    settings = get_settings()
    return {
        "status": "ok",
        "service": "imbai-worker",
        "workspace": settings.worker_workspace,
    }


@router.post("/v1/execute")
async def execute_tool(req: ExecuteRequest, _: None = Depends(verify_worker_token)):
    settings = get_settings()
    workspace = req.workspace or settings.worker_workspace
    executor = ToolExecutor(workspace, shell_timeout=settings.shell_timeout)

    try:
        result = executor.execute(req.tool, req.arguments)
        return {"status": "ok", "result": result, "workspace": str(executor.workspace)}
    except ToolError as exc:
        return {"status": "error", "result": str(exc), "workspace": str(executor.workspace)}
