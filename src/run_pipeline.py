#!/usr/bin/env python3
"""
LCR Pipeline Orchestrator
=========================

Orchestrates the full LCR data pipeline execution:
1. Generate synthetic data (optional)
2. Load bronze layer from CSV files
3. Transform to silver layer (data quality)
4. Build gold layer (dimensional model)

Usage:
    # Run full pipeline
    python run_pipeline.py --all
    
    # Run specific steps
    python run_pipeline.py --generate-data --date 2026-06-27
    python run_pipeline.py --bronze
    python run_pipeline.py --silver
    python run_pipeline.py --gold
    
    # Run multiple steps
    python run_pipeline.py --bronze --silver --gold
"""

import argparse
import subprocess
import sys
from datetime import datetime
from pathlib import Path


class LCRPipeline:
    """Orchestrator for LCR data pipeline"""
    
    def __init__(self, workspace_path=None):
        if workspace_path:
            self.base_path = Path(workspace_path)
        else:
            # Auto-detect if running in Databricks
            self.base_path = Path("/Workspace/Users/debarupa.roychoudhury.uemcse@gmail.com/lcr_management")
        
        self.src_path = self.base_path / "src"
        self.sql_path = self.base_path / "sql"
    
    def generate_data(self, date=None, records=1000):
        """Generate synthetic data"""
        print("\n" + "="*80)
        print("Step 1: Generating Synthetic Data")
        print("="*80)
        
        if date is None:
            date = datetime.now().strftime('%Y-%m-%d')
        
        print(f"Date: {date}")
        print(f"Records per dataset: {records}")
        
        # Execute data generation script
        cmd = ["python", str(self.src_path / "data_generation.py")]
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ Data generation completed")
            print(result.stdout)
        else:
            print("❌ Data generation failed")
            print(result.stderr)
            return False
        
        return True
    
    def execute_sql(self, sql_file, description):
        """Execute a SQL file using Databricks SQL"""
        print(f"\n{description}...")
        
        sql_path = self.sql_path / sql_file
        
        if not sql_path.exists():
            print(f"❌ SQL file not found: {sql_path}")
            return False
        
        # Execute using Databricks CLI
        cmd = ["databricks", "sql", "execute", "--file", str(sql_path)]
        print(f"Running: {' '.join(cmd)}")
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            print(f"✅ {description} completed")
            if result.stdout:
                print(result.stdout)
        else:
            print(f"❌ {description} failed")
            if result.stderr:
                print(result.stderr)
            return False
        
        return True
    
    def run_setup(self):
        """Create Unity Catalog structure"""
        print("\n" + "="*80)
        print("Step 0: Unity Catalog Setup")
        print("="*80)
        return self.execute_sql("00_setup.sql", "Creating catalog and schemas")
    
    def run_bronze(self):
        """Load bronze layer"""
        print("\n" + "="*80)
        print("Step 2: Bronze Layer - Raw Data Ingestion")
        print("="*80)
        return self.execute_sql("01_bronze_layer.sql", "Loading bronze tables")
    
    def run_silver(self):
        """Transform to silver layer"""
        print("\n" + "="*80)
        print("Step 3: Silver Layer - Data Quality")
        print("="*80)
        return self.execute_sql("02_silver_layer.sql", "Creating silver tables")
    
    def run_gold(self):
        """Build gold layer"""
        print("\n" + "="*80)
        print("Step 4: Gold Layer - Dimensional Model")
        print("="*80)
        return self.execute_sql("03_gold_layer.sql", "Building dimensional model")
    
    def run_all(self, include_setup=False, generate_data=False, date=None):
        """Run the complete pipeline"""
        print("\n" + "#"*80)
        print("# LCR Data Pipeline Execution")
        print("#"*80)
        print(f"Start time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        steps = []
        
        if include_setup:
            steps.append(("setup", self.run_setup))
        
        if generate_data:
            steps.append(("generate", lambda: self.generate_data(date=date)))
        
        steps.extend([
            ("bronze", self.run_bronze),
            ("silver", self.run_silver),
            ("gold", self.run_gold)
        ])
        
        success_count = 0
        failed_steps = []
        
        for step_name, step_func in steps:
            try:
                if step_func():
                    success_count += 1
                else:
                    failed_steps.append(step_name)
                    print(f"\n⚠️  Step '{step_name}' failed. Continuing...")
            except Exception as e:
                failed_steps.append(step_name)
                print(f"\n❌ Step '{step_name}' error: {e}")
        
        # Summary
        print("\n" + "="*80)
        print("Pipeline Execution Summary")
        print("="*80)
        print(f"Completed: {success_count}/{len(steps)} steps")
        
        if failed_steps:
            print(f"Failed steps: {', '.join(failed_steps)}")
        else:
            print("✅ All steps completed successfully!")
        
        print(f"End time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        return len(failed_steps) == 0


def main():
    parser = argparse.ArgumentParser(
        description="LCR Pipeline Orchestrator",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    # Pipeline steps
    parser.add_argument("--all", action="store_true", 
                        help="Run complete pipeline (bronze + silver + gold)")
    parser.add_argument("--setup", action="store_true", 
                        help="Run Unity Catalog setup")
    parser.add_argument("--generate-data", action="store_true", 
                        help="Generate synthetic data")
    parser.add_argument("--bronze", action="store_true", 
                        help="Run bronze layer ingestion")
    parser.add_argument("--silver", action="store_true", 
                        help="Run silver layer transformation")
    parser.add_argument("--gold", action="store_true", 
                        help="Run gold layer dimensional model")
    
    # Options
    parser.add_argument("--date", type=str, 
                        help="Date for data generation (YYYY-MM-DD)")
    parser.add_argument("--records", type=int, default=1000,
                        help="Number of records per dataset (default: 1000)")
    parser.add_argument("--workspace-path", type=str,
                        help="Workspace path (auto-detected if omitted)")
    
    args = parser.parse_args()
    
    # Create pipeline orchestrator
    pipeline = LCRPipeline(workspace_path=args.workspace_path)
    
    # Determine what to run
    if args.all:
        success = pipeline.run_all(
            include_setup=args.setup,
            generate_data=args.generate_data,
            date=args.date
        )
    else:
        # Run individual steps
        success = True
        
        if args.setup:
            success = pipeline.run_setup() and success
        
        if args.generate_data:
            success = pipeline.generate_data(date=args.date, records=args.records) and success
        
        if args.bronze:
            success = pipeline.run_bronze() and success
        
        if args.silver:
            success = pipeline.run_silver() and success
        
        if args.gold:
            success = pipeline.run_gold() and success
        
        # If no steps specified, show help
        if not any([args.setup, args.generate_data, args.bronze, args.silver, args.gold]):
            parser.print_help()
            return 0
    
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
