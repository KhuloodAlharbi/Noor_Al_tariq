"""
Noor Al-Tariq - Crowd Density API (v3 - with Best Times)
=========================================================
Returns real-time crowd density data + suggested best visit times
for major Hajj/Umrah locations around Masjid al-Haram.

Run with:
    python -m uvicorn crowd_api:app --host 0.0.0.0 --port 8001 --reload
"""

import random
from datetime import datetime
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="Noor Al-Tariq Crowd API",
    description="Real-time crowd density + best visit times",
    version="3.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ----- ZONES with best visit times -----
ZONES = [
    {
        "id": "mataf",
        "name": "Mataf (around Kaaba)",
        "lat": 21.4225,
        "lng": 39.8262,
        "radius": 80,
        "best_time": "2:00 AM - 4:00 AM",
        "best_time_note": "Least crowded after Tahajjud prayer",
    },
    {
        "id": "saee_zone",
        "name": "Saee Area",
        "lat": 21.4220,
        "lng": 39.8280,
        "radius": 60,
        "best_time": "10:00 AM - 12:00 PM",
        "best_time_note": "Most pilgrims rest between Dhuhr and Asr",
    },
    {
        "id": "gate_zone",
        "name": "King Abdulaziz Gate",
        "lat": 21.4220,
        "lng": 39.8275,
        "radius": 50,
        "best_time": "After Isha prayer",
        "best_time_note": "Foot traffic drops after last prayer",
    },
    {
        "id": "outer",
        "name": "Outer Courtyard",
        "lat": 21.4250,
        "lng": 39.8240,
        "radius": 70,
        "best_time": "6:00 AM - 8:00 AM",
        "best_time_note": "Calm period before morning rush",
    },
    {
        "id": "marwah",
        "name": "Marwah End",
        "lat": 21.4257,
        "lng": 39.8298,
        "radius": 55,
        "best_time": "11:00 PM - 1:00 AM",
        "best_time_note": "Late night is usually quiet",
    },
]


def _level_for(density: float) -> str:
    if density >= 0.7:
        return "crowded"
    if density >= 0.4:
        return "medium"
    return "safe"


def _random_density() -> float:
    band = random.choices(
        ["safe", "medium", "crowded"],
        weights=[35, 35, 30],
    )[0]
    if band == "safe":
        return round(random.uniform(0.10, 0.39), 2)
    elif band == "medium":
        return round(random.uniform(0.40, 0.69), 2)
    else:
        return round(random.uniform(0.70, 0.95), 2)


# ----- ENDPOINTS -----

@app.get("/")
def root():
    return {
        "service": "Noor Al-Tariq Crowd API",
        "status": "running",
        "version": "3.0.0",
        "endpoints": [
            "/crowd_density",
            "/crowd_density/{zone_id}",
            "/scenario/{name}",
        ],
    }


@app.get("/crowd_density")
def get_crowd_density():
    zones = []
    for z in ZONES:
        density = _random_density()
        zones.append({
            "id": z["id"],
            "name": z["name"],
            "lat": z["lat"],
            "lng": z["lng"],
            "radius": z["radius"],
            "density": density,
            "level": _level_for(density),
            "best_time": z["best_time"],
            "best_time_note": z["best_time_note"],
        })

    return {
        "timestamp": datetime.now().isoformat(),
        "zones": zones,
    }


@app.get("/scenario/{name}")
def get_scenario(name: str):
    zones = []
    for z in ZONES:
        if name == "prayer_time":
            density = round(random.uniform(0.78, 0.95), 2)
        elif name == "off_peak":
            density = round(random.uniform(0.10, 0.30), 2)
        else:
            density = _random_density()

        zones.append({
            "id": z["id"],
            "name": z["name"],
            "lat": z["lat"],
            "lng": z["lng"],
            "radius": z["radius"],
            "density": density,
            "level": _level_for(density),
            "best_time": z["best_time"],
            "best_time_note": z["best_time_note"],
        })

    return {
        "timestamp": datetime.now().isoformat(),
        "scenario": name,
        "zones": zones,
    }


@app.get("/crowd_density/{zone_id}")
def get_zone_density(zone_id: str):
    for z in ZONES:
        if z["id"] == zone_id:
            density = _random_density()
            return {
                "id": z["id"],
                "name": z["name"],
                "lat": z["lat"],
                "lng": z["lng"],
                "radius": z["radius"],
                "density": density,
                "level": _level_for(density),
                "best_time": z["best_time"],
                "best_time_note": z["best_time_note"],
                "timestamp": datetime.now().isoformat(),
            }
    return {"error": f"Zone '{zone_id}' not found"}, 404