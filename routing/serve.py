import argparse
import hashlib
import os
from pathlib import Path
import shutil
import sys
import urllib.request

VERSION = "11.0"
MAVEN = f"https://repo1.maven.org/maven2/com/graphhopper/graphhopper-web/{VERSION}/graphhopper-web-{VERSION}.jar"


def main():
    parser = argparse.ArgumentParser(description="Run TimeMaster's GraphHopper road router on 127.0.0.1:8989. Requires Java 17+ and an OpenStreetMap .osm.pbf extract. Put an authenticated, rate-limited HTTPS reverse proxy in front of this private listener for production, and enter that URL in the app's Trip Services. Bus paths are road estimates, not transit timetables. OSM attribution: https://www.openstreetmap.org/copyright; GraphHopper: Apache-2.0, https://github.com/graphhopper/graphhopper.")
    parser.add_argument("--osm", required=True, type=Path, help="Regional OSM PBF, e.g. a Geofabrik or BBBike extract; include every intended route area")
    parser.add_argument("--data", required=True, type=Path, help="Persistent graph and SRTM elevation cache directory; use a fresh directory after changing profiles or map data")
    parser.add_argument("--java", default=shutil.which("java"), help="Java 17+ executable")
    parser.add_argument("--heap", default="4g", help="Java maximum heap, default 4g")
    args = parser.parse_args()
    if not args.java:
        parser.error("Install a Java 17+ runtime or pass --java")
    source = args.osm.resolve()
    if not source.is_file():
        parser.error("--osm must name an existing .osm.pbf file")
    directory = args.data.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    jar = directory / f"graphhopper-{VERSION}.jar"
    with urllib.request.urlopen(MAVEN + ".sha256", timeout=30) as response:
        expected = response.read().decode().strip().split()[0].lower()
    if len(expected) != 64 or any(character not in "0123456789abcdef" for character in expected):
        raise RuntimeError("Invalid Maven SHA-256 response")
    if not jar.exists() or hashlib.sha256(jar.read_bytes()).hexdigest() != expected:
        temporary = jar.with_suffix(".download")
        try:
            with urllib.request.urlopen(MAVEN, timeout=120) as response, temporary.open("wb") as output:
                shutil.copyfileobj(response, output)
            if hashlib.sha256(temporary.read_bytes()).hexdigest() != expected:
                raise RuntimeError("GraphHopper download checksum mismatch")
            temporary.replace(jar)
        finally:
            temporary.unlink(missing_ok=True)
    configuration = Path(__file__).resolve().with_name("graphhopper.yml")
    command = [args.java, f"-Xmx{args.heap}", f"-Ddw.graphhopper.datareader.file={source}", "-jar", str(jar), "server", str(configuration)]
    print("Importing or opening the road graph; /info becomes available after import. SRTM tiles download on first import.", flush=True)
    os.chdir(directory)
    os.execvpe(args.java, command, os.environ)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError) as error:
        sys.exit(str(error))
