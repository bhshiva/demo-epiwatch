"""
ML Pipeline Runner for EpiWatch

Runs the following steps in sequence:
1. scripts.run_spc --run (Statistical Process Control for EWMA/CUSUM)
2. scripts.run_graph_intelligence (Louvain community detection/graph features)
3. scripts.generate_risk_scores (Isolation Forest and composite risk calculation)

Outputs: data/cleaned/final_risk_scores.json
"""

import subprocess
import sys
from pathlib import Path

def main() -> None:
    root = Path(__file__).resolve().parents[2]
    
    print("=== Step 1: Running Statistical Process Control (SPC) ===")
    subprocess.run([sys.executable, "-m", "scripts.run_spc", "--run"], cwd=root / "backend", check=True)
    
    print("\n=== Step 2: Running Graph Intelligence ===")
    subprocess.run([sys.executable, "-m", "scripts.run_graph_intelligence"], cwd=root / "backend", check=True)
    
    print("\n=== Step 3: Generating Composite Risk Scores ===")
    subprocess.run([sys.executable, "-m", "scripts.generate_risk_scores"], cwd=root / "backend", check=True)
    
    print("\n=== Pipeline Execution Complete! ===")
    print(f"Generated final risk scores at: {root / 'data' / 'cleaned' / 'final_risk_scores.json'}")

if __name__ == "__main__":
    main()
