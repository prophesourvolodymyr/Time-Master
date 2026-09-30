#!/usr/bin/env python3
from __future__ import annotations
import argparse
import datetime
import gzip
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import sqlite3
import subprocess
import sys
import zipfile
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

import osmium
from shapely.errors import GEOSException
from shapely.geometry import box, shape, mapping
from shapely.ops import polygonize, unary_union
from shapely.strtree import STRtree

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "TimeMaster/Resources/OfflineRouting"


def run(*args):
    subprocess.run([str(arg) for arg in args], check=True)


def digest(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(262144), b""):
            result.update(chunk)
    return result.hexdigest()


class MapIndex(osmium.SimpleHandler):
    def __init__(self, database, output, bounds):
        super().__init__()
        self.db = database
        self.output = output
        self.bounds = box(*bounds)
        self.raw_bounds = bounds
        self.factory = osmium.geom.GeoJSONFactory()
        self.coastlines = []
        self.invalid_geometries = 0
    def feature(self, layer, geometry, properties, clipped=False):
        try:
            local = shape(geometry)
            if not clipped:
                local = local.intersection(self.bounds)
        except GEOSException:
            self.invalid_geometries += 1
            return
        if local.is_empty:
            return
        self.output.write(json.dumps({"type": "Feature", "geometry": mapping(local), "properties": properties,
                                      "tippecanoe": {"layer": layer}}, ensure_ascii=False, separators=(",", ":")) + "\n")

    def place(self, identifier, tags, longitude, latitude):
        category = "parks" if tags.get("leisure") == "park" else "cafes" if tags.get("amenity") == "cafe" else "water" if tags.get("amenity") == "drinking_water" else "viewpoints" if tags.get("tourism") == "viewpoint" else None
        address = " ".join(filter(None, [tags.get("addr:housenumber"), tags.get("addr:street")]))
        name = tags.get("name:en") or tags.get("name") or address or {"parks": "Park", "cafes": "Café", "water": "Drinking water", "viewpoints": "Viewpoint"}.get(category)
        if not name or not self.bounds.covers(shape({"type": "Point", "coordinates": [longitude, latitude]})):
            return
        detail = ", ".join(dict.fromkeys(filter(None, [address if address != name else None, tags.get("addr:city"), tags.get("addr:suburb"), tags.get("addr:postcode")])))
        self.db.execute("INSERT INTO places(id,name,detail,lat,lon,category) VALUES(?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name,detail=excluded.detail,lat=excluded.lat,lon=excluded.lon,category=excluded.category", (identifier, name, detail, latitude, longitude, category))

    def node(self, node):
        if not node.location.valid():
            return
        tags = dict(node.tags)
        if not tags:
            return
        self.place("n" + str(node.id), tags, node.location.lon, node.location.lat)
        if tags.get("place") in {"city", "town", "village", "suburb", "neighbourhood"} and tags.get("name"):
            self.feature("place", {"type": "Point", "coordinates": [node.location.lon, node.location.lat]}, {"name": tags.get("name:en", tags["name"]), "class": tags["place"]})

    def way(self, way):
        tags = dict(way.tags)
        highway = tags.get("highway")
        if not highway and not tags.get("railway") and not tags.get("waterway") and tags.get("natural") != "coastline" and not tags.get("name") and not tags.get("addr:housenumber"):
            return
        try:
            geometry = json.loads(self.factory.create_linestring(way))
            local = shape(geometry).intersection(self.bounds)
        except (RuntimeError, GEOSException):
            self.invalid_geometries += 1
            return
        if local.is_empty:
            return
        center = local.representative_point()
        self.place("w" + str(way.id), tags, center.x, center.y)
        local_geometry = mapping(local)
        if tags.get("natural") == "coastline":
            self.coastlines.append(shape(geometry))
        if tags.get("waterway") in {"river", "stream", "canal", "drain"}:
            self.feature("waterway", local_geometry, {"class": tags["waterway"]}, clipped=True)
        if highway or tags.get("railway"):
            road_class = highway if highway in {"motorway", "trunk", "primary", "secondary", "tertiary", "service"} else "path" if highway in {"footway", "path", "cycleway", "steps", "bridleway", "pedestrian"} else "transit" if tags.get("railway") else "street"
            properties = {"class": road_class, "subclass": highway or tags.get("railway"), "bicycle": tags.get("bicycle", "")}
            self.feature("transportation", local_geometry, properties, clipped=True)
            if tags.get("name"):
                self.feature("transportation_name", local_geometry, {**properties, "name": tags.get("name:en", tags["name"])}, clipped=True)
        if not highway:
            return
        surface = tags.get("surface", "")
        paved = {"asphalt", "paved", "concrete", "concrete:plates", "concrete:lanes", "paving_stones", "sett", "cobblestone", "chipseal"}
        unpaved = {"unpaved", "gravel", "fine_gravel", "ground", "dirt", "earth", "grass", "sand", "compacted", "wood", "pebblestone", "mud"}
        value = 0 if surface in paved else 1 if surface in unpaved else None
        self.db.execute("INSERT OR REPLACE INTO way_surfaces VALUES(?,?)", (way.id, value))
        public = tags.get("access") not in {"private", "no", "customers"} and highway not in {"construction", "proposed", "motorway", "motorway_link", "trunk", "trunk_link"}
        walking = public and tags.get("foot") not in {"no", "private"}
        cycling = public and tags.get("bicycle") not in {"no", "private"} and highway != "steps" and (highway != "footway" or tags.get("bicycle") in {"yes", "designated", "permissive"})
        if walking or cycling:
            for index, node in enumerate(way.nodes):
                if index not in {0, len(way.nodes) - 1} and index % 8:
                    continue
                if not node.location.valid():
                    continue
                west, south, east, north = self.raw_bounds
                if not (west <= node.location.lon <= east and south <= node.location.lat <= north):
                    continue
                self.db.execute("INSERT INTO anchors VALUES(?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET cycling=max(cycling,excluded.cycling),walking=max(walking,excluded.walking)", (node.ref, node.location.lat, node.location.lon, int(cycling), int(walking)))

    def area(self, area):
        tags = dict(area.tags)
        layer = "water" if tags.get("natural") == "water" or tags.get("water") or tags.get("landuse") == "reservoir" else "park" if tags.get("leisure") in {"park", "garden", "nature_reserve", "golf_course"} or tags.get("landuse") in {"forest", "grass", "meadow", "recreation_ground"} or tags.get("natural") in {"wood", "scrub"} else "building" if tags.get("building") else None
        if not layer and not tags.get("name") and not tags.get("addr:housenumber"):
            return
        try:
            geometry = json.loads(self.factory.create_multipolygon(area))
            polygon = shape(geometry)
            if polygon.is_empty:
                return
            local = polygon.intersection(self.bounds)
        except (RuntimeError, ValueError, GEOSException):
            self.invalid_geometries += 1
            return
        if local.is_empty:
            return
        if layer:
            self.feature(layer, mapping(local), {"class": tags.get("leisure") or tags.get("landuse") or tags.get("natural") or "building"}, clipped=True)
        point = local.representative_point()
        self.place(("w" if area.from_way() else "r") + str(area.orig_id()), tags, point.x, point.y)

    def oceans(self):
        if not self.coastlines:
            return
        clipped = [line.intersection(self.bounds) for line in self.coastlines if line.intersects(self.bounds)]
        tree = STRtree(self.coastlines)
        for polygon in polygonize(unary_union(clipped + [self.bounds.boundary])):
            point = polygon.representative_point()
            line = self.coastlines[int(tree.nearest(point))]
            distance = line.project(point)
            first = line.interpolate(max(0, distance - 0.00001))
            second = line.interpolate(min(line.length, distance + 0.00001))
            cross = (second.x - first.x) * (point.y - first.y) - (second.y - first.y) * (point.x - first.x)
            if cross < 0:
                self.feature("water", mapping(polygon), {"class": "ocean"})


def elevation_tiles(source, destination, bounds):
    import numpy as np
    destination.mkdir(parents=True, exist_ok=True)
    resolution = 30
    for latitude in range(math.floor(bounds[1]), math.ceil(bounds[3])):
        for longitude in range(math.floor(bounds[0]), math.ceil(bounds[2])):
            name = f"{'N' if latitude >= 0 else 'S'}{abs(latitude):02}{'E' if longitude >= 0 else 'W'}{abs(longitude):03}.hgt"
            direct = source / name
            if direct.exists():
                raw = direct.read_bytes()
            elif (source / (name + ".zip")).exists():
                with zipfile.ZipFile(source / (name + ".zip")) as archive:
                    entry = next(item for item in archive.namelist() if Path(item).name.lower() == name.lower())
                    raw = archive.read(entry)
            elif (source / (name + ".gz")).exists():
                raw = gzip.decompress((source / (name + ".gz")).read_bytes())
            else:
                raise RuntimeError(f"Missing elevation tile {name}; supply it or explicitly use --without-elevation")
            side = math.isqrt(len(raw) // 2)
            if side * side * 2 != len(raw) or side not in {1201, 3601}:
                raise RuntimeError(f"Unsupported HGT dimensions for {name}")
            if side == 1201:
                resolution = 90
                old = np.frombuffer(raw, dtype=">i2").reshape((side, side)).astype(np.float32)
                axis = np.arange(3601) / 3
                left = np.minimum(axis.astype(np.int32), 1199)
                weight = axis - left
                horizontal = old[:, left] * (1 - weight) + old[:, left + 1] * weight
                invalid_horizontal = (old[:, left] == -32768) | (old[:, left + 1] == -32768)
                result = horizontal[left, :] * (1 - weight[:, None]) + horizontal[left + 1, :] * weight[:, None]
                result[invalid_horizontal[left, :] | invalid_horizontal[left + 1, :]] = -32768
                raw = np.rint(result).astype(">i2").tobytes()
            (destination / name).write_bytes(raw)
    return resolution

def timezone_database(destination, bounds, identifier):
    try:
        ZoneInfo(identifier)
    except ZoneInfoNotFoundError as error:
        raise RuntimeError(f"Unknown IANA time zone: {identifier}") from error
    executable = shutil.which("spatialite")
    if not executable:
        raise RuntimeError("spatialite is required to assign the regional time zone")
    west = max(-180, bounds[0] - 2)
    south = max(-90, bounds[1] - 2)
    east = min(180, bounds[2] + 2)
    north = min(90, bounds[3] + 2)
    escaped = identifier.replace("'", "''")
    polygon = f"MULTIPOLYGON((({west} {south},{east} {south},{east} {north},{west} {north},{west} {south})))"
    sql = f"""
    CREATE TABLE tz_world (TZID TEXT NOT NULL);
    SELECT AddGeometryColumn('tz_world','geom',4326,'MULTIPOLYGON','XY');
    INSERT INTO tz_world(TZID,geom) VALUES('{escaped}',GeomFromText('{polygon}',4326));
    SELECT CreateSpatialIndex('tz_world','geom');
    VACUUM;
    """
    result = subprocess.run([executable, "-batch", str(destination), sql], text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "Unable to create time zone database")
    with sqlite3.connect(destination) as database:
        if database.execute("SELECT count(*) FROM tz_world").fetchone()[0] != 1:
            raise RuntimeError("Regional time zone database is incomplete")




def main():
    parser = argparse.ArgumentParser(description="Prepare a TimeMaster offline area on a Mac. The phone imports the resulting ZIP and runs routing/search locally.")
    parser.add_argument("--pbf", type=Path, required=True)
    parser.add_argument("--id", required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--data-source", required=True, help="OSM provider URL and source-data timestamp, preserved in the installed area")
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--tools", type=Path, required=True, help="Directory containing the native Valhalla preparation executables")
    parser.add_argument("--source", type=Path, required=True, help="Pinned, terrain-patched Valhalla source checkout")
    parser.add_argument("--timezone-id", required=True, help="Single IANA time zone covering the regional extract")
    elevation = parser.add_mutually_exclusive_group(required=True)
    parser.add_argument("--keep-work", action="store_true")
    elevation.add_argument("--elevation-dir", type=Path)
    parser.add_argument("--elevation-attribution", type=Path, help="UTF-8 provider, license, source URL, and modification notices for supplied HGT data")
    elevation.add_argument("--without-elevation", action="store_true")
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,79}", args.id):
        parser.error("Use a lowercase, path-safe area ID")
    if args.elevation_dir and not args.elevation_attribution:
        parser.error("--elevation-attribution is required with --elevation-dir")
    if args.output.exists() or args.work.exists():
        parser.error("Output and work paths must be new; existing files are never overwritten")
    info = json.loads(subprocess.check_output(["osmium", "fileinfo", "-j", str(args.pbf)]))
    bounds = info["header"]["boxes"][0]
    if not (-180 <= bounds[0] < bounds[2] <= 180 and -90 <= bounds[1] < bounds[3] <= 90):
        parser.error("The PBF must declare valid regional bounds")
    engine = json.loads((RESOURCES / "engine.json").read_text())
    version = subprocess.check_output([str(args.tools / "valhalla_build_tiles"), "--version"], text=True)
    if engine["version"] not in version:
        parser.error("Graph tools do not match the app's native engine version")
    args.work.mkdir(parents=True)
    package = args.work / "area"
    (package / "graph").mkdir(parents=True)
    config = json.loads((RESOURCES / "routing-config.json").read_text())
    timezone_path = args.work / "timezone.sqlite"
    timezone_database(timezone_path, bounds, args.timezone_id)
    config["mjolnir"].update({"tile_dir": str(args.work / "graph-tiles"), "tile_extract": str(package / "graph/tiles.tar"), "admin": str(args.work / "admins.sqlite"), "timezone": str(timezone_path), "concurrency": 4})
    resolution = None
    if args.elevation_dir:
        resolution = elevation_tiles(args.elevation_dir, args.work / "elevation", bounds)
        config["additional_data"] = {"elevation": str(args.work / "elevation")}
    config_path = args.work / "routing.json"
    config_path.write_text(json.dumps(config))
    run(args.tools / "valhalla_build_admins", "--config", config_path, args.pbf)
    run(args.tools / "valhalla_build_tiles", "--config", config_path, "--concurrency", "4", args.pbf)
    run(sys.executable, args.source / "scripts/valhalla_build_extract", "--config", config_path)
    shutil.rmtree(args.work / "graph-tiles")
    shutil.rmtree(args.work / "elevation", ignore_errors=True)
    for temporary in [args.work / "admins.sqlite", timezone_path]:
        temporary.unlink(missing_ok=True)
    tippecanoe = subprocess.Popen([
        "tippecanoe", "-o", str(args.work / "map.mbtiles"), "-Z", "6", "-z", "14",
        "--drop-densest-as-needed", "--extend-zooms-if-still-dropping",
        "--maximum-tile-bytes=500000", "--no-tile-compression"
    ], stdin=subprocess.PIPE, text=True)
    try:
        if tippecanoe.stdin is None:
            raise RuntimeError("Could not stream local map features to tippecanoe")
        with sqlite3.connect(package / "places.sqlite") as database:
            database.executescript("""
            PRAGMA journal_mode=OFF;
            CREATE TABLE places(id TEXT UNIQUE NOT NULL,name TEXT NOT NULL,detail TEXT NOT NULL,lat REAL NOT NULL,lon REAL NOT NULL,category TEXT);
            CREATE TABLE anchors(id INTEGER PRIMARY KEY,lat REAL NOT NULL,lon REAL NOT NULL,cycling INTEGER NOT NULL,walking INTEGER NOT NULL);
            CREATE TABLE way_surfaces(id INTEGER PRIMARY KEY,unpaved INTEGER);
            """)
            handler = MapIndex(database, tippecanoe.stdin, bounds)
            handler.apply_file(str(args.pbf), locations=True, idx="flex_mem")
            handler.oceans()
            print(f"Skipped incomplete OSM geometries: {handler.invalid_geometries}", flush=True)
            database.executescript("""
            CREATE VIRTUAL TABLE places_fts USING fts5(name,detail,content='places',content_rowid='rowid',tokenize='unicode61 remove_diacritics 2');
            INSERT INTO places_fts(places_fts) VALUES('rebuild');
            CREATE VIRTUAL TABLE places_bounds USING rtree(id,min_lat,max_lat,min_lon,max_lon);
            INSERT INTO places_bounds SELECT rowid,lat,lat,lon,lon FROM places;
            CREATE VIRTUAL TABLE anchor_bounds USING rtree(id,min_lat,max_lat,min_lon,max_lon);
            INSERT INTO anchor_bounds SELECT id,lat,lat,lon,lon FROM anchors;
            CREATE INDEX place_categories ON places(category);
            ANALYZE;
            """)
            database.commit()
            database.execute("VACUUM")
            print("Indexed places:", database.execute("SELECT count(*) FROM places").fetchone()[0], flush=True)
    except BaseException:
        if tippecanoe.stdin is not None:
            try:
                tippecanoe.stdin.close()
            except BrokenPipeError:
                pass
        tippecanoe.terminate()
        tippecanoe.wait()
        raise
    try:
        tippecanoe.stdin.close()
    except BrokenPipeError:
        pass
    if tippecanoe.wait() != 0:
        raise RuntimeError("tippecanoe could not prepare the local map")
    with sqlite3.connect(args.work / "map.mbtiles") as tiles:
        zooms = tiles.execute("SELECT min(zoom_level),max(zoom_level) FROM tiles").fetchone()
        for z, x, y, data in tiles.execute("SELECT zoom_level,tile_column,tile_row,tile_data FROM tiles"):
            path = package / "tiles" / str(z) / str(x) / (str((1 << z) - 1 - y) + ".pbf")
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(gzip.decompress(data) if data[:2] == b"\x1f\x8b" else data)
    (args.work / "map.mbtiles").unlink()
    attribution = "Map and graph data © OpenStreetMap contributors, licensed under ODbL 1.0: https://www.openstreetmap.org/copyright\n"
    if args.elevation_dir:
        attribution += args.elevation_attribution.read_text().strip() + "\n"
        attribution += "TimeMaster resamples 3-arcsecond HGT input onto Valhalla's 1-arcsecond grid without claiming additional source resolution.\n"
    attribution += "Preparation source: https://github.com/prophesourvolodymyr/Time-Master/tree/main/routing\n"
    if len(attribution.encode("utf-8")) > 64_000:
        raise RuntimeError("Area attribution exceeds 64 KB")
    (package / "attribution.txt").write_text(attribution)
    records = {path.relative_to(package).as_posix(): {"size": path.stat().st_size, "sha256": digest(path)} for path in sorted(package.rglob("*")) if path.is_file()}
    if len(records) >= 99999 or sum(item["size"] for item in records.values()) > 2000000000 or zooms[1] > 18:
        raise RuntimeError("Area exceeds the phone's format limits; prepare a smaller geographic extract")
    manifest = {"schemaVersion": 1, "id": args.id, "name": args.name, "engineRevision": engine["revision"], "createdAt": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"), "source": args.data_source + " | PBF SHA256:" + digest(args.pbf), "attribution": attribution, "timeZoneID": args.timezone_id, "bounds": dict(zip(["west", "south", "east", "north"], bounds)), "hasElevation": bool(args.elevation_dir), "elevationResolutionMeters": resolution, "minZoom": zooms[0], "maxZoom": zooms[1], "files": records}
    (package / "manifest.json").write_text(json.dumps(manifest, sort_keys=True, separators=(",", ":")))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.output, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        archive.write(package / "manifest.json", "manifest.json")
        for relative in records:
            archive.write(package / relative, relative)
    print(f"Prepared {args.name}: {args.output} ({args.output.stat().st_size} bytes)", flush=True)

    if not args.keep_work:
        shutil.rmtree(args.work)

if __name__ == "__main__":
    main()
