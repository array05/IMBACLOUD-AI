from fastapi import Header, HTTPException, status

from app.config import get_settings


def verify_worker_token(authorization: str | None = Header(default=None)) -> None:
    if not authorization:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing token")

    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid auth header")

    if token != get_settings().worker_token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid worker token")
