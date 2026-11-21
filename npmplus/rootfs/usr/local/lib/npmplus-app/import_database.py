#!/usr/bin/env python3
"""Copies the SQLite database of a Nginx Proxy Manager installation for use by NPMplus.

    import_database.py SOURCE TARGET MIGRATIONS_DIR

The source is only ever opened read-only. Before anything is written the script checks that

  * the file is an intact SQLite database created by Nginx Proxy Manager, and
  * every schema migration recorded in it is also known to the installed NPMplus.

The second rule matters: NPMplus follows upstream Nginx Proxy Manager with a delay. A database
written by a newer release records migrations NPMplus cannot reproduce, and starting NPMplus on it
would fail inside the migration step. Refusing early keeps the original data usable.

The copy goes through SQLite's backup API, so it is consistent even if the old app is still
running, and it is moved into place atomically.
"""
import os
import sqlite3
import sys
import tempfile
from pathlib import Path


def open_read_only(path):
    return sqlite3.connect(f"file:{path}?mode=ro", uri=True)


def applied_migrations(database):
    """Names of the knex migrations recorded in an Nginx Proxy Manager database."""
    try:
        return {row[0] for row in database.execute("SELECT name FROM migrations")}
    except sqlite3.DatabaseError:
        raise SystemExit("[ERROR] The file is not a Nginx Proxy Manager database (no migration history found).")


def assert_intact(database):
    try:
        result = database.execute("PRAGMA integrity_check").fetchone()[0]
    except sqlite3.DatabaseError as error:
        raise SystemExit(f"[ERROR] The database cannot be read: {error}")
    if result != "ok":
        raise SystemExit(f"[ERROR] The database failed its integrity check: {result}")


def assert_known_migrations(applied, migrations_dir):
    known = {entry.name for entry in Path(migrations_dir).iterdir()}
    unknown = sorted(applied - known)
    if unknown:
        raise SystemExit(
            "[ERROR] The database was written by a newer Nginx Proxy Manager than this NPMplus release supports.\n"
            "[ERROR] Unknown migrations: " + ", ".join(unknown) + "\n"
            "[ERROR] Nothing was changed. Wait for a newer version of this app, or start without an import."
        )


def copy_database(source, target):
    """Writes a consistent copy next to the target and renames it into place."""
    target = Path(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    handle, temporary = tempfile.mkstemp(dir=target.parent, prefix=".import-", suffix=".sqlite")
    os.close(handle)
    try:
        destination = sqlite3.connect(temporary)
        with destination:
            source.backup(destination)
        destination.close()
        os.chmod(temporary, 0o600)
        os.replace(temporary, target)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main(source_path, target_path, migrations_dir):
    source = open_read_only(source_path)
    try:
        assert_intact(source)
        assert_known_migrations(applied_migrations(source), migrations_dir)
        copy_database(source, target_path)
    finally:
        source.close()
    print(f"Imported {source_path}")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    main(*sys.argv[1:])
