"""
LCR Data Generation Script
==========================

Generates synthetic data for Basel III Liquidity Coverage Ratio (LCR) analysis.

Creates three datasets:
* balances: Account balances across subsidiaries
* hqla: High Quality Liquid Assets
* collateral: Collateral positions

Data includes intentional anomalies and liquidity risk patterns:
* Italy & Spain: High liquidity risk
* UK & Poland: Medium liquidity risk  
* Germany, France, Switzerland, Sweden: Low liquidity risk

Usage:
    # Generate data for specific date
    python data_generation.py

"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import os
import random
from pathlib import Path

# Set random seed for reproducibility
np.random.seed(42)
random.seed(42)

# Configuration
BANK_NAME = "DRC Bank"
START_DATE = datetime(2020, 1, 1)
END_DATE = datetime.now()

# European countries with their currencies and subsidiaries
COUNTRIES_CONFIG = {
    'Germany': {
        'currency': 'EUR',
        'subsidiaries': ['DRC Germany Asset Management', 'DRC Germany Retail', 'DRC Germany Corporate'],
        'liquidity_risk': 'low',
        'skew_factor': 1.0
    },
    'France': {
        'currency': 'EUR',
        'subsidiaries': ['DRC France Investment', 'DRC France Private Banking'],
        'liquidity_risk': 'low',
        'skew_factor': 1.0
    },
    'United Kingdom': {
        'currency': 'GBP',
        'subsidiaries': ['DRC UK Holdings', 'DRC UK Wealth Management', 'DRC UK Trading'],
        'liquidity_risk': 'medium',
        'skew_factor': 1.2
    },
    'Switzerland': {
        'currency': 'CHF',
        'subsidiaries': ['DRC Swiss Private Banking', 'DRC Swiss Asset Management'],
        'liquidity_risk': 'low',
        'skew_factor': 0.9
    },
    'Italy': {
        'currency': 'EUR',
        'subsidiaries': ['DRC Italy Retail', 'DRC Italy SME Banking'],
        'liquidity_risk': 'high',  # Liquidity risk country
        'skew_factor': 1.5
    },
    'Spain': {
        'currency': 'EUR',
        'subsidiaries': ['DRC Spain Consumer', 'DRC Spain Commercial'],
        'liquidity_risk': 'high',  # Liquidity risk country
        'skew_factor': 1.6
    },
    'Poland': {
        'currency': 'PLN',
        'subsidiaries': ['DRC Poland Retail'],
        'liquidity_risk': 'medium',
        'skew_factor': 1.3
    },
    'Sweden': {
        'currency': 'SEK',
        'subsidiaries': ['DRC Sweden Nordic', 'DRC Sweden Digital'],
        'liquidity_risk': 'low',
        'skew_factor': 0.95
    }
}

# Currency to EUR conversion rates (approximate)
CURRENCY_RATES = {
    'EUR': 1.0,
    'GBP': 1.17,
    'CHF': 1.05,
    'PLN': 0.22,
    'SEK': 0.095
}

# Account types with characteristics
ACCOUNT_TYPES = [
    'Current Account', 'Savings Account', 'Term Deposit', 
    'Corporate Account', 'Investment Account', 'Escrow Account',
    'Money Market Account', 'Treasury Account'
]

# HQLA categories (High Quality Liquid Assets)
HQLA_CATEGORIES = {
    'Level 1': ['Cash', 'Central Bank Reserves', 'Government Bonds AAA', 'Government Bonds AA'],
    'Level 2A': ['Corporate Bonds AA-', 'Covered Bonds AA+', 'Municipal Bonds AA'],
    'Level 2B': ['Corporate Bonds A+', 'Equity Securities', 'RMBS AA']
}

# Collateral types
COLLATERAL_TYPES = [
    'Real Estate', 'Equipment', 'Inventory', 'Securities', 
    'Cash Deposit', 'Receivables', 'Vehicles', 'Intellectual Property'
]

def generate_balances_data(target_date, num_records=1000):
    """
    Generate account balances dataset.
    
    Columns:
    - account_id: Unique account identifier
    - country: Country where account is held
    - subsidiary: Bank subsidiary managing the account
    - account_type: Type of account
    - currency: Original currency of the account
    - balance_local: Balance in local currency
    - balance_eur: Balance converted to EUR (reporting currency)
    - customer_segment: Type of customer (Retail, Corporate, Institutional)
    - maturity_bucket: Time bucket for maturity (Overnight, 7-day, 30-day, etc.)
    - weighted_outflow_rate: Expected outflow rate for LCR calculation
    - stable_funding_flag: Whether this is stable funding (Y/N)
    - last_transaction_date: Date of last transaction
    - average_balance_30d: 30-day average balance
    - balance_volatility: Volatility indicator (Low, Medium, High)
    - business_date: Reporting date
    - created_timestamp: Record creation timestamp
    """
    
    data = []
    
    for i in range(num_records):
        country = random.choice(list(COUNTRIES_CONFIG.keys()))
        country_info = COUNTRIES_CONFIG[country]
        subsidiary = random.choice(country_info['subsidiaries'])
        currency = country_info['currency']
        account_type = random.choice(ACCOUNT_TYPES)
        
        # Apply skew factor for anomaly generation
        skew = country_info['skew_factor']
        
        # Generate balance with potential anomalies
        if country_info['liquidity_risk'] == 'high':
            # High risk countries have lower balances and higher volatility
            balance_local = max(0, np.random.lognormal(10, 2.5) * skew * 0.6)
            volatility = random.choices(['Low', 'Medium', 'High'], weights=[10, 30, 60])[0]
            weighted_outflow = random.uniform(0.15, 0.40)  # Higher outflow
        elif country_info['liquidity_risk'] == 'medium':
            balance_local = max(0, np.random.lognormal(11, 2) * skew)
            volatility = random.choices(['Low', 'Medium', 'High'], weights=[30, 50, 20])[0]
            weighted_outflow = random.uniform(0.05, 0.20)
        else:
            balance_local = max(0, np.random.lognormal(12, 1.8) * skew)
            volatility = random.choices(['Low', 'Medium', 'High'], weights=[60, 30, 10])[0]
            weighted_outflow = random.uniform(0.03, 0.10)
        
        balance_eur = balance_local * CURRENCY_RATES[currency]
        
        # Customer segment
        if 'Retail' in subsidiary or 'Consumer' in subsidiary:
            customer_segment = random.choices(['Retail', 'Corporate', 'Institutional'], weights=[80, 15, 5])[0]
        else:
            customer_segment = random.choices(['Retail', 'Corporate', 'Institutional'], weights=[20, 50, 30])[0]
        
        # Maturity buckets
        maturity_bucket = random.choices(
            ['Overnight', '7-day', '30-day', '90-day', '180-day', '1-year', '>1-year'],
            weights=[30, 20, 15, 10, 10, 10, 5]
        )[0]
        
        # Stable funding (longer maturity = more stable)
        stable_funding_flag = 'Y' if maturity_bucket in ['180-day', '1-year', '>1-year'] else 'N'
        
        # Last transaction date (some accounts inactive)
        days_back = random.randint(0, 90)
        last_transaction_date = target_date - timedelta(days=days_back)
        
        # Average balance with some variance
        avg_balance_30d = balance_local * random.uniform(0.85, 1.15)
        
        data.append({
            'account_id': f'ACC{country[:3].upper()}{i:06d}',
            'country': country,
            'subsidiary': subsidiary,
            'account_type': account_type,
            'currency': currency,
            'balance_local': round(balance_local, 2),
            'balance_eur': round(balance_eur, 2),
            'customer_segment': customer_segment,
            'maturity_bucket': maturity_bucket,
            'weighted_outflow_rate': round(weighted_outflow, 4),
            'stable_funding_flag': stable_funding_flag,
            'last_transaction_date': last_transaction_date.strftime('%Y-%m-%d'),
            'average_balance_30d': round(avg_balance_30d, 2),
            'balance_volatility': volatility,
            'business_date': target_date.strftime('%Y-%m-%d'),
            'created_timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        })
    
    return pd.DataFrame(data)

def generate_hqla_data(target_date, num_records=1000):
    """
    Generate High Quality Liquid Assets (HQLA) dataset.
    
    Columns:
    - asset_id: Unique asset identifier
    - country: Country where asset is held
    - subsidiary: Bank subsidiary holding the asset
    - hqla_level: HQLA classification (Level 1, 2A, 2B)
    - asset_type: Specific type of asset
    - currency: Currency of the asset
    - market_value_local: Market value in local currency
    - market_value_eur: Market value in EUR
    - haircut_rate: Haircut percentage for LCR calculation
    - eligible_hqla_value_eur: Value after haircut for LCR
    - maturity_date: Asset maturity date
    - credit_rating: Credit rating of the asset
    - liquidity_score: Liquidity score (1-10, 10 being most liquid)
    - encumbered_flag: Whether asset is encumbered (Y/N)
    - central_bank_eligible: Can be used as central bank collateral (Y/N)
    - yield_rate: Current yield rate
    - duration_years: Duration in years
    - last_valuation_date: Date of last valuation
    - business_date: Reporting date
    - created_timestamp: Record creation timestamp
    """
    
    data = []
    
    for i in range(num_records):
        country = random.choice(list(COUNTRIES_CONFIG.keys()))
        country_info = COUNTRIES_CONFIG[country]
        subsidiary = random.choice(country_info['subsidiaries'])
        currency = country_info['currency']
        
        # Select HQLA level and type
        hqla_level = random.choices(['Level 1', 'Level 2A', 'Level 2B'], weights=[50, 30, 20])[0]
        asset_type = random.choice(HQLA_CATEGORIES[hqla_level])
        
        # Apply skew for countries with liquidity risk (they hold less quality assets)
        skew = country_info['skew_factor']
        if country_info['liquidity_risk'] == 'high':
            # High risk countries have more Level 2B assets
            hqla_level = random.choices(['Level 1', 'Level 2A', 'Level 2B'], weights=[20, 30, 50])[0]
            market_value_local = np.random.lognormal(12, 2) * skew * 0.7
        else:
            market_value_local = np.random.lognormal(13, 1.8) * skew
        
        market_value_eur = market_value_local * CURRENCY_RATES[currency]
        
        # Haircut rates based on HQLA level
        if hqla_level == 'Level 1':
            haircut_rate = 0.0  # No haircut for Level 1
            liquidity_score = random.randint(9, 10)
            central_bank_eligible = 'Y'
            credit_rating = random.choice(['AAA', 'AA+', 'AA', 'AA-'])
        elif hqla_level == 'Level 2A':
            haircut_rate = 0.15
            liquidity_score = random.randint(7, 9)
            central_bank_eligible = random.choice(['Y', 'Y', 'N'])
            credit_rating = random.choice(['AA-', 'A+', 'A'])
        else:  # Level 2B
            haircut_rate = random.choice([0.25, 0.50])
            liquidity_score = random.randint(5, 7)
            central_bank_eligible = random.choice(['Y', 'N', 'N'])
            credit_rating = random.choice(['A', 'A-', 'BBB+'])
        
        eligible_hqla_value_eur = market_value_eur * (1 - haircut_rate)
        
        # Maturity date
        days_to_maturity = random.randint(30, 3650)
        maturity_date = target_date + timedelta(days=days_to_maturity)
        
        # Encumbered flag (some assets are pledged)
        encumbered_flag = random.choices(['Y', 'N'], weights=[15, 85])[0]
        
        # Yield rate
        if hqla_level == 'Level 1':
            yield_rate = random.uniform(0.001, 0.025)
        elif hqla_level == 'Level 2A':
            yield_rate = random.uniform(0.015, 0.040)
        else:
            yield_rate = random.uniform(0.030, 0.070)
        
        # Duration
        duration_years = round(random.uniform(0.1, 10), 2)
        
        # Last valuation date
        days_back = random.randint(0, 5)
        last_valuation_date = target_date - timedelta(days=days_back)
        
        data.append({
            'asset_id': f'HQLA{country[:3].upper()}{i:06d}',
            'country': country,
            'subsidiary': subsidiary,
            'hqla_level': hqla_level,
            'asset_type': asset_type,
            'currency': currency,
            'market_value_local': round(market_value_local, 2),
            'market_value_eur': round(market_value_eur, 2),
            'haircut_rate': haircut_rate,
            'eligible_hqla_value_eur': round(eligible_hqla_value_eur, 2),
            'maturity_date': maturity_date.strftime('%Y-%m-%d'),
            'credit_rating': credit_rating,
            'liquidity_score': liquidity_score,
            'encumbered_flag': encumbered_flag,
            'central_bank_eligible': central_bank_eligible,
            'yield_rate': round(yield_rate, 4),
            'duration_years': duration_years,
            'last_valuation_date': last_valuation_date.strftime('%Y-%m-%d'),
            'business_date': target_date.strftime('%Y-%m-%d'),
            'created_timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        })
    
    return pd.DataFrame(data)

def generate_collateral_data(target_date, num_records=1000):
    """
    Generate collateral dataset.
    
    Columns:
    - collateral_id: Unique collateral identifier
    - country: Country where collateral is located
    - subsidiary: Bank subsidiary managing the collateral
    - collateral_type: Type of collateral
    - currency: Currency of collateral valuation
    - gross_value_local: Gross value in local currency
    - gross_value_eur: Gross value in EUR
    - loan_to_value_ratio: LTV ratio
    - haircut_percentage: Haircut applied
    - net_realizable_value_eur: Net value after haircut in EUR
    - associated_loan_id: ID of associated loan
    - collateral_status: Status (Active, Under Review, Released)
    - valuation_date: Date of valuation
    - next_review_date: Next scheduled review date
    - quality_rating: Quality rating (A, B, C, D)
    - liquidation_period_days: Expected days to liquidate
    - insurance_status: Whether insured (Y/N)
    - legal_ownership: Ownership status (Owned, Leased, Third-party)
    - concentration_risk_flag: High concentration risk flag (Y/N)
    - business_date: Reporting date
    - created_timestamp: Record creation timestamp
    """
    
    data = []
    
    for i in range(num_records):
        country = random.choice(list(COUNTRIES_CONFIG.keys()))
        country_info = COUNTRIES_CONFIG[country]
        subsidiary = random.choice(country_info['subsidiaries'])
        currency = country_info['currency']
        collateral_type = random.choice(COLLATERAL_TYPES)
        
        skew = country_info['skew_factor']
        
        # Generate collateral value
        if country_info['liquidity_risk'] == 'high':
            # High risk countries may have overvalued or concentrated collateral
            gross_value_local = np.random.lognormal(11, 2.5) * skew * 0.8
            quality_rating = random.choices(['A', 'B', 'C', 'D'], weights=[10, 20, 40, 30])[0]
            concentration_risk = random.choices(['Y', 'N'], weights=[40, 60])[0]
        else:
            gross_value_local = np.random.lognormal(12, 2) * skew
            quality_rating = random.choices(['A', 'B', 'C', 'D'], weights=[40, 35, 20, 5])[0]
            concentration_risk = random.choices(['Y', 'N'], weights=[10, 90])[0]
        
        gross_value_eur = gross_value_local * CURRENCY_RATES[currency]
        
        # LTV and haircut based on collateral type and quality
        if collateral_type == 'Real Estate':
            ltv_ratio = random.uniform(0.60, 0.85)
            haircut = random.uniform(0.10, 0.30)
            liquidation_days = random.randint(60, 180)
        elif collateral_type == 'Securities':
            ltv_ratio = random.uniform(0.70, 0.90)
            haircut = random.uniform(0.05, 0.20)
            liquidation_days = random.randint(5, 30)
        elif collateral_type == 'Cash Deposit':
            ltv_ratio = random.uniform(0.95, 1.00)
            haircut = random.uniform(0.00, 0.05)
            liquidation_days = random.randint(1, 5)
        else:
            ltv_ratio = random.uniform(0.50, 0.80)
            haircut = random.uniform(0.15, 0.40)
            liquidation_days = random.randint(30, 120)
        
        # Adjust haircut based on quality
        if quality_rating == 'D':
            haircut = min(0.60, haircut * 1.5)
        elif quality_rating == 'C':
            haircut = min(0.45, haircut * 1.2)
        
        net_realizable_value_eur = gross_value_eur * (1 - haircut)
        
        # Collateral status
        collateral_status = random.choices(
            ['Active', 'Under Review', 'Released'],
            weights=[80, 15, 5]
        )[0]
        
        # Valuation date
        days_back = random.randint(0, 90)
        valuation_date = target_date - timedelta(days=days_back)
        
        # Next review date
        days_forward = random.randint(30, 365)
        next_review_date = valuation_date + timedelta(days=days_forward)
        
        # Insurance
        insurance_status = random.choices(['Y', 'N'], weights=[70, 30])[0]
        
        # Legal ownership
        legal_ownership = random.choices(
            ['Owned', 'Leased', 'Third-party'],
            weights=[70, 20, 10]
        )[0]
        
        data.append({
            'collateral_id': f'COLL{country[:3].upper()}{i:06d}',
            'country': country,
            'subsidiary': subsidiary,
            'collateral_type': collateral_type,
            'currency': currency,
            'gross_value_local': round(gross_value_local, 2),
            'gross_value_eur': round(gross_value_eur, 2),
            'loan_to_value_ratio': round(ltv_ratio, 4),
            'haircut_percentage': round(haircut, 4),
            'net_realizable_value_eur': round(net_realizable_value_eur, 2),
            'associated_loan_id': f'LOAN{random.randint(100000, 999999)}',
            'collateral_status': collateral_status,
            'valuation_date': valuation_date.strftime('%Y-%m-%d'),
            'next_review_date': next_review_date.strftime('%Y-%m-%d'),
            'quality_rating': quality_rating,
            'liquidation_period_days': liquidation_days,
            'insurance_status': insurance_status,
            'legal_ownership': legal_ownership,
            'concentration_risk_flag': concentration_risk,
            'business_date': target_date.strftime('%Y-%m-%d'),
            'created_timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        })
    
    return pd.DataFrame(data)

def save_dataset(df, base_path, dataset_name, target_date):
    """
    Save dataset to the specified path with date folder structure.
    """
    # Create date folder path
    date_folder = target_date.strftime('%Y-%m-%d')
    full_path = f"{base_path}{date_folder}/"
    
    # Create directory if it doesn't exist
    try:
        dbutils.fs.mkdirs(full_path)
    except:
        pass
    
    # Save as CSV
    file_path = f"{full_path}{dataset_name}_{date_folder}.csv"
    
    # Convert to Spark DataFrame and save
    spark_df = spark.createDataFrame(df)
    spark_df.coalesce(1).write.mode('overwrite').option('header', 'true').csv(file_path)
    
    return file_path

def generate_data_for_date(target_date_str, num_records_per_dataset=1000):
    """
    Main function to generate all datasets for a specific date.
    
    Parameters:
    - target_date_str: Date string in format 'YYYY-MM-DD'
    - num_records_per_dataset: Number of records to generate per dataset
    """
    
    target_date = datetime.strptime(target_date_str, '%Y-%m-%d')
    
    print(f"\n{'='*80}")
    print(f"Generating data for {BANK_NAME} - Date: {target_date_str}")
    print(f"{'='*80}\n")
    
    # Base paths
    base_paths = {
        'balances': '/Volumes/liquidity_dev/bronze/landing_zone/balances/',
        'hqla': '/Volumes/liquidity_dev/bronze/landing_zone/hqla/',
        'collateral': '/Volumes/liquidity_dev/bronze/landing_zone/collateral/'
    }
    
    # Generate datasets
    print("1. Generating Balances dataset...")
    balances_df = generate_balances_data(target_date, num_records_per_dataset)
    print(f"   ✓ Generated {len(balances_df)} balance records")
    
    print("\n2. Generating HQLA dataset...")
    hqla_df = generate_hqla_data(target_date, num_records_per_dataset)
    print(f"   ✓ Generated {len(hqla_df)} HQLA records")
    
    print("\n3. Generating Collateral dataset...")
    collateral_df = generate_collateral_data(target_date, num_records_per_dataset)
    print(f"   ✓ Generated {len(collateral_df)} collateral records")
    
    # Save datasets
    print("\n4. Saving datasets to volumes...")
    
    balances_path = save_dataset(balances_df, base_paths['balances'], 'balances', target_date)
    print(f"   ✓ Balances saved to: {balances_path}")
    
    hqla_path = save_dataset(hqla_df, base_paths['hqla'], 'hqla', target_date)
    print(f"   ✓ HQLA saved to: {hqla_path}")
    
    collateral_path = save_dataset(collateral_df, base_paths['collateral'], 'collateral', target_date)
    print(f"   ✓ Collateral saved to: {collateral_path}")
    
    print(f"\n{'='*80}")
    print("✓ Data generation completed successfully!")
    print(f"{'='*80}\n")
    
    return {
        'balances': balances_df,
        'hqla': hqla_df,
        'collateral': collateral_df
    }

# Example usage:
# Generate data for a specific date
# datasets = generate_data_for_date('2024-06-26', num_records_per_dataset=1000)

# Display sample data
# display(datasets['balances'].head())
# display(datasets['hqla'].head())
# display(datasets['collateral'].head())

# Generate data for today with 1000 records per dataset
today = datetime.now().strftime('%Y-%m-%d')
print(f"Generating liquidity data for: {today}\n")

datasets = generate_data_for_date(today, num_records_per_dataset=1000)

# Display summary statistics
print("\n" + "="*80)
print("DATA SUMMARY")
print("="*80)

print("\n1. BALANCES BY COUNTRY:")
balance_summary = datasets['balances'].groupby('country').agg({
    'balance_eur': ['count', 'sum', 'mean'],
    'weighted_outflow_rate': 'mean'
}).round(2)
print(balance_summary)

print("\n2. HQLA BY LEVEL:")
hqla_summary = datasets['hqla'].groupby('hqla_level').agg({
    'eligible_hqla_value_eur': ['count', 'sum', 'mean']
}).round(2)
print(hqla_summary)

print("\n3. COLLATERAL BY TYPE:")
collateral_summary = datasets['collateral'].groupby('collateral_type').agg({
    'net_realizable_value_eur': ['count', 'sum', 'mean']
}).round(2)
print(collateral_summary)

print("\n4. LIQUIDITY RISK BY COUNTRY:")
risk_summary = datasets['balances'].groupby(['country', 'balance_volatility']).size().unstack(fill_value=0)
print(risk_summary)

print("\n" + "="*80)
print("✓ Sample data generation completed!")
print("="*80)

# Generate historical data - monthly snapshots from Jan 2020 to today
# Uncomment and run this cell to generate historical data


from datetime import datetime, timedelta

print("Starting historical data generation...\n")
print(f"Period: January 1, 2024 to {datetime.now().strftime('%B %d, %Y')}")
print("Frequency: Monthly (1st of each month)\n")

start_date = datetime(2024, 1, 1)
end_date = datetime.now()

current_date = start_date
month_count = 0

while current_date <= end_date:
    date_str = current_date.strftime('%Y-%m-%d')
    month_count += 1
    
    print(f"[{month_count}] Generating data for {date_str}...")
    
    try:
        generate_data_for_date(date_str, num_records_per_dataset=1000)
        print(f"    ✓ Success\n")
    except Exception as e:
        print(f"    ✗ Error: {str(e)}\n")
    
    # Move to first day of next month
    if current_date.month == 12:
        current_date = datetime(current_date.year + 1, 1, 1)
    else:
        current_date = datetime(current_date.year, current_date.month + 1, 1)

print("="*80)
print(f"✓ Historical data generation completed!")
print(f"Total months processed: {month_count}")
print(f"Total records generated: {month_count * 3 * 1000:,} (across 3 datasets)")
print("="*80)