#!/usr/bin/env python3
"""
Nasdaq API Load Test
Tests performance under various load conditions
"""

import requests
import asyncio
import aiohttp
import time
import statistics
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Dict
import json

class NasdaqLoadTester:
    def __init__(self):
        self.base_url = "https://api.nasdaq.com/api/quote"
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            "Accept": "application/json"
        }
        
    def fetch_stock_quote_sync(self, symbol: str) -> Dict:
        """Synchronous stock quote fetch for threading tests"""
        start_time = time.time()
        try:
            url = f"{self.base_url}/{symbol}/info?assetclass=stocks"
            response = requests.get(url, headers=self.headers, timeout=10)
            response_time = time.time() - start_time
            
            if response.status_code == 200:
                data = response.json()
                if data.get("status", {}).get("rCode") == 200:
                    price_str = data.get("data", {}).get("primaryData", {}).get("lastSalePrice", "$0")
                    price = float(price_str.replace("$", "").replace(",", ""))
                    return {
                        "symbol": symbol,
                        "success": True,
                        "response_time": response_time,
                        "price": price
                    }
            
            return {
                "symbol": symbol,
                "success": False,
                "response_time": response_time,
                "error": f"HTTP {response.status_code}"
            }
            
        except Exception as e:
            response_time = time.time() - start_time
            return {
                "symbol": symbol,
                "success": False,
                "response_time": response_time,
                "error": str(e)
            }
    
    async def fetch_stock_quote_async(self, session: aiohttp.ClientSession, symbol: str) -> Dict:
        """Asynchronous stock quote fetch for async tests"""
        start_time = time.time()
        try:
            url = f"{self.base_url}/{symbol}/info?assetclass=stocks"
            async with session.get(url, headers=self.headers, timeout=10) as response:
                response_time = time.time() - start_time
                
                if response.status == 200:
                    data = await response.json()
                    if data.get("status", {}).get("rCode") == 200:
                        price_str = data.get("data", {}).get("primaryData", {}).get("lastSalePrice", "$0")
                        price = float(price_str.replace("$", "").replace(",", ""))
                        return {
                            "symbol": symbol,
                            "success": True,
                            "response_time": response_time,
                            "price": price
                        }
                
                return {
                    "symbol": symbol,
                    "success": False,
                    "response_time": response_time,
                    "error": f"HTTP {response.status}"
                }
                
        except Exception as e:
            response_time = time.time() - start_time
            return {
                "symbol": symbol,
                "success": False,
                "response_time": response_time,
                "error": str(e)
            }
    
    def run_concurrent_test(self, symbols: List[str], max_workers: int) -> Dict:
        """Run concurrent requests using ThreadPoolExecutor"""
        print(f"  Running concurrent test with {max_workers} workers...")
        
        start_time = time.time()
        results = []
        
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            # Submit all requests
            future_to_symbol = {
                executor.submit(self.fetch_stock_quote_sync, symbol): symbol 
                for symbol in symbols
            }
            
            # Collect results
            for future in as_completed(future_to_symbol):
                results.append(future.result())
        
        total_time = time.time() - start_time
        
        successful = [r for r in results if r["success"]]
        failed = [r for r in results if not r["success"]]
        
        return {
            "total_time": total_time,
            "total_requests": len(results),
            "successful_requests": len(successful),
            "failed_requests": len(failed),
            "success_rate": len(successful) / len(results) * 100,
            "requests_per_second": len(results) / total_time,
            "avg_response_time": statistics.mean([r["response_time"] for r in successful]) if successful else 0,
            "p95_response_time": statistics.quantiles([r["response_time"] for r in successful], n=20)[18] if len(successful) > 20 else 0,
            "max_response_time": max([r["response_time"] for r in successful]) if successful else 0,
            "results": results
        }
    
    async def run_async_test(self, symbols: List[str], concurrent_limit: int) -> Dict:
        """Run asynchronous requests with concurrency limit"""
        print(f"  Running async test with {concurrent_limit} concurrent requests...")
        
        connector = aiohttp.TCPConnector(limit=concurrent_limit)
        timeout = aiohttp.ClientTimeout(total=10)
        
        start_time = time.time()
        results = []
        
        async with aiohttp.ClientSession(connector=connector, timeout=timeout) as session:
            semaphore = asyncio.Semaphore(concurrent_limit)
            
            async def fetch_with_semaphore(symbol):
                async with semaphore:
                    return await self.fetch_stock_quote_async(session, symbol)
            
            tasks = [fetch_with_semaphore(symbol) for symbol in symbols]
            results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Filter out exceptions
        valid_results = [r for r in results if isinstance(r, dict)]
        total_time = time.time() - start_time
        
        successful = [r for r in valid_results if r["success"]]
        failed = [r for r in valid_results if not r["success"]]
        
        return {
            "total_time": total_time,
            "total_requests": len(valid_results),
            "successful_requests": len(successful),
            "failed_requests": len(failed),
            "success_rate": len(successful) / len(valid_results) * 100 if valid_results else 0,
            "requests_per_second": len(valid_results) / total_time if total_time > 0 else 0,
            "avg_response_time": statistics.mean([r["response_time"] for r in successful]) if successful else 0,
            "p95_response_time": statistics.quantiles([r["response_time"] for r in successful], n=20)[18] if len(successful) > 20 else 0,
            "max_response_time": max([r["response_time"] for r in successful]) if successful else 0,
            "results": valid_results
        }

def run_load_tests():
    """Run comprehensive load tests"""
    
    # Test with popular stocks
    test_symbols = [
        "AAPL", "MSFT", "GOOGL", "AMZN", "META",
        "TSLA", "NVDA", "NFLX", "AMD", "CRM",
        "WMT", "JPM", "BAC", "XOM", "CVX",
        "JNJ", "PG", "KO", "PFE", "VZ"
    ] * 2  # 40 total requests
    
    tester = NasdaqLoadTester()
    
    print("🚀 Starting Nasdaq API Load Tests")
    print("=" * 50)
    
    test_configs = [
        {"workers": 1, "name": "Sequential (1 worker)"},
        {"workers": 5, "name": "Low Concurrency (5 workers)"},
        {"workers": 10, "name": "Medium Concurrency (10 workers)"},
        {"workers": 20, "name": "High Concurrency (20 workers)"},
    ]
    
    results = {}
    
    # Threading tests
    print("\n🧵 Threading-based Load Tests")
    print("-" * 30)
    
    for config in test_configs:
        print(f"\n📊 {config['name']}")
        result = tester.run_concurrent_test(test_symbols, config["workers"])
        results[f"threading_{config['workers']}"] = result
        
        print(f"  Total time: {result['total_time']:.2f}s")
        print(f"  Success rate: {result['success_rate']:.1f}%")
        print(f"  Requests/sec: {result['requests_per_second']:.1f}")
        print(f"  Avg response: {result['avg_response_time']:.3f}s")
        print(f"  P95 response: {result['p95_response_time']:.3f}s")
        print(f"  Max response: {result['max_response_time']:.3f}s")
        
        # Brief pause between tests
        time.sleep(2)
    
    # Async tests
    print("\n🔄 Async-based Load Tests")
    print("-" * 30)
    
    async_configs = [
        {"limit": 5, "name": "Low Async (5 concurrent)"},
        {"limit": 10, "name": "Medium Async (10 concurrent)"},
        {"limit": 15, "name": "High Async (15 concurrent)"},
    ]
    
    for config in async_configs:
        print(f"\n📊 {config['name']}")
        result = asyncio.run(tester.run_async_test(test_symbols, config["limit"]))
        results[f"async_{config['limit']}"] = result
        
        print(f"  Total time: {result['total_time']:.2f}s")
        print(f"  Success rate: {result['success_rate']:.1f}%")
        print(f"  Requests/sec: {result['requests_per_second']:.1f}")
        print(f"  Avg response: {result['avg_response_time']:.3f}s")
        print(f"  P95 response: {result['p95_response_time']:.3f}s")
        print(f"  Max response: {result['max_response_time']:.3f}s")
        
        # Brief pause between tests
        time.sleep(2)
    
    # Performance Analysis
    print("\n📈 Performance Analysis")
    print("=" * 50)
    
    # Find best performing configuration
    best_rps = 0
    best_config = None
    
    for config_name, result in results.items():
        if result["requests_per_second"] > best_rps and result["success_rate"] > 90:
            best_rps = result["requests_per_second"]
            best_config = config_name
    
    if best_config:
        print(f"🏆 Best performing configuration: {best_config}")
        best_result = results[best_config]
        print(f"  Requests/sec: {best_result['requests_per_second']:.1f}")
        print(f"  Success rate: {best_result['success_rate']:.1f}%")
        print(f"  Avg response: {best_result['avg_response_time']:.3f}s")
    
    # Rate limiting analysis
    print("\n⚠️  Rate Limiting Analysis")
    print("-" * 30)
    
    for config_name, result in results.items():
        failed_requests = result["failed_requests"]
        if failed_requests > 0:
            error_types = {}
            for r in result["results"]:
                if not r["success"]:
                    error = r.get("error", "Unknown")
                    error_types[error] = error_types.get(error, 0) + 1
            
            print(f"{config_name}: {failed_requests} failures")
            for error, count in error_types.items():
                print(f"  {error}: {count}")
    
    # Save detailed results
    with open("/Users/hnigel/coding/my asset/nasdaq_load_test_report.json", "w") as f:
        json.dump(results, f, indent=2)
    
    print(f"\n📋 Detailed results saved to nasdaq_load_test_report.json")
    
    # Recommendations
    print("\n💡 Recommendations")
    print("=" * 50)
    
    # Analyze results to provide recommendations
    high_concurrency_results = [r for name, r in results.items() if "20" in name or "15" in name]
    
    if any(r["success_rate"] < 95 for r in high_concurrency_results):
        print("⚠️  High concurrency shows reduced reliability")
        print("   Recommendation: Limit to 10 concurrent requests maximum")
    
    avg_response_times = [r["avg_response_time"] for r in results.values() if r["success_rate"] > 90]
    if avg_response_times and statistics.mean(avg_response_times) > 0.5:
        print("⚠️  High response times detected")
        print("   Recommendation: Implement request timeout of 5s minimum")
    
    best_rps_values = [r["requests_per_second"] for r in results.values() if r["success_rate"] > 95]
    if best_rps_values:
        recommended_rps = max(best_rps_values) * 0.8  # 80% of peak for safety margin
        print(f"✅ Recommended sustained request rate: {recommended_rps:.1f} requests/second")
    
    return results

if __name__ == "__main__":
    run_load_tests()