from __future__ import annotations

import unittest

from voxhandoff_stt.cli import main


class SttCliTest(unittest.TestCase):
    def test_missing_model_fails_closed_before_starting_service(self) -> None:
        self.assertEqual(main(["--model", "/absolute/path/that-does-not-exist"]), 2)

    def test_relative_model_path_fails_closed(self) -> None:
        self.assertEqual(main(["--model", "relative-model"]), 2)


if __name__ == "__main__":
    unittest.main()
