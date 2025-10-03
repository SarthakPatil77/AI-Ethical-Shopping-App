# main.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import requests
import time

app = FastAPI(title="ShopLens Backend (dev)")

OPENFOOD_URL = "https://world.openfoodfacts.org/api/v0/product/{}.json"

# Simple in-memory cache: { barcode: (timestamp, response_dict) }
CACHE = {}
CACHE_TTL_SECONDS = 60 * 60  # 1 hour in dev; tune later

class ProductResponse(BaseModel):
    barcode: str
    name: str | None = None
    brands: str | None = None
    ingredients: str | None = None
    source: str | None = None
    timestamp: float

def _fetch_from_openfood(barcode: str) -> dict | None:
    """Call OpenFoodFacts and return transformed dict or None if not found."""
    try:
        r = requests.get(OPENFOOD_URL.format(barcode), timeout=6)
        if r.status_code != 200:
            return None
        data = r.json()
        if data.get("status") != 1:
            return None
        product = data["product"]
        return {
            "barcode": barcode,
            "name": product.get("product_name"),
            "brands": product.get("brands"),
            "ingredients": product.get("ingredients_text"),
            "source": "OpenFoodFacts",
            "timestamp": time.time(),
        }
    except requests.RequestException:
        return None

@app.get("/product/{barcode}", response_model=ProductResponse)
def get_product(barcode: str):
    # normalize barcode string
    barcode = barcode.strip()
    now = time.time()

    # Check cache
    cached = CACHE.get(barcode)
    if cached:
        ts, data = cached
        if now - ts < CACHE_TTL_SECONDS:
            return data

    # Not in cache or expired — fetch upstream
    data = _fetch_from_openfood(barcode)
    if data is None:
        # Save a small negative cache (to avoid repeated upstream hits)
        CACHE[barcode] = (now, ProductResponse(
            barcode=barcode, name=None, brands=None, ingredients=None, source=None, timestamp=now
        ).dict())
        raise HTTPException(status_code=404, detail="Product not found")

    # store in cache and return
    CACHE[barcode] = (now, data)
    return data
