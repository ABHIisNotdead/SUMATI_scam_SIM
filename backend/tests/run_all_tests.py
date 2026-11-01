"""Fast, deterministic offline test runner for SUMATI backend verification suite."""
import sys
import time
import unittest
from pathlib import Path

def main():
    # Ensure backend directory is in sys.path
    backend_dir = Path(__file__).resolve().parent.parent
    if str(backend_dir) not in sys.path:
        sys.path.insert(0, str(backend_dir))

    tests_dir = Path(__file__).resolve().parent
    print("=" * 70)
    print("SUMATI Backend Offline Verification Test Suite")
    print(f"Target directory: {tests_dir}")
    print("=" * 70)

    start_time = time.time()
    loader = unittest.TestLoader()
    suite = loader.discover(start_dir=str(tests_dir), pattern="test_*.py")

    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    elapsed = time.time() - start_time

    print("\n" + "=" * 70)
    print(f"Tests run: {result.testsRun}")
    print(f"Failures:  {len(result.failures)}")
    print(f"Errors:    {len(result.errors)}")
    print(f"Elapsed:   {elapsed:.3f}s (Budget: < 2.0s)")
    print("=" * 70)

    if not result.wasSuccessful():
        sys.exit(1)
    if elapsed > 2.0:
        print(f"WARNING: Test suite took {elapsed:.3f}s which exceeds the 2.0s budget!")
        sys.exit(1)

if __name__ == "__main__":
    main()
