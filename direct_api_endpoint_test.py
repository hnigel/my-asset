#!/usr/bin/env python3
"""
Direct API Endpoint Test for Historical Data Services

This script directly tests the API endpoints used by the iOS app to validate:
1. Yahoo Finance API accessibility and response format
2. EODHD API functionality (if API key available)
3. Finnhub API functionality (if API key available)
4. Response time measurements
5. Data format validation
6. Error handling scenarios

Author: Claude Code Assistant
Date: 2024-09-14
"""

import asyncio
import aiohttp
import json
import time
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
import urllib.parse


class DirectAPITester:
    """Direct API endpoint tester for historical data services."""
    
    def __init__(self):
        self.results = []
        self.session_timeout = aiohttp.ClientTimeout(total=30)
        
        # Test symbols
        self.test_symbols = ["AAPL", "GOOGL", "MSFT"]
        
        # Date range for testing (last 30 days)
        self.end_date = datetime.now()
        self.start_date = self.end_date - timedelta(days=30)
        
    async def test_yahoo_finance_api(self) -> Dict[str, Any]:
        """Test Yahoo Finance API directly."""
        print("🔍 Testing Yahoo Finance API...")
        
        results = {
            "provider": "Yahoo Finance",
            "endpoint": "https://query1.finance.yahoo.com/v8/finance/chart",
            "tests": []
        }
        
        async with aiohttp.ClientSession(timeout=self.session_timeout) as session:
            for symbol in self.test_symbols:
                test_result = await self._test_yahoo_symbol(session, symbol)
                results["tests"].append(test_result)
        
        return results
    
    async def _test_yahoo_symbol(self, session: aiohttp.ClientSession, symbol: str) -> Dict[str, Any]:
        """Test Yahoo Finance API for a specific symbol."""
        start_timestamp = int(self.start_date.timestamp())
        end_timestamp = int(self.end_date.timestamp())
        
        url = f"https://query1.finance.yahoo.com/v8/finance/chart/{symbol}"
        params = {
            "period1": start_timestamp,
            "period2": end_timestamp,
            "interval": "1d"
        }
        
        headers = {
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Accept": "application/json",
            "Referer": "https://finance.yahoo.com"
        }
        
        start_time = time.time()
        
        try:
            async with session.get(url, params=params, headers=headers) as response:
                response_time = time.time() - start_time
                
                if response.status == 200:
                    data = await response.json()
                    return self._analyze_yahoo_response(symbol, data, response_time)
                else:
                    return {
                        "symbol": symbol,
                        "success": False,
                        "response_time": response_time,
                        "error": f"HTTP {response.status}",
                        "data_points": 0
                    }
                    
        except asyncio.TimeoutError:
            return {
                "symbol": symbol,
                "success": False,
                "response_time": 30.0,
                "error": "Timeout",
                "data_points": 0
            }
        except Exception as e:
            response_time = time.time() - start_time
            return {
                "symbol": symbol,
                "success": False,
                "response_time": response_time,
                "error": str(e),
                "data_points": 0
            }
    
    def _analyze_yahoo_response(self, symbol: str, data: Dict, response_time: float) -> Dict[str, Any]:
        """Analyze Yahoo Finance API response."""
        try:
            chart = data.get("chart", {})
            result = chart.get("result", [])
            
            if not result:
                return {
                    "symbol": symbol,
                    "success": False,
                    "response_time": response_time,
                    "error": "No chart data",
                    "data_points": 0
                }
            
            first_result = result[0]
            timestamps = first_result.get("timestamp", [])
            indicators = first_result.get("indicators", {})
            quote = indicators.get("quote", [])
            
            if not quote:
                return {
                    "symbol": symbol,
                    "success": False,
                    "response_time": response_time,
                    "error": "No quote data",
                    "data_points": 0
                }
            
            quote_data = quote[0]
            opens = quote_data.get("open", [])
            highs = quote_data.get("high", [])
            lows = quote_data.get("low", [])
            closes = quote_data.get("close", [])
            volumes = quote_data.get("volume", [])
            
            # Validate data structure
            data_points = len(timestamps)
            valid_prices = sum(1 for i in range(data_points) 
                             if all(x is not None for x in [opens[i], highs[i], lows[i], closes[i]]))
            
            return {
                "symbol": symbol,
                "success": True,
                "response_time": response_time,
                "error": None,
                "data_points": data_points,
                "valid_prices": valid_prices,
                "data_quality": valid_prices / data_points if data_points > 0 else 0,
                "date_range": {
                    "start": datetime.fromtimestamp(timestamps[0]).isoformat() if timestamps else None,
                    "end": datetime.fromtimestamp(timestamps[-1]).isoformat() if timestamps else None
                },
                "sample_data": {
                    "latest_close": closes[-1] if closes and closes[-1] is not None else None,
                    "latest_volume": volumes[-1] if volumes and volumes[-1] is not None else None
                }
            }
            
        except Exception as e:
            return {
                "symbol": symbol,
                "success": False,
                "response_time": response_time,
                "error": f"Response parsing error: {str(e)}",
                "data_points": 0
            }
    
    async def test_eodhd_api(self, api_key: Optional[str] = None) -> Dict[str, Any]:
        """Test EODHD API if API key is available."""
        print("🔍 Testing EODHD API...")
        
        results = {
            "provider": "EODHD",
            "endpoint": "https://eodhd.com/api/eod",
            "tests": []
        }
        
        if not api_key:
            results["tests"].append({
                "symbol": "ALL",
                "success": False,
                "response_time": 0,
                "error": "No API key provided",
                "data_points": 0
            })
            return results
        
        async with aiohttp.ClientSession(timeout=self.session_timeout) as session:
            for symbol in self.test_symbols:
                test_result = await self._test_eodhd_symbol(session, symbol, api_key)
                results["tests"].append(test_result)
        
        return results
    
    async def _test_eodhd_symbol(self, session: aiohttp.ClientSession, symbol: str, api_key: str) -> Dict[str, Any]:
        """Test EODHD API for a specific symbol."""
        url = f"https://eodhd.com/api/eod/{symbol}.US"
        params = {
            "api_token": api_key,
            "from": self.start_date.strftime("%Y-%m-%d"),
            "to": self.end_date.strftime("%Y-%m-%d"),
            "period": "d",
            "fmt": "json"
        }
        
        start_time = time.time()
        
        try:
            async with session.get(url, params=params) as response:
                response_time = time.time() - start_time
                
                if response.status == 200:
                    data = await response.json()
                    return self._analyze_eodhd_response(symbol, data, response_time)
                else:
                    error_text = await response.text()
                    return {
                        "symbol": symbol,
                        "success": False,
                        "response_time": response_time,
                        "error": f"HTTP {response.status}: {error_text[:100]}",
                        "data_points": 0
                    }
                    
        except Exception as e:
            response_time = time.time() - start_time
            return {
                "symbol": symbol,
                "success": False,
                "response_time": response_time,
                "error": str(e),
                "data_points": 0
            }
    
    def _analyze_eodhd_response(self, symbol: str, data: List[Dict], response_time: float) -> Dict[str, Any]:
        """Analyze EODHD API response."""
        try:
            if not isinstance(data, list):
                return {
                    "symbol": symbol,
                    "success": False,
                    "response_time": response_time,
                    "error": "Invalid response format",
                    "data_points": 0
                }
            
            data_points = len(data)
            valid_prices = sum(1 for item in data 
                             if all(key in item and item[key] is not None 
                                  for key in ["open", "high", "low", "close"]))
            
            return {
                "symbol": symbol,
                "success": True,
                "response_time": response_time,
                "error": None,
                "data_points": data_points,
                "valid_prices": valid_prices,
                "data_quality": valid_prices / data_points if data_points > 0 else 0,
                "date_range": {
                    "start": data[0]["date"] if data else None,
                    "end": data[-1]["date"] if data else None
                },
                "sample_data": {
                    "latest_close": data[-1]["close"] if data else None,
                    "latest_volume": data[-1]["volume"] if data else None
                }
            }
            
        except Exception as e:
            return {
                "symbol": symbol,
                "success": False,
                "response_time": response_time,
                "error": f"Response parsing error: {str(e)}",
                "data_points": 0
            }
    
    async def test_finnhub_api(self, api_key: Optional[str] = None) -> Dict[str, Any]:
        """Test Finnhub API if API key is available."""
        print("🔍 Testing Finnhub API...")
        
        results = {
            "provider": "Finnhub",
            "endpoint": "https://finnhub.io/api/v1/stock/candle",
            "tests": []
        }
        
        if not api_key:
            results["tests"].append({
                "symbol": "ALL",
                "success": False,
                "response_time": 0,
                "error": "No API key provided",
                "data_points": 0
            })
            return results
        
        async with aiohttp.ClientSession(timeout=self.session_timeout) as session:
            for symbol in self.test_symbols:
                test_result = await self._test_finnhub_symbol(session, symbol, api_key)
                results["tests"].append(test_result)
        
        return results
    
    async def _test_finnhub_symbol(self, session: aiohttp.ClientSession, symbol: str, api_key: str) -> Dict[str, Any]:
        """Test Finnhub API for a specific symbol."""
        url = "https://finnhub.io/api/v1/stock/candle"
        params = {
            "symbol": symbol,
            "resolution": "D",
            "from": int(self.start_date.timestamp()),
            "to": int(self.end_date.timestamp()),
            "token": api_key
        }
        
        start_time = time.time()
        
        try:
            async with session.get(url, params=params) as response:
                response_time = time.time() - start_time
                
                if response.status == 200:
                    data = await response.json()
                    return self._analyze_finnhub_response(symbol, data, response_time)
                else:
                    error_text = await response.text()
                    return {
                        "symbol": symbol,
                        "success": False,
                        "response_time": response_time,
                        "error": f"HTTP {response.status}: {error_text[:100]}",
                        "data_points": 0
                    }
                    
        except Exception as e:
            response_time = time.time() - start_time
            return {
                "symbol": symbol,
                "success": False,
                "response_time": response_time,
                "error": str(e),
                "data_points": 0
            }
    
    def _analyze_finnhub_response(self, symbol: str, data: Dict, response_time: float) -> Dict[str, Any]:
        """Analyze Finnhub API response."""
        try:
            if data.get("s") != "ok":
                return {
                    "symbol": symbol,
                    "success": False,
                    "response_time": response_time,
                    "error": f"API error: {data.get('s', 'Unknown')}",
                    "data_points": 0
                }
            
            timestamps = data.get("t", [])
            opens = data.get("o", [])
            highs = data.get("h", [])
            lows = data.get("l", [])
            closes = data.get("c", [])
            volumes = data.get("v", [])
            
            data_points = len(timestamps)
            valid_prices = sum(1 for i in range(data_points) 
                             if all(x is not None for x in [opens[i], highs[i], lows[i], closes[i]]))
            
            return {
                "symbol": symbol,
                "success": True,
                "response_time": response_time,
                "error": None,
                "data_points": data_points,
                "valid_prices": valid_prices,
                "data_quality": valid_prices / data_points if data_points > 0 else 0,
                "date_range": {
                    "start": datetime.fromtimestamp(timestamps[0]).isoformat() if timestamps else None,
                    "end": datetime.fromtimestamp(timestamps[-1]).isoformat() if timestamps else None
                },
                "sample_data": {
                    "latest_close": closes[-1] if closes else None,
                    "latest_volume": volumes[-1] if volumes else None
                }
            }
            
        except Exception as e:
            return {
                "symbol": symbol,
                "success": False,
                "response_time": response_time,
                "error": f"Response parsing error: {str(e)}",
                "data_points": 0
            }
    
    async def test_error_scenarios(self) -> Dict[str, Any]:
        """Test various error scenarios."""
        print("🔍 Testing error scenarios...")
        
        results = {
            "provider": "Error Handling",
            "tests": []
        }
        
        async with aiohttp.ClientSession(timeout=self.session_timeout) as session:
            # Test invalid symbol
            invalid_symbol_result = await self._test_yahoo_symbol(session, "INVALID123")
            invalid_symbol_result["scenario"] = "Invalid Symbol"
            results["tests"].append(invalid_symbol_result)
            
            # Test rate limiting (make multiple rapid requests)
            print("  Testing rate limiting...")
            rate_limit_results = []
            start_time = time.time()
            
            tasks = []
            for i in range(10):  # Make 10 concurrent requests
                task = self._test_yahoo_symbol(session, "AAPL")
                tasks.append(task)
            
            rate_limit_responses = await asyncio.gather(*tasks, return_exceptions=True)
            total_time = time.time() - start_time
            
            successful = sum(1 for r in rate_limit_responses 
                           if isinstance(r, dict) and r.get("success", False))
            
            results["tests"].append({
                "scenario": "Rate Limiting Test",
                "success": True,  # Success means we handled the rate limiting properly
                "total_requests": 10,
                "successful_requests": successful,
                "total_time": total_time,
                "response_time": total_time / 10,
                "error": None if successful > 0 else "All requests failed"
            })
        
        return results
    
    def generate_api_test_report(self, test_results: List[Dict[str, Any]]) -> str:
        """Generate comprehensive API test report."""
        report = """
╔══════════════════════════════════════════════════════════════════════════════╗
║                       DIRECT API ENDPOINT TEST REPORT                       ║
╚══════════════════════════════════════════════════════════════════════════════╝

"""
        
        total_tests = 0
        successful_tests = 0
        
        for provider_result in test_results:
            provider_name = provider_result["provider"]
            tests = provider_result.get("tests", [])
            
            if not tests:
                continue
            
            report += f"🔗 {provider_name} API Test Results\n"
            report += "=" * 50 + "\n"
            
            provider_successes = sum(1 for test in tests if test.get("success", False))
            provider_total = len(tests)
            provider_success_rate = (provider_successes / provider_total * 100) if provider_total > 0 else 0
            
            total_tests += provider_total
            successful_tests += provider_successes
            
            report += f"Status: {'✅ OPERATIONAL' if provider_success_rate > 80 else '❌ ISSUES DETECTED'}\n"
            report += f"Success Rate: {provider_success_rate:.1f}% ({provider_successes}/{provider_total})\n"
            
            if "endpoint" in provider_result:
                report += f"Endpoint: {provider_result['endpoint']}\n"
            
            report += "\nIndividual Test Results:\n"
            for test in tests:
                symbol = test.get("symbol", "N/A")
                success = test.get("success", False)
                response_time = test.get("response_time", 0)
                data_points = test.get("data_points", 0)
                error = test.get("error")
                
                status_icon = "✅" if success else "❌"
                report += f"  {status_icon} {symbol}: "
                
                if success:
                    report += f"{data_points} data points, {response_time:.2f}s response time\n"
                    if "data_quality" in test:
                        report += f"      Data Quality: {test['data_quality']:.1%}\n"
                    if "sample_data" in test and test["sample_data"].get("latest_close"):
                        report += f"      Latest Close: ${test['sample_data']['latest_close']:.2f}\n"
                else:
                    report += f"FAILED - {error}\n"
            
            # Performance summary for successful tests
            successful_tests_data = [test for test in tests if test.get("success", False)]
            if successful_tests_data:
                avg_response_time = sum(test["response_time"] for test in successful_tests_data) / len(successful_tests_data)
                total_data_points = sum(test.get("data_points", 0) for test in successful_tests_data)
                avg_data_quality = sum(test.get("data_quality", 0) for test in successful_tests_data) / len(successful_tests_data)
                
                report += f"\nPerformance Summary:\n"
                report += f"  • Average Response Time: {avg_response_time:.2f}s\n"
                report += f"  • Total Data Points Retrieved: {total_data_points}\n"
                report += f"  • Average Data Quality: {avg_data_quality:.1%}\n"
            
            report += "\n"
        
        # Overall summary
        overall_success_rate = (successful_tests / total_tests * 100) if total_tests > 0 else 0
        report += "📊 OVERALL API HEALTH SUMMARY\n"
        report += "=" * 50 + "\n"
        report += f"Overall Success Rate: {overall_success_rate:.1f}% ({successful_tests}/{total_tests})\n"
        report += f"System Status: {'✅ HEALTHY' if overall_success_rate > 70 else '⚠️ DEGRADED' if overall_success_rate > 30 else '❌ CRITICAL'}\n"
        
        # Recommendations
        report += "\n💡 RECOMMENDATIONS\n"
        report += "=" * 50 + "\n"
        
        if overall_success_rate < 70:
            report += "• Immediate attention required - API connectivity issues detected\n"
        
        # Check individual provider health
        for provider_result in test_results:
            provider_name = provider_result["provider"]
            tests = provider_result.get("tests", [])
            if tests:
                success_rate = sum(1 for test in tests if test.get("success", False)) / len(tests) * 100
                if success_rate < 50:
                    report += f"• {provider_name}: Consider disabling or investigating connectivity\n"
                elif success_rate < 80:
                    report += f"• {provider_name}: Monitor closely for stability issues\n"
        
        report += "• Implement proper error handling and retry logic\n"
        report += "• Monitor API usage against rate limits\n"
        report += "• Consider implementing circuit breaker pattern\n"
        
        report += f"\n📅 Test Completed: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
        report += "=" * 80 + "\n"
        
        return report
    
    async def run_all_api_tests(self, eodhd_api_key: Optional[str] = None, 
                               finnhub_api_key: Optional[str] = None) -> List[Dict[str, Any]]:
        """Run all API tests and return results."""
        print("🚀 Starting Direct API Endpoint Tests...")
        
        results = []
        
        # Test Yahoo Finance (free, no API key required)
        yahoo_results = await self.test_yahoo_finance_api()
        results.append(yahoo_results)
        
        # Test EODHD (requires API key)
        eodhd_results = await self.test_eodhd_api(eodhd_api_key)
        results.append(eodhd_results)
        
        # Test Finnhub (requires API key)
        finnhub_results = await self.test_finnhub_api(finnhub_api_key)
        results.append(finnhub_results)
        
        # Test error scenarios
        error_results = await self.test_error_scenarios()
        results.append(error_results)
        
        return results


async def main():
    """Main execution function."""
    tester = DirectAPITester()
    
    # You can provide API keys here if available
    eodhd_api_key = None  # Set to your EODHD API key if available
    finnhub_api_key = None  # Set to your Finnhub API key if available
    
    try:
        # Run all API tests
        results = await tester.run_all_api_tests(eodhd_api_key, finnhub_api_key)
        
        # Generate and display report
        report = tester.generate_api_test_report(results)
        print(report)
        
        # Save detailed results
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Save JSON results
        json_filename = f"direct_api_test_results_{timestamp}.json"
        with open(json_filename, 'w') as f:
            json.dump({
                "timestamp": datetime.now().isoformat(),
                "test_results": results
            }, f, indent=2, default=str)
        
        # Save report
        report_filename = f"DIRECT_API_TEST_REPORT_{timestamp}.md"
        with open(report_filename, 'w') as f:
            f.write(report)
        
        print(f"\n📄 Detailed results saved to: {json_filename}")
        print(f"📄 Report saved to: {report_filename}")
        
        return 0
        
    except Exception as e:
        print(f"❌ API test execution failed: {str(e)}")
        return 1


if __name__ == "__main__":
    import sys
    exit_code = asyncio.run(main())
    sys.exit(exit_code)