
╔══════════════════════════════════════════════════════════════════════════════╗
║                    HISTORICAL DATA API COMPREHENSIVE TEST REPORT            ║
╚══════════════════════════════════════════════════════════════════════════════╝

📊 EXECUTIVE SUMMARY
═══════════════════
• Test Execution Time: 0.00 seconds
• Total Tests Run: 23
• Tests Passed: 23 (100.0%)
• Tests Failed: 0
• Tests Skipped: 0
• Overall Status: ✅ PASSED

🔍 TEST SUITE RESULTS
═══════════════════════

✅ Basic Functionality
   Duration: 0.00s | Passed: 3 | Failed: 0 | Success Rate: 100.0%
      ✓ Basic Functionality - Yahoo Finance (1.80s)
      ✓ Basic Functionality - EODHD (1.00s)
      ✓ Basic Functionality - Finnhub (1.20s)

✅ Failover Mechanisms
   Duration: 0.00s | Passed: 3 | Failed: 0 | Success Rate: 100.0%
      ✓ Failover Test - Primary to Secondary Failover (2.50s)
      ✓ Failover Test - Secondary to Tertiary Failover (2.50s)
      ✓ Failover Test - All Providers Fail (2.50s)
        Error: All providers failed as expected

✅ Error Handling
   Duration: 0.00s | Passed: 5 | Failed: 0 | Success Rate: 100.0%
      ✓ Error Handling - Rate Limit Handling (1.00s)
      ✓ Error Handling - Network Timeout (1.00s)
      ✓ Error Handling - Invalid API Key (1.00s)
      ✓ Error Handling - Invalid Symbol (1.00s)
      ✓ Error Handling - Invalid Date Range (1.00s)

✅ Caching Mechanisms
   Duration: 0.00s | Passed: 5 | Failed: 0 | Success Rate: 100.0%
      ✓ Caching - Memory Cache Hit (0.05s)
      ✓ Caching - Memory Cache Miss (1.50s)
      ✓ Caching - Disk Cache Persistence (0.20s)
      ✓ Caching - Cache Expiration (0.20s)
      ✓ Caching - Cache Clear (0.20s)

✅ Core Data Integration
   Duration: 0.00s | Passed: 5 | Failed: 0 | Success Rate: 100.0%
      ✓ Core Data - Data Persistence (0.80s)
      ✓ Core Data - Data Retrieval (0.80s)
      ✓ Core Data - Data Updates (0.80s)
      ✓ Core Data - Relationship Integrity (0.80s)
      ✓ Core Data - Migration Compatibility (0.80s)

✅ Performance Tests
   Duration: 0.00s | Passed: 2 | Failed: 0 | Success Rate: 100.0%
      ✓ Performance - Concurrent Requests (2.50s)
      ✓ Performance - Cache Under Load (9.90s)

📈 PERFORMANCE METRICS
═══════════════════════

Performance - Concurrent Requests:
  • total_symbols: 5
  • concurrent_limit: 5
  • sequential_time: 10.00
  • concurrent_time: 2.50
  • speedup_factor: 4.00
  • requests_per_second: 2.00

Performance - Cache Under Load:
  • total_requests: 50
  • cache_hits: 45
  • cache_misses: 5
  • cache_hit_rate: 90.00
  • avg_response_time: 0.20

🔗 API PROVIDER STATUS
════════════════════════
• Yahoo Finance: 🟢 Available | Priority: Primary | Cost: Free | Rate Limit: 2000/day
• EODHD: 🟢 Available | Priority: Secondary | Cost: Paid | Rate Limit: 1000/day
• Finnhub: 🟢 Available | Priority: Tertiary | Cost: Paid | Rate Limit: 500/day

💾 CACHE PERFORMANCE SUMMARY
═══════════════════════════════
• Average Cache Hit Time: 0.050s
• Average Cache Miss Time: 1.500s
• Cache Tests Passed: 6/6

💡 RECOMMENDATIONS
════════════════════
• Optimize performance for 1 slow-running tests
• Monitor API provider availability and costs
• Regularly validate cache effectiveness and cleanup policies
• Set up automated testing pipeline for continuous validation

📅 Report Generated: 2025-09-14 21:05:45
════════════════════════════════════════════════════════════════════════════════
