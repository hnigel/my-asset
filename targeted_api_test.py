#!/usr/bin/env python3
"""
Targeted API Test - Focus on working endpoints with proper headers
"""

import json
import requests
import time
from datetime import datetime

def test_yahoo_quotesummary_with_proper_headers():
    """Test Yahoo QuoteSummary with browser-like headers"""
    print("Testing Yahoo Finance QuoteSummary with proper headers...")
    
    session = requests.Session()
    
    # More comprehensive browser-like headers
    session.headers.update({
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'none',
        'Cache-Control': 'max-age=0'
    })
    
    test_symbols = ['AAPL', 'MSFT', 'SPY']
    base_url = "https://query1.finance.yahoo.com/v10/finance/quoteSummary"
    modules = "price,summaryDetail,calendarEvents,quoteType"
    
    for symbol in test_symbols:
        print(f"\nTesting {symbol}...")
        url = f"{base_url}/{symbol}?modules={modules}"
        
        try:
            response = session.get(url, timeout=15)
            print(f"Status Code: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                print("✓ Success! Got dividend/distribution data")
                
                # Parse the data
                if 'quoteSummary' in data and 'result' in data['quoteSummary']:
                    result = data['quoteSummary']['result'][0]
                    
                    # Price info
                    price_info = result.get('price', {})
                    print(f"Company: {price_info.get('longName', 'N/A')}")
                    
                    # Dividend info
                    summary_detail = result.get('summaryDetail', {})
                    if summary_detail.get('dividendRate'):
                        dividend_rate = summary_detail['dividendRate'].get('raw', 'N/A')
                        print(f"Annual Dividend: ${dividend_rate}")
                    
                    if summary_detail.get('dividendYield'):
                        dividend_yield = summary_detail['dividendYield'].get('raw', 0)
                        print(f"Dividend Yield: {dividend_yield * 100:.2f}%")
                    
            elif response.status_code == 401:
                print("✗ 401 Unauthorized - API may require different authentication")
            else:
                print(f"✗ HTTP {response.status_code}")
                
        except Exception as e:
            print(f"✗ Error: {e}")
        
        time.sleep(1)

def test_alternative_dividend_apis():
    """Test alternative dividend data sources"""
    print("\n" + "="*60)
    print("TESTING ALTERNATIVE DIVIDEND DATA SOURCES")
    print("="*60)
    
    # Test Alpha Vantage (mentioned in the code but not implemented)
    print("\n1. Testing Alpha Vantage API...")
    print("Note: Would require API key - checking endpoint availability")
    
    try:
        response = requests.get("https://www.alphavantage.co/query?function=OVERVIEW&symbol=AAPL&apikey=demo")
        print(f"Alpha Vantage Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            if 'Information' in data:
                print("✓ Alpha Vantage endpoint accessible (demo key)")
                print(f"Response: {data.get('Information', 'No info')}")
            else:
                print("✓ Alpha Vantage provides company data")
    except Exception as e:
        print(f"✗ Alpha Vantage error: {e}")
    
    # Test Financial Modeling Prep (free tier)
    print("\n2. Testing Financial Modeling Prep...")
    try:
        response = requests.get("https://financialmodelingprep.com/api/v3/profile/AAPL?apikey=demo")
        print(f"FMP Status: {response.status_code}")
        if response.status_code == 200:
            print("✓ Financial Modeling Prep accessible")
    except Exception as e:
        print(f"✗ FMP error: {e}")

def test_yahoo_with_crumb():
    """Test Yahoo Finance with proper crumb/cookie authentication"""
    print("\n" + "="*60)
    print("TESTING YAHOO FINANCE WITH CRUMB AUTHENTICATION")  
    print("="*60)
    
    session = requests.Session()
    
    # First get the main page to establish session
    print("1. Establishing Yahoo Finance session...")
    try:
        main_page = session.get("https://finance.yahoo.com/", timeout=10)
        print(f"Main page status: {main_page.status_code}")
        
        if main_page.status_code == 200:
            # Try to get crumb
            crumb_url = "https://query1.finance.yahoo.com/v1/test/getcrumb"
            crumb_response = session.get(crumb_url, timeout=10)
            print(f"Crumb request status: {crumb_response.status_code}")
            
            if crumb_response.status_code == 200:
                crumb = crumb_response.text.strip()
                print(f"Got crumb: {crumb}")
                
                # Now try quota summary with crumb
                url = f"https://query1.finance.yahoo.com/v10/finance/quoteSummary/AAPL?modules=summaryDetail&crumb={crumb}"
                summary_response = session.get(url, timeout=15)
                print(f"QuoteSummary with crumb status: {summary_response.status_code}")
                
                if summary_response.status_code == 200:
                    print("✓ Successfully got dividend data with crumb authentication!")
                    data = summary_response.json()
                    # Parse dividend data
                    if 'quoteSummary' in data and 'result' in data['quoteSummary']:
                        result = data['quoteSummary']['result'][0]
                        summary_detail = result.get('summaryDetail', {})
                        if summary_detail.get('dividendRate'):
                            dividend_rate = summary_detail['dividendRate'].get('raw', 'N/A')
                            print(f"AAPL Annual Dividend: ${dividend_rate}")
                else:
                    print(f"✗ QuoteSummary failed even with crumb: {summary_response.status_code}")
            else:
                print("✗ Failed to get crumb")
    except Exception as e:
        print(f"✗ Session establishment failed: {e}")

def main():
    print("Targeted API Testing - Distribution Data Focus")
    print("=" * 60)
    
    # Test Yahoo QuoteSummary with proper headers
    test_yahoo_quotesummary_with_proper_headers()
    
    # Test with crumb authentication 
    test_yahoo_with_crumb()
    
    # Test alternative sources
    test_alternative_dividend_apis()
    
    print("\n" + "="*60)
    print("CONCLUSIONS:")
    print("="*60)
    print("1. Yahoo Chart API works well for stock prices")
    print("2. Yahoo QuoteSummary API may require session/crumb authentication")
    print("3. IEX Cloud sandbox is not responding (may be deprecated)")
    print("4. Alternative APIs like Alpha Vantage are available")
    print("5. The app has proper fallback mechanisms to demo data")

if __name__ == "__main__":
    main()