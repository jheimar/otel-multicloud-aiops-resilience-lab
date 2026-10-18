import unittest
from correlation import Window, correlate

class TestCorrelation(unittest.TestCase):
    def setUp(self):
        self.base = [Window(str(i), 100, 0, 90.0) for i in range(10)]
    def test_both_breached(self):
        d = correlate(self.base, Window("event",100,10,280.0,"a"*32))
        self.assertTrue(d["correlated_alert"])
        self.assertEqual(d["trace_id"], "a"*32)
    def test_latency_alone_not_correlated(self):
        d = correlate(self.base, Window("event",100,0,300.0))
        self.assertFalse(d["correlated_alert"])
        self.assertTrue(d["latency_only_alert"])
    def test_error_alone_not_correlated(self):
        d = correlate(self.base, Window("event",100,10,100.0))
        self.assertFalse(d["correlated_alert"])
    def test_min_baseline(self):
        with self.assertRaises(ValueError):
            correlate(self.base[:4], Window("x",100,1,300.0))

if __name__ == "__main__": unittest.main()
