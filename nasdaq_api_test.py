#!/usr/bin/env python3
"""
Comprehensive Nasdaq API Test Suite
Tests Nasdaq API endpoints for stock quotes and dividend data
"""

import requests
import json
import time
import statistics
from datetime import datetime
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass

@dataclass
class TestResult:
    symbol: str
    success: bool
    response_time: float
    error_message: Optional[str] = None
    price: Optional[float] = None
    company_name: Optional[str] = None
    dividend_yield: Optional[float] = None
    annual_dividend: Optional[float] = None

class NasdaqAPITester:
    def __init__(self):
        self.base_url = "https://api.nasdaq.com/api/quote"
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            "Accept": "application/json"
        }
        self.session = requests.Session()
        self.session.headers.update(self.headers)
        
    def test_stock_quote(self, symbol: str) -> TestResult:
        """Test stock quote endpoint for a given symbol"""
        start_time = time.time()
        
        try:
            url = f"{self.base_url}/{symbol}/info?assetclass=stocks"
            response = self.session.get(url, timeout=10)
            response_time = time.time() - start_time
            
            if response.status_code != 200:
                return TestResult(
                    symbol=symbol,
                    success=False,
                    response_time=response_time,
                    error_message=f"HTTP {response.status_code}: {response.text[:100]}"
                )
            
            data = response.json()
            
            if data.get("status", {}).get("rCode") != 200:
                return TestResult(
                    symbol=symbol,
                    success=False,
                    response_time=response_time,
                    error_message=f"API Error: {data.get('message', 'Unknown error')}"
                )
            
            # Parse stock data
            quote_data = data.get("data", {})
            primary_data = quote_data.get("primaryData", {})
            
            price_str = primary_data.get("lastSalePrice", "$0").replace("$", "").replace(",", "")
            price = float(price_str) if price_str else None
            
            return TestResult(
                symbol=symbol,
                success=True,
                response_time=response_time,
                price=price,
                company_name=quote_data.get("companyName")
            )
            
        except Exception as e:
            response_time = time.time() - start_time
            return TestResult(
                symbol=symbol,
                success=False,
                response_time=response_time,
                error_message=str(e)
            )
    
    def test_dividend_data(self, symbol: str) -> TestResult:
        """Test dividend endpoint for a given symbol"""
        start_time = time.time()
        
        try:
            url = f"{self.base_url}/{symbol}/dividends?assetclass=stocks"
            response = self.session.get(url, timeout=10)
            response_time = time.time() - start_time
            
            if response.status_code != 200:
                return TestResult(
                    symbol=symbol,
                    success=False,
                    response_time=response_time,
                    error_message=f"HTTP {response.status_code}: {response.text[:100]}"
                )
            
            data = response.json()
            
            if data.get("status", {}).get("rCode") != 200:
                return TestResult(
                    symbol=symbol,
                    success=False,
                    response_time=response_time,
                    error_message=f"API Error: {data.get('message', 'Unknown error')}"
                )
            
            # Parse dividend data
            dividend_data = data.get("data", {})
            
            # Parse yield percentage - handle N/A values
            yield_str = dividend_data.get("yield", "0%").replace("%", "")
            dividend_yield = None
            if yield_str and yield_str != "N/A":
                try:
                    dividend_yield = float(yield_str)
                except ValueError:
                    dividend_yield = None
            
            # Parse annual dividend - handle N/A values
            annual_div_str = dividend_data.get("annualizedDividend", "$0").replace("$", "").replace(",", "")
            annual_dividend = None
            if annual_div_str and annual_div_str != "N/A":
                try:
                    annual_dividend = float(annual_div_str)
                except ValueError:
                    annual_dividend = None
            
            return TestResult(
                symbol=symbol,
                success=True,
                response_time=response_time,
                dividend_yield=dividend_yield,
                annual_dividend=annual_dividend
            )
            
        except Exception as e:
            response_time = time.time() - start_time
            return TestResult(
                symbol=symbol,
                success=False,
                response_time=response_time,
                error_message=str(e)
            )

def run_comprehensive_test():
    """Run comprehensive test suite on Nasdaq API"""
    
    # Test symbols - focus on stocks that work with Nasdaq API
    test_symbols = [
        # Major tech stocks
        "AAPL", "MSFT", "GOOGL", "AMZN", "META",
        # High dividend stocks  
        "JNJ", "PG", "KO", "PFE", "VZ",
        # Growth stocks
        "TSLA", "NVDA", "NFLX", "AMD", "CRM",
        # Blue chip stocks
        "WMT", "JPM", "BAC", "XOM", "CVX",
        # Invalid symbols for error testing
        "INVALID", "XXXXXX", "12345"
    ]
    
    tester = NasdaqAPITester()
    
    print("🧪 Starting Comprehensive Nasdaq API Test Suite")
    print("=" * 60)
    
    quote_results = []
    dividend_results = []
    
    # Test stock quotes
    print("\n📈 Testing Stock Quote API...")
    for symbol in test_symbols:
        print(f"  Testing {symbol}...", end="")
        result = tester.test_stock_quote(symbol)
        quote_results.append(result)
        
        if result.success:
            print(f" ✅ ${result.price:.2f} ({result.response_time:.3f}s)")
        else:
            print(f" ❌ {result.error_message} ({result.response_time:.3f}s)")
        
        # Rate limiting - be respectful to the API
        time.sleep(0.1)
    
    # Test dividend data
    print("\n💰 Testing Dividend API...")
    for symbol in test_symbols:
        print(f"  Testing {symbol}...", end="")
        result = tester.test_dividend_data(symbol)
        dividend_results.append(result)
        
        if result.success:
            yield_str = f"{result.dividend_yield:.2f}%" if result.dividend_yield else "N/A"
            div_str = f"${result.annual_dividend:.2f}" if result.annual_dividend else "N/A"
            print(f" ✅ Yield: {yield_str}, Annual: {div_str} ({result.response_time:.3f}s)")
        else:
            print(f" ❌ {result.error_message} ({result.response_time:.3f}s)")
        
        # Rate limiting
        time.sleep(0.1)
    
    # Generate performance statistics
    print("\n📊 Performance Analysis")
    print("=" * 60)
    
    # Quote API stats
    successful_quotes = [r for r in quote_results if r.success]
    failed_quotes = [r for r in quote_results if not r.success]
    
    if successful_quotes:
        quote_times = [r.response_time for r in successful_quotes]
        print(f"Quote API Success Rate: {len(successful_quotes)}/{len(quote_results)} ({len(successful_quotes)/len(quote_results)*100:.1f}%)")
        print(f"Quote API Response Times: avg={statistics.mean(quote_times):.3f}s, "
              f"p50={statistics.median(quote_times):.3f}s, "
              f"p95={statistics.quantiles(quote_times, n=20)[18]:.3f}s, "
              f"max={max(quote_times):.3f}s")
    
    # Dividend API stats
    successful_dividends = [r for r in dividend_results if r.success]
    failed_dividends = [r for r in dividend_results if not r.success]
    
    if successful_dividends:
        dividend_times = [r.response_time for r in successful_dividends]
        print(f"Dividend API Success Rate: {len(successful_dividends)}/{len(dividend_results)} ({len(successful_dividends)/len(dividend_results)*100:.1f}%)")
        print(f"Dividend API Response Times: avg={statistics.mean(dividend_times):.3f}s, "
              f"p50={statistics.median(dividend_times):.3f}s, "
              f"p95={statistics.quantiles(dividend_times, n=20)[18]:.3f}s, "
              f"max={max(dividend_times):.3f}s")
    
    # Data accuracy checks
    print("\n🎯 Data Accuracy Checks")
    print("=" * 60)
    
    # Check if known dividend stocks have dividend data
    dividend_stocks_with_data = 0
    expected_dividend_stocks = ["AAPL", "MSFT", "JNJ", "PG", "KO", "PFE", "VZ"]
    
    for result in dividend_results:
        if (result.symbol in expected_dividend_stocks and 
            result.success and 
            result.dividend_yield and result.dividend_yield > 0):
            dividend_stocks_with_data += 1
    
    print(f"Dividend Data Coverage: {dividend_stocks_with_data}/{len(expected_dividend_stocks)} expected dividend stocks have data")
    
    # Error analysis
    print("\n❌ Error Analysis")
    print("=" * 60)
    
    quote_errors = {}
    for result in failed_quotes:
        error_type = result.error_message.split(":")[0] if result.error_message else "Unknown"
        quote_errors[error_type] = quote_errors.get(error_type, 0) + 1
    
    dividend_errors = {}
    for result in failed_dividends:
        error_type = result.error_message.split(":")[0] if result.error_message else "Unknown"
        dividend_errors[error_type] = dividend_errors.get(error_type, 0) + 1
    
    if quote_errors:
        print("Quote API Errors:")
        for error_type, count in quote_errors.items():
            print(f"  {error_type}: {count} occurrences")
    
    if dividend_errors:
        print("Dividend API Errors:")
        for error_type, count in dividend_errors.items():
            print(f"  {error_type}: {count} occurrences")
    
    # Sample successful data
    print("\n✅ Sample Successful Data")
    print("=" * 60)
    
    print("Stock Quotes:")
    for result in successful_quotes[:5]:  # Show first 5 successful results
        print(f"  {result.symbol}: {result.company_name} - ${result.price:.2f}")
    
    print("\nDividend Data:")
    dividend_stocks = [r for r in successful_dividends if r.dividend_yield and r.dividend_yield > 0]
    for result in dividend_stocks[:5]:  # Show first 5 with dividend data
        print(f"  {result.symbol}: {result.dividend_yield:.2f}% yield, ${result.annual_dividend:.2f} annual")
    
    # Generate test report
    test_report = {
        "timestamp": datetime.now().isoformat(),
        "quote_api": {
            "success_rate": len(successful_quotes) / len(quote_results) * 100,
            "avg_response_time": statistics.mean([r.response_time for r in successful_quotes]) if successful_quotes else 0,
            "total_tests": len(quote_results),
            "successful_tests": len(successful_quotes),
            "failed_tests": len(failed_quotes)
        },
        "dividend_api": {
            "success_rate": len(successful_dividends) / len(dividend_results) * 100,
            "avg_response_time": statistics.mean([r.response_time for r in successful_dividends]) if successful_dividends else 0,
            "total_tests": len(dividend_results),
            "successful_tests": len(successful_dividends),
            "failed_tests": len(failed_dividends)
        },
        "data_accuracy": {
            "dividend_coverage": dividend_stocks_with_data / len(expected_dividend_stocks) * 100
        }
    }
    
    # Save test report
    with open("/Users/hnigel/coding/my asset/nasdaq_api_test_report.json", "w") as f:
        json.dump(test_report, f, indent=2)
    
    print(f"\n📋 Test report saved to nasdaq_api_test_report.json")
    
    # Overall assessment
    print("\n🏆 Overall Assessment")
    print("=" * 60)
    
    quote_success_rate = len(successful_quotes) / len(quote_results) * 100
    dividend_success_rate = len(successful_dividends) / len(dividend_results) * 100
    
    if quote_success_rate >= 80 and dividend_success_rate >= 70:
        print("✅ NASDAQ API shows strong reliability for production use")
        recommendation = "RECOMMENDED for production deployment"
    elif quote_success_rate >= 60 and dividend_success_rate >= 50:
        print("⚠️  NASDAQ API shows moderate reliability")
        recommendation = "CONDITIONAL - monitor in production"
    else:
        print("❌ NASDAQ API shows low reliability")
        recommendation = "NOT RECOMMENDED - investigate issues"
    
    print(f"Recommendation: {recommendation}")
    
    return test_report

if __name__ == "__main__":
    run_comprehensive_test()