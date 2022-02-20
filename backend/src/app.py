from typing import Optional

import httpx
from pydantic import BaseModel
from starlette_csrf import CSRFMiddleware
from fastapi import FastAPI, Response, Request

app = FastAPI()
app.add_middleware(CSRFMiddleware, secret="SUPERSECRET")

client = httpx.AsyncClient()

async def get_user(request):
    response = await client.get("http://api:8001/rpc/current_user", cookies=request.cookies,
                                headers={"content-type": "application/json"})
    user = response.json()
    if not user["user_id"]:
        return None

    return user


class FileBase64(BaseModel):
    name: str
    content: Optional[str]


@app.post("/rpc/upload_file")
async def upload_file(file: FileBase64, request: Request):
    user = await get_user(request)
    return {"HELLO": file, "user": user}


@app.get("{path:path}")
async def postgrest_api(request: Request):
    path = request.path_params["path"]
    query = str(request.query_params)
    result = await client.get(f"http://api:8001{path}?{query}")
    headers = result.headers
    content_type = headers.pop("content-type")
    return Response(content=result.content, status_code=result.status_code, headers=headers, media_type=content_type)


@app.post("{path:path}")
async def postgrest_api(request: Request):
    path = request.path_params["path"]
    query = str(request.query_params)
    json = await request.json()
    headers = {**request.headers}
    headers.pop("content-length")
    cookies = {**request.cookies}

    result = await client.post(f"http://api:8001{path}?{query}", headers=headers, cookies=cookies, json=json)

    headers = result.headers
    content_type = headers.pop("content-type")
    return Response(content=result.content, status_code=result.status_code, headers=headers, media_type=content_type)
