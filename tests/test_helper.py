import importlib.util
import io
import unittest
from pathlib import Path
from unittest import mock


MODULE_PATH = Path(__file__).parents[1] / "helper" / "videopocket_helper.py"
SPEC = importlib.util.spec_from_file_location("videopocket_helper", MODULE_PATH)
helper = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(helper)


class AuthorizationTests(unittest.TestCase):
    def setUp(self):
        self.config = {"token": "private-token"}

    def test_accepts_extension_origin(self):
        headers = {"Origin": "chrome-extension://abcdefghijklmnop"}
        self.assertTrue(helper.request_authorized(headers, self.config))

    def test_accepts_token_when_origin_is_missing(self):
        headers = {"X-VideoPocket-Token": "private-token"}
        self.assertTrue(helper.request_authorized(headers, self.config))

    def test_rejects_missing_or_wrong_credentials(self):
        self.assertFalse(helper.request_authorized({}, self.config))
        self.assertFalse(helper.request_authorized(
            {"X-VideoPocket-Token": "wrong-token"}, self.config
        ))


class CompatibilityTests(unittest.TestCase):
    def probe(self, report):
        completed = mock.Mock(stderr=report)
        log = io.StringIO()
        with mock.patch.object(helper.subprocess, "run", return_value=completed):
            result = helper.already_quicktime_compatible(
                Path("video.mp4"), Path("ffmpeg"), log
            )
        return result

    def test_accepts_h264_and_aac(self):
        self.assertTrue(self.probe(
            "Stream #0:0: Video: h264 (avc1)\nStream #0:1: Audio: aac (LC)"
        ))

    def test_accepts_h264_without_audio(self):
        self.assertTrue(self.probe("Stream #0:0: Video: h264 (avc1)"))

    def test_rejects_nonzero_rotation(self):
        self.assertFalse(self.probe(
            "Video: h264 (avc1)\nAudio: aac (LC)\nrotation of 90.00 degrees"
        ))

    def test_rejects_incompatible_codecs(self):
        self.assertFalse(self.probe("Video: vp9\nAudio: opus"))


if __name__ == "__main__":
    unittest.main()
