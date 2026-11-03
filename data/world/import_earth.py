"""Rebuild normalized Earth polygons from public-domain Natural Earth 1:110m data."""
import json
import urllib.request
from pathlib import Path

SOURCE = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_admin_0_countries.geojson"
path = Path(__file__).with_name("earth_regions.json")
with urllib.request.urlopen(SOURCE) as response:
    source = json.load(response)
regions = {}
for feature in source["features"]:
    name = feature["properties"]["CONTINENT"]
    name = {"Europe": "Eurasia", "Asia": "Eurasia", "Oceania": "Australia"}.get(name, name)
    if name == "Seven seas (open ocean)":
        name = "Africa"
    geometry = feature["geometry"]
    polygons = geometry["coordinates"] if geometry["type"] == "MultiPolygon" else [geometry["coordinates"]]
    for polygon in polygons:
        # National borders disappear when adjacent land hexes are rendered.
        regions.setdefault(name, []).append([
            [round((lon + 180) / 360, 6), round((90 - lat) / 180, 6)]
            for lon, lat in polygon[0]
        ])

def box(west, south, east, north):
    return [[(west + 180) / 360, (90 - north) / 180],
            [(east + 180) / 360, (90 - north) / 180],
            [(east + 180) / 360, (90 - south) / 180],
            [(west + 180) / 360, (90 - south) / 180]]

# Broad geographic terrain bands, not a claim of surveyed biome boundaries.
biomes = [
    {"terrain": "snow", "polygons": [box(-180, -90, 180, -60), box(-180, 74, 180, 90), box(-60, 60, -20, 84)]},
    {"terrain": "tundra", "polygons": [box(-170, 62, -52, 74), box(35, 65, 180, 74), box(10, 69, 35, 74)]},
    {"terrain": "mountain", "polygons": [box(-125, 30, -110, 60), box(-79, -55, -68, 8), box(65, 27, 100, 38), box(5, 44, 16, 48), box(55, 50, 65, 67)]},
    {"terrain": "desert", "polygons": [box(-17, 15, 35, 32), box(35, 15, 60, 32), box(12, -30, 28, -18), box(115, -31, 140, -20), box(85, 37, 115, 46), box(-116, 25, -103, 37)]},
    {"terrain": "forest", "polygons": [box(-78, -15, -45, 5), box(10, -6, 30, 6), box(95, -10, 150, 20), box(-140, 48, -55, 65), box(5, 50, 140, 65), box(-90, 32, -65, 48)]},
]
cities = [("Western Port", -122.4, 37.8), ("Atlantic Metro", -74, 40.7), ("Pacific Capital", -99.1, 19.4), ("Andean Gate", -77, -12), ("Southern Harbor", -43.2, -22.9), ("Northern Exchange", 0, 51.5), ("Eastern Capital", 37.6, 55.8), ("Nile City", 31.2, 30), ("Coastal Bazaar", 3.4, 6.5), ("Southern Cross", 18.4, -33.9), ("River Junction", 77.2, 28.6), ("Eastern Megacity", 116.4, 39.9), ("Island Harbor", 139.7, 35.7), ("Coral Port", 151.2, -33.9)]
resources = [("Northern Oil", -110, 56), ("Interior Ore", -105, 39), ("Andean Copper", -70, -24), ("Rainforest Timber", -60, -4), ("Saharan Gas", 10, 27), ("Southern Diamonds", 25, -27), ("Northern Iron", 20, 65), ("Steppe Metals", 70, 49), ("Eastern Lithium", 105, 34), ("Desert Uranium", 132, -25)]
result = {"name": "Earth", "description": "Natural Earth 1:110m land outlines, equirectangular projection. Broad illustrative biomes; no political borders.", "source": SOURCE, "license": "Natural Earth public domain: https://www.naturalearthdata.com/about/terms-of-use/", "continents": [{"name": name, "polygons": polygons} for name, polygons in regions.items()], "biomes": biomes, "sites": [{"kind": kind, "name": name, "at": [(lon + 180) / 360, (90 - lat) / 180]} for kind, points in [("city", cities), ("resource", resources)] for name, lon, lat in points]}
path.write_text(json.dumps(result, separators=(",", ":")) + "\n")
print(f"Imported {sum(len(p) for p in regions.values())} polygons in {len(regions)} regions")
