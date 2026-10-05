"""Public plotting example adapted from my summer-research plotting script.

The bundled data are synthetic and do not represent a measured device.
"""
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

base = Path(__file__).resolve().parent
data = pd.read_csv(base / "synthetic_spectrum.csv")
fig, ax = plt.subplots(figsize=(9, 4.5))
sns.lineplot(data=data, x="wavelength_nm", y="relative_transmission_db", ax=ax)
ax.set(xlabel="Wavelength (nm)", ylabel="Synthetic relative transmission (dB)",
       title="Synthetic spectrum — plotting demonstration only")
ax.grid(True, alpha=0.3)
fig.tight_layout()
fig.savefig(base / "synthetic-spectrum.png", dpi=160)
plt.close(fig)
print("Saved synthetic-spectrum.png (synthetic data; not experimental results).")
