from pathlib import Path
import copy
import hashlib
import json
import zipfile

root = Path.cwd()
artifacts = root / "rocketmq-docker/image-build/artifacts"
original = artifacts / "rocketmq.zip"
output = artifacts / "rocketmq-all-4.8.0-bin-release-loongarch64.zip"
digest = lambda data: hashlib.sha256(data).hexdigest()
assert digest(original.read_bytes()) == "56bce195af3843a234f77e4248657d0f72d5da0f7f44923bd820762e7d35c548"
provenance = json.loads((artifacts / "native/provenance.json").read_text())
by_name = {item["url"].rsplit("/", 1)[-1]: item for item in provenance}
replacements = {
    "jna-4.2.2.jar": "jna-4.2.2.jar",
    "netty-all-4.0.42.Final.jar": "netty-all-4.0.56.Final.jar",
    "netty-tcnative-boringssl-static-1.1.33.Fork26.jar": "netty-tcnative-boringssl-static-2.0.7.Final.jar",
}
payloads = {}
for old, new in replacements.items():
    data = (artifacts / "native" / new).read_bytes()
    assert digest(data) == by_name[new]["sha256"]
    payloads[old] = data

tmp = output.with_suffix(".zip.tmp")
changes = []
with zipfile.ZipFile(original) as src, zipfile.ZipFile(tmp, "w") as dst:
    assert len(src.namelist()) == len(set(src.namelist()))
    dst.comment = src.comment
    for entry in src.infolist():
        data = src.read(entry)
        info = copy.copy(entry)
        basename = Path(entry.filename).name
        if "/lib/" in entry.filename and basename in replacements:
            newname = replacements[basename]
            info.filename = entry.filename.rsplit("/", 1)[0] + "/" + newname
            changes.append({
                "old_entry": entry.filename,
                "new_entry": info.filename,
                "old_sha256": digest(data),
                "new_sha256": digest(payloads[basename]),
                "coordinate": by_name[newname]["coordinate"],
                "source": by_name[newname]["url"],
            })
            data = payloads[basename]
        dst.writestr(info, data, compress_type=entry.compress_type, compresslevel=9)
assert len(changes) == 3
with zipfile.ZipFile(original) as src, zipfile.ZipFile(tmp) as dst:
    assert dst.testzip() is None
    expected_names = set(src.namelist())
    for change in changes:
        expected_names.remove(change["old_entry"])
        expected_names.add(change["new_entry"])
    assert expected_names == set(dst.namelist())
    unchanged = 0
    for entry in src.infolist():
        basename = Path(entry.filename).name
        newname = entry.filename
        changed = "/lib/" in newname and basename in replacements
        if changed:
            newname = newname.rsplit("/", 1)[0] + "/" + replacements[basename]
            assert dst.read(newname) == payloads[basename]
        else:
            assert src.read(entry) == dst.read(newname)
            unchanged += int(not entry.is_dir())
        packaged = dst.getinfo(newname)
        assert packaged.external_attr == entry.external_attr
        assert packaged.date_time == entry.date_time
        assert packaged.is_dir() == entry.is_dir()
    entries = len(dst.infolist())
    jar_count = sum(x.filename.endswith(".jar") for x in dst.infolist())
tmp.replace(output)
print("PREPARED_ZIP", output)
print("SHA256", digest(output.read_bytes()))
print("VERIFIED replacements=3 unchanged_files=%d jars=%d entries=%d" % (unchanged, jar_count, entries))
