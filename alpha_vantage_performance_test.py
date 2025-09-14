#!/usr/bin/env python3
"""
Alpha Vantage Performance and Load Testing Suite
Tests performance characteristics, error handling, and rate limiting behavior.
"""

import asyncio
import aiohttp
import time
import statistics
from datetime import datetime, timedelta
from typing import List, Dict, Tuple
import json

class AlphaVantagePerformanceTester:
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.base_url = "https://www.alphavantage.co/query"
        self.results = []
        
    async def single_request_test(self, session: aiohttp.ClientSession, symbol: str, function: str = "GLOBAL_QUOTE") -> Dict:
        """Test a single API request and measure performance"""
        url = f"{self.base_url}?function={function}&symbol={symbol}&apikey={self.api_key}"
        
        start_time = time.time()
        try:
            async with session.get(url, timeout=30) as response:
                end_time = time.time()
                response_time = (end_time - start_time) * 1000  # Convert to ms
                
                data = await response.json()
                
                return {
                    "symbol": symbol,
                    "function": function,
                    "status_code": response.status,
                    "response_time_ms": round(response_time, 2),
                    "success": response.status == 200 and bool(data.get("Global Quote", {})),
                    "data_size": len(str(data)),
                    "timestamp": datetime.now().isoformat()
                }
                
        except asyncio.TimeoutError:
            return {
                "symbol": symbol,
                "function": function,
                "status_code": None,
                "response_time_ms": 30000,  # Timeout
                "success": False,
                "error": "Timeout",
                "timestamp": datetime.now().isoformat()
            }
        except Exception as e:
            return {
                "symbol": symbol,
                "function": function,
                "status_code": None,
                "response_time_ms": None,
                "success": False,
                "error": str(e),
                "timestamp": datetime.now().isoformat()
            }
    
    async def response_time_test(self, symbols: List[str], iterations: int = 3) -> Dict:
        """Test response time consistency across multiple requests"""
        print(f"\n🏃‍♂️ Response Time Consistency Test")
        print(f"Testing {len(symbols)} symbols × {iterations} iterations")
        print("-" * 50)
        
        all_results = []
        
        async with aiohttp.ClientSession() as session:
            for iteration in range(iterations):
                print(f"Iteration {iteration + 1}/{iterations}")
                
                for symbol in symbols:
                    result = await self.single_request_test(session, symbol)
                    all_results.append(result)
                    
                    if result["success"]:
                        print(f"  {symbol}: {result['response_time_ms']}ms ✅")
                    else:
                        print(f"  {symbol}: FAILED ❌")
                    
                    # Rate limiting delay
                    await asyncio.sleep(12)
                
                print(f"Completed iteration {iteration + 1}")
        
        # Calculate statistics
        successful_results = [r for r in all_results if r["success"]]
        response_times = [r["response_time_ms"] for r in successful_results]
        
        if response_times:
            stats = {
                "avg_response_time_ms": round(statistics.mean(response_times), 2),
                "median_response_time_ms": round(statistics.median(response_times), 2),
                "min_response_time_ms": min(response_times),
                "max_response_time_ms": max(response_times),
                "std_dev_ms": round(statistics.stdev(response_times) if len(response_times) > 1 else 0, 2),
                "success_rate": round((len(successful_results) / len(all_results)) * 100, 1),
                "total_requests": len(all_results),
                "successful_requests": len(successful_results)
            }
        else:
            stats = {
                "avg_response_time_ms": None,
                "median_response_time_ms": None,
                "min_response_time_ms": None,
                "max_response_time_ms": None,
                "std_dev_ms": None,
                "success_rate": 0,
                "total_requests": len(all_results),
                "successful_requests": 0
            }
        
        return {
            "test_type": "response_time_consistency",
            "symbols_tested": symbols,
            "iterations": iterations,
            "statistics": stats,
            "raw_results": all_results
        }
    
    async def error_handling_test(self) -> Dict:
        """Test error handling with various invalid inputs"""
        print(f"\n🚨 Error Handling Test")
        print("-" * 50)
        
        test_cases = [
            {"symbol": "INVALID123", "expected": "invalid_symbol"},
            {"symbol": "AAPL", "function": "INVALID_FUNCTION", "expected": "invalid_function"},
            {"symbol": "", "expected": "empty_symbol"},
            {"symbol": "VERYLONGINVALIDSYMBOLNAME", "expected": "invalid_symbol"},
        ]
        
        results = []
        
        async with aiohttp.ClientSession() as session:
            for i, test_case in enumerate(test_cases):
                print(f"Test case {i+1}: {test_case}")
                
                function = test_case.get("function", "GLOBAL_QUOTE")
                result = await self.single_request_test(session, test_case["symbol"], function)
                result["expected_error"] = test_case["expected"]
                result["test_case"] = test_case
                
                results.append(result)
                
                if not result["success"]:
                    print(f"  ✅ Error handled correctly")
                else:
                    print(f"  ⚠️  Expected error but got success")
                
                await asyncio.sleep(12)  # Rate limiting
        
        return {
            "test_type": "error_handling",
            "test_cases": len(test_cases),
            "results": results
        }
    
    async def rate_limiting_test(self, max_requests: int = 10) -> Dict:
        """Test rate limiting behavior"""
        print(f"\n⏱️ Rate Limiting Test")
        print(f"Testing with {max_requests} rapid requests")
        print("-" * 50)
        
        results = []
        
        async with aiohttp.ClientSession() as session:
            start_time = time.time()
            
            for i in range(max_requests):
                print(f"Request {i+1}/{max_requests}")
                
                result = await self.single_request_test(session, "AAPL")
                result["request_number"] = i + 1
                result["time_since_start"] = round((time.time() - start_time), 2)
                
                results.append(result)
                
                if result["success"]:
                    print(f"  ✅ Success ({result['response_time_ms']}ms)")
                else:
                    print(f"  ❌ Failed: {result.get('error', 'Unknown error')}")
                
                # Minimal delay to test rate limiting
                await asyncio.sleep(2)
        
        # Analyze results
        success_count = sum(1 for r in results if r["success"])
        failure_count = len(results) - success_count
        
        return {
            "test_type": "rate_limiting",
            "total_requests": max_requests,
            "successful_requests": success_count,
            "failed_requests": failure_count,
            "success_rate": round((success_count / max_requests) * 100, 1),
            "test_duration_seconds": round(time.time() - start_time, 2),
            "results": results
        }
    
    async def data_accuracy_test(self) -> Dict:
        """Test data accuracy and format validation"""
        print(f"\n📊 Data Accuracy Test")
        print("-" * 50)
        
        test_symbols = ["AAPL", "MSFT", "SPY"]
        results = []
        
        async with aiohttp.ClientSession() as session:
            for symbol in test_symbols:
                print(f"Testing {symbol} data accuracy...")
                
                # Test quote data
                quote_result = await self.single_request_test(session, symbol, "GLOBAL_QUOTE")
                
                if quote_result["success"]:
                    # Make another request to get detailed data for analysis
                    url = f"{self.base_url}?function=GLOBAL_QUOTE&symbol={symbol}&apikey={self.api_key}"
                    async with session.get(url) as response:
                        data = await response.json()
                        global_quote = data.get("Global Quote", {})
                        
                        validation = {
                            "symbol": symbol,
                            "has_symbol": bool(global_quote.get("01. symbol")),
                            "has_price": bool(global_quote.get("05. price")),
                            "has_volume": bool(global_quote.get("06. volume")),
                            "has_change": bool(global_quote.get("09. change")),
                            "price_is_numeric": self._is_numeric(global_quote.get("05. price")),
                            "volume_is_numeric": self._is_numeric(global_quote.get("06. volume")),
                            "change_is_numeric": self._is_numeric(global_quote.get("09. change")),
                            "has_trading_day": bool(global_quote.get("07. latest trading day")),
                            "raw_data": global_quote
                        }
                        
                        validation["data_completeness_score"] = sum([
                            validation["has_symbol"],
                            validation["has_price"], 
                            validation["has_volume"],
                            validation["has_change"],
                            validation["price_is_numeric"],
                            validation["volume_is_numeric"],
                            validation["change_is_numeric"],
                            validation["has_trading_day"]
                        ]) / 8 * 100
                        
                        results.append(validation)
                        print(f"  Data completeness: {validation['data_completeness_score']:.1f}%")
                
                await asyncio.sleep(12)  # Rate limiting
        
        overall_completeness = sum(r["data_completeness_score"] for r in results) / len(results) if results else 0
        
        return {
            "test_type": "data_accuracy",
            "symbols_tested": test_symbols,
            "overall_completeness_score": round(overall_completeness, 1),
            "results": results
        }
    
    def _is_numeric(self, value: str) -> bool:
        """Helper to check if a string value is numeric"""
        if not value:
            return False
        try:
            float(value)
            return True
        except (ValueError, TypeError):
            return False
    
    async def run_comprehensive_performance_test(self) -> Dict:
        """Run all performance tests"""
        print("🔥 ALPHA VANTAGE PERFORMANCE TEST SUITE")
        print("=" * 60)
        print(f"Start time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        test_results = {
            "test_suite": "alpha_vantage_performance",
            "start_time": datetime.now().isoformat(),
            "api_key": f"{self.api_key[:8]}...",
            "results": {}
        }
        
        # Test 1: Response time consistency
        test_results["results"]["response_time"] = await self.response_time_test(
            symbols=["AAPL", "MSFT", "SPY"], 
            iterations=2
        )
        
        # Test 2: Error handling  
        test_results["results"]["error_handling"] = await self.error_handling_test()
        
        # Test 3: Rate limiting behavior
        test_results["results"]["rate_limiting"] = await self.rate_limiting_test(max_requests=5)
        
        # Test 4: Data accuracy
        test_results["results"]["data_accuracy"] = await self.data_accuracy_test()
        
        test_results["end_time"] = datetime.now().isoformat()
        test_results["total_duration"] = str(datetime.fromisoformat(test_results["end_time"]) - 
                                           datetime.fromisoformat(test_results["start_time"]))
        
        return test_results

def print_performance_summary(results: Dict):
    """Print a formatted summary of performance test results"""
    print("\n" + "=" * 60)
    print("📈 PERFORMANCE TEST SUMMARY")
    print("=" * 60)
    
    # Response time stats
    if "response_time" in results["results"]:
        rt_stats = results["results"]["response_time"]["statistics"]
        print(f"\n🏃‍♂️ Response Time Performance:")
        print(f"  Average: {rt_stats['avg_response_time_ms']}ms")
        print(f"  Median: {rt_stats['median_response_time_ms']}ms")
        print(f"  Range: {rt_stats['min_response_time_ms']}ms - {rt_stats['max_response_time_ms']}ms")
        print(f"  Standard Deviation: {rt_stats['std_dev_ms']}ms")
        print(f"  Success Rate: {rt_stats['success_rate']}%")
    
    # Error handling
    if "error_handling" in results["results"]:
        eh_results = results["results"]["error_handling"]["results"]
        handled_correctly = sum(1 for r in eh_results if not r["success"])
        print(f"\n🚨 Error Handling:")
        print(f"  Test Cases: {len(eh_results)}")
        print(f"  Errors Handled Correctly: {handled_correctly}/{len(eh_results)}")
        print(f"  Error Handling Score: {(handled_correctly/len(eh_results))*100:.1f}%")
    
    # Rate limiting
    if "rate_limiting" in results["results"]:
        rl_results = results["results"]["rate_limiting"]
        print(f"\n⏱️ Rate Limiting:")
        print(f"  Total Requests: {rl_results['total_requests']}")
        print(f"  Successful: {rl_results['successful_requests']}")
        print(f"  Failed: {rl_results['failed_requests']}")
        print(f"  Success Rate: {rl_results['success_rate']}%")
        print(f"  Test Duration: {rl_results['test_duration_seconds']}s")
    
    # Data accuracy
    if "data_accuracy" in results["results"]:
        da_results = results["results"]["data_accuracy"]
        print(f"\n📊 Data Accuracy:")
        print(f"  Overall Completeness: {da_results['overall_completeness_score']}%")
        print(f"  Symbols Tested: {len(da_results['results'])}")
    
    # Overall assessment
    print(f"\n🎯 Overall Assessment:")
    
    # Calculate overall score
    scores = []
    if "response_time" in results["results"]:
        scores.append(results["results"]["response_time"]["statistics"]["success_rate"])
    if "error_handling" in results["results"]:
        eh_results = results["results"]["error_handling"]["results"]
        handled_correctly = sum(1 for r in eh_results if not r["success"])
        scores.append((handled_correctly/len(eh_results))*100)
    if "data_accuracy" in results["results"]:
        scores.append(results["results"]["data_accuracy"]["overall_completeness_score"])
    
    overall_score = sum(scores) / len(scores) if scores else 0
    
    print(f"  Overall Performance Score: {overall_score:.1f}%")
    
    if overall_score >= 90:
        print("  ✅ EXCELLENT - Ready for production use")
    elif overall_score >= 80:
        print("  ✅ GOOD - Suitable for production with monitoring")
    elif overall_score >= 70:
        print("  ⚠️  ACCEPTABLE - Use with caution, monitor closely")
    else:
        print("  ❌ POOR - Not recommended for production")

async def main():
    API_KEY = "QCYXJ1BYPYXG8BUY"
    
    tester = AlphaVantagePerformanceTester(API_KEY)
    results = await tester.run_comprehensive_performance_test()
    
    # Save detailed results
    output_file = f"alpha_vantage_performance_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2)
    
    print_performance_summary(results)
    print(f"\nDetailed results saved to: {output_file}")

if __name__ == "__main__":
    asyncio.run(main())