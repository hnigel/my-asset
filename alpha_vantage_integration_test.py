#!/usr/bin/env python3
"""
Alpha Vantage API Integration Test Suite
Tests the Alpha Vantage integration for stock quotes and dividend data.
"""

import asyncio
import aiohttp
import json
import time
from datetime import datetime
from typing import Dict, List, Optional

class AlphaVantageAPITester:
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.base_url = "https://www.alphavantage.co/query"
        self.request_count = 0
        self.max_requests = 25  # Daily limit for free tier
        self.rate_limit_delay = 12  # Seconds between requests (5 per minute)
        
    async def test_global_quote(self, session: aiohttp.ClientSession, symbol: str) -> Dict:
        """Test Alpha Vantage Global Quote endpoint"""
        url = f"{self.base_url}?function=GLOBAL_QUOTE&symbol={symbol}&apikey={self.api_key}"
        
        try:
            start_time = time.time()
            async with session.get(url, timeout=30) as response:
                response_time = time.time() - start_time
                
                if response.status == 200:
                    data = await response.json()
                    
                    # Check for valid response structure
                    if "Global Quote" in data and data["Global Quote"]:
                        global_quote = data["Global Quote"]
                        price = global_quote.get("05. price")
                        
                        return {
                            "success": True,
                            "symbol": symbol,
                            "price": float(price) if price else None,
                            "volume": global_quote.get("06. volume"),
                            "change": global_quote.get("09. change"),
                            "change_percent": global_quote.get("10. change percent"),
                            "response_time_ms": round(response_time * 1000, 2),
                            "raw_data": data
                        }
                    else:
                        return {
                            "success": False,
                            "symbol": symbol,
                            "error": "Empty or invalid Global Quote response",
                            "response_time_ms": round(response_time * 1000, 2),
                            "raw_data": data
                        }
                else:
                    return {
                        "success": False,
                        "symbol": symbol,
                        "error": f"HTTP {response.status}",
                        "response_time_ms": round(response_time * 1000, 2)
                    }
                    
        except asyncio.TimeoutError:
            return {
                "success": False,
                "symbol": symbol,
                "error": "Request timeout (30s)",
                "response_time_ms": 30000
            }
        except Exception as e:
            return {
                "success": False,
                "symbol": symbol,
                "error": f"Exception: {str(e)}",
                "response_time_ms": None
            }
    
    async def test_dividends(self, session: aiohttp.ClientSession, symbol: str) -> Dict:
        """Test Alpha Vantage Dividends endpoint"""
        url = f"{self.base_url}?function=DIVIDENDS&symbol={symbol}&apikey={self.api_key}"
        
        try:
            start_time = time.time()
            async with session.get(url, timeout=30) as response:
                response_time = time.time() - start_time
                
                if response.status == 200:
                    data = await response.json()
                    
                    # Check for dividends data
                    if "data" in data and isinstance(data["data"], list):
                        dividends = data["data"]
                        
                        if dividends:
                            # Get most recent dividend
                            recent_dividend = dividends[0]
                            return {
                                "success": True,
                                "symbol": symbol,
                                "dividend_count": len(dividends),
                                "most_recent_dividend": {
                                    "ex_date": recent_dividend.get("ex_dividend_date"),
                                    "amount": float(recent_dividend.get("dividend_amount", 0)),
                                    "payment_date": recent_dividend.get("payment_date")
                                },
                                "response_time_ms": round(response_time * 1000, 2),
                                "raw_sample": dividends[:3]  # First 3 for inspection
                            }
                        else:
                            return {
                                "success": True,
                                "symbol": symbol,
                                "dividend_count": 0,
                                "message": "No dividend data available",
                                "response_time_ms": round(response_time * 1000, 2)
                            }
                    else:
                        return {
                            "success": False,
                            "symbol": symbol,
                            "error": "Invalid dividends response structure",
                            "response_time_ms": round(response_time * 1000, 2),
                            "raw_data": data
                        }
                else:
                    return {
                        "success": False,
                        "symbol": symbol,
                        "error": f"HTTP {response.status}",
                        "response_time_ms": round(response_time * 1000, 2)
                    }
                    
        except asyncio.TimeoutError:
            return {
                "success": False,
                "symbol": symbol,
                "error": "Request timeout (30s)",
                "response_time_ms": 30000
            }
        except Exception as e:
            return {
                "success": False,
                "symbol": symbol,
                "error": f"Exception: {str(e)}",
                "response_time_ms": None
            }
    
    async def run_comprehensive_test(self, test_symbols: List[str]) -> Dict:
        """Run comprehensive Alpha Vantage API tests"""
        print(f"Starting Alpha Vantage API Test Suite")
        print(f"API Key: {self.api_key[:8]}...")
        print(f"Test Symbols: {test_symbols}")
        print(f"Rate Limit: {self.max_requests} requests per day")
        print("=" * 60)
        
        results = {
            "test_timestamp": datetime.now().isoformat(),
            "api_key": f"{self.api_key[:8]}...",
            "symbols_tested": test_symbols,
            "quote_tests": {},
            "dividend_tests": {},
            "performance_metrics": {},
            "rate_limiting": {},
            "overall_success_rate": 0.0
        }
        
        successful_tests = 0
        total_tests = 0
        response_times = []
        
        async with aiohttp.ClientSession() as session:
            
            # Test Global Quote endpoint
            print("\n📈 Testing Global Quote Endpoint")
            print("-" * 40)
            
            for symbol in test_symbols:
                print(f"Testing {symbol}...")
                
                # Rate limiting
                if self.request_count > 0:
                    print(f"   Waiting {self.rate_limit_delay}s for rate limit...")
                    await asyncio.sleep(self.rate_limit_delay)
                
                result = await self.test_global_quote(session, symbol)
                results["quote_tests"][symbol] = result
                
                if result["success"]:
                    successful_tests += 1
                    if result["response_time_ms"]:
                        response_times.append(result["response_time_ms"])
                    print(f"   ✅ Price: ${result['price']:.2f} ({result['response_time_ms']}ms)")
                else:
                    print(f"   ❌ Error: {result['error']}")
                
                total_tests += 1
                self.request_count += 1
                
                # Stop if we hit rate limit
                if self.request_count >= self.max_requests:
                    print(f"\n⚠️  Rate limit reached ({self.max_requests} requests)")
                    break
            
            # Test Dividends endpoint (if we haven't hit rate limit)
            if self.request_count < self.max_requests:
                print("\n💰 Testing Dividends Endpoint")
                print("-" * 40)
                
                # Test fewer symbols for dividends to conserve API calls
                dividend_test_symbols = test_symbols[:3]
                
                for symbol in dividend_test_symbols:
                    if self.request_count >= self.max_requests:
                        break
                        
                    print(f"Testing {symbol} dividends...")
                    
                    # Rate limiting
                    await asyncio.sleep(self.rate_limit_delay)
                    
                    result = await self.test_dividends(session, symbol)
                    results["dividend_tests"][symbol] = result
                    
                    if result["success"]:
                        successful_tests += 1
                        if result["response_time_ms"]:
                            response_times.append(result["response_time_ms"])
                        if "dividend_count" in result:
                            print(f"   ✅ Found {result['dividend_count']} dividends ({result['response_time_ms']}ms)")
                    else:
                        print(f"   ❌ Error: {result['error']}")
                    
                    total_tests += 1
                    self.request_count += 1
        
        # Calculate performance metrics
        if response_times:
            results["performance_metrics"] = {
                "avg_response_time_ms": round(sum(response_times) / len(response_times), 2),
                "min_response_time_ms": min(response_times),
                "max_response_time_ms": max(response_times),
                "total_requests": len(response_times)
            }
        
        # Rate limiting info
        results["rate_limiting"] = {
            "requests_used": self.request_count,
            "daily_limit": self.max_requests,
            "remaining": self.max_requests - self.request_count,
            "rate_limit_hit": self.request_count >= self.max_requests
        }
        
        # Overall success rate
        results["overall_success_rate"] = round((successful_tests / total_tests) * 100, 1) if total_tests > 0 else 0
        
        return results

async def main():
    # Test configuration
    API_KEY = "QCYXJ1BYPYXG8BUY"
    TEST_SYMBOLS = [
        "AAPL",  # Apple - Large cap stock with dividends
        "MSFT",  # Microsoft - Tech stock with dividends  
        "SPY",   # S&P 500 ETF - High volume ETF
        "TSLA",  # Tesla - Growth stock (no dividends)
        "BRK.A", # Berkshire Hathaway - High priced stock
        "INVALID" # Invalid symbol for error testing
    ]
    
    # Run tests
    tester = AlphaVantageAPITester(API_KEY)
    results = await tester.run_comprehensive_test(TEST_SYMBOLS)
    
    # Print summary
    print("\n" + "=" * 60)
    print("📊 ALPHA VANTAGE API TEST SUMMARY")
    print("=" * 60)
    
    print(f"Overall Success Rate: {results['overall_success_rate']}%")
    
    if results["performance_metrics"]:
        metrics = results["performance_metrics"]
        print(f"Average Response Time: {metrics['avg_response_time_ms']}ms")
        print(f"Response Time Range: {metrics['min_response_time_ms']}-{metrics['max_response_time_ms']}ms")
    
    rate_info = results["rate_limiting"]
    print(f"API Usage: {rate_info['requests_used']}/{rate_info['daily_limit']} requests")
    print(f"Remaining: {rate_info['remaining']} requests")
    
    # Successful quotes
    successful_quotes = [s for s, r in results["quote_tests"].items() if r["success"]]
    print(f"Successful Quotes: {len(successful_quotes)}/{len(results['quote_tests'])}")
    
    # Successful dividend calls  
    successful_dividends = [s for s, r in results["dividend_tests"].items() if r["success"]]
    print(f"Successful Dividends: {len(successful_dividends)}/{len(results['dividend_tests'])}")
    
    # Save detailed results
    output_file = f"alpha_vantage_test_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\nDetailed results saved to: {output_file}")
    
    # Recommendations
    print("\n🔍 INTEGRATION RECOMMENDATIONS:")
    
    if results['overall_success_rate'] >= 80:
        print("✅ Alpha Vantage integration looks reliable")
    else:
        print("⚠️  Alpha Vantage integration may have reliability issues")
    
    if results["performance_metrics"] and results["performance_metrics"]["avg_response_time_ms"] > 5000:
        print("⚠️  Consider implementing longer timeouts (>30s)")
    
    if rate_info["rate_limit_hit"]:
        print("⚠️  Rate limiting is strict - implement careful request management")
    
    print("✅ Recommended position in fallback chain: 3rd (after Yahoo/Nasdaq)")

if __name__ == "__main__":
    asyncio.run(main())