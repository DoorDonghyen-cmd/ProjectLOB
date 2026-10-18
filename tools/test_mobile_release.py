"""Offline delivery safeguards; no Google Drive mutations."""
import contextlib
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import mobile_release as delivery


class DeliveryTests(unittest.TestCase):
    def test_architecture_manifest_matches_actual_payload(self):
        arm64 = "lib/arm64-v8a/libgodot_android.so"
        armv7 = "lib/armeabi-v7a/libgodot_android.so"
        delivery.verify_architectures({"architectures": ["arm64-v8a"]}, [arm64])
        delivery.verify_architectures({"architectures": ["arm64-v8a", "armeabi-v7a"]}, [arm64, armv7])
        for abis, names in [([], [arm64]), (["arm64-v8a"], []), (["arm64-v8a"], [arm64, armv7]), (["x86"], []), (["arm64-v8a", "arm64-v8a"], [arm64])]:
            with self.subTest(abis=abis, names=names), self.assertRaises(ValueError):
                delivery.verify_architectures({"architectures": abis}, names)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.payload = self.root / "download.zip"
        self.payload.write_bytes(b"test release")
        self.request = {"file_name": "release.zip", "parent_folder_id": "folder123", "size_bytes": self.payload.stat().st_size, "sha256": delivery.digest(self.payload), "md5": delivery.digest(self.payload, "md5")}
        self.metadata = {"id": "file123", "title": "release.zip", "mime_type": "application/zip", "size": str(self.request["size_bytes"]), "parent_ids": ["folder123"], "url": "https://drive.google.com/file/d/file123/view"}

    def tearDown(self):
        self.temp.cleanup()

    def test_connector_readback_download(self):
        receipt = delivery.validate_remote(self.request, {"structuredContent": self.metadata}, self.payload)
        self.assertEqual(receipt["file_id"], "file123")

    def test_missing_or_incorrect_checksum_fails(self):
        with self.assertRaises(ValueError):
            delivery.validate_remote(self.request, self.metadata)
        self.metadata["md5Checksum"] = "0" * 32
        with self.assertRaises(ValueError):
            delivery.validate_remote(self.request, self.metadata)

    def test_checksum_metadata(self):
        self.metadata["md5Checksum"] = self.request["md5"]
        delivery.validate_remote(self.request, self.metadata)

    def test_wrong_destination_size_name_or_link_fails(self):
        for key, value in [("parent_ids", ["elsewhere"]), ("size", "1"), ("title", "other.zip"), ("url", "https://example.com/file123")]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                delivery.validate_remote(self.request, dict(self.metadata, **{key: value}), self.payload)

    def test_modified_download_fails(self):
        self.payload.write_bytes(b"tampered release")
        with self.assertRaises(ValueError):
            delivery.validate_remote(self.request, self.metadata, self.payload)

    def test_package_allowlist_and_no_overwrite(self):
        release = self.root / "release"
        release.mkdir()
        apk = release / delivery.APK_NAME
        apk.write_bytes(b"sample validated APK")
        delivery.write_json(release / "build_manifest.json", {"sha256": delivery.digest(apk), "version_name": "test", "version_code": 1})
        delivery.write_json(release / "validation.json", {"apk_sha256": delivery.digest(apk)})
        (release / "INSTALL.md").write_text("Install")
        (release / "RELEASE_NOTES.md").write_text("Changes")
        (release / "private-settings.json").write_text("must never ship")
        with contextlib.redirect_stdout(io.StringIO()):
            delivery.package(release)
        with zipfile.ZipFile(release / "release.zip") as archive:
            self.assertEqual(set(archive.namelist()), {delivery.APK_NAME, "INSTALL.md", "RELEASE_NOTES.md", "build_manifest.json", "validation.json", "SHA256SUMS.txt"})
        with self.assertRaises(FileExistsError):
            delivery.package(release)

    def test_oversized_zip_never_becomes_upload_request(self):
        release = self.root / "oversized"
        release.mkdir()
        apk = release / delivery.APK_NAME
        apk.write_bytes(b"sample validated APK")
        delivery.write_json(release / "build_manifest.json", {"sha256": delivery.digest(apk), "version_name": "test", "version_code": 1})
        delivery.write_json(release / "validation.json", {"apk_sha256": delivery.digest(apk)})
        (release / "INSTALL.md").write_text("Install")
        (release / "RELEASE_NOTES.md").write_text("Changes")
        original_read = delivery.read_json

        def limited_config(path):
            value = original_read(path)
            if Path(path).name == "mobile_delivery.json":
                value["drive"]["max_upload_bytes"] = 1
            return value

        with patch.object(delivery, "read_json", side_effect=limited_config):
            with self.assertRaisesRegex(ValueError, "upload limit"):
                delivery.package(release)
        self.assertFalse((release / "delivery_request.json").exists())


if __name__ == "__main__":
    unittest.main()
