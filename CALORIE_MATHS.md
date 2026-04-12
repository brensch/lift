# Calorie Estimation

## Formula

We use the standard MET (Metabolic Equivalent of Task) formula:

```
calories = MET × 3.5 × body_weight_kg × duration_minutes / 200
```

For traditional strength training, **MET = 3.5** (Ainsworth et al., 2011 Compendium of Physical Activities).

The constant 3.5 ml O₂ / kg / min represents resting oxygen consumption at 1 MET. Dividing by 200 converts from ml O₂/min to kcal/min using the approximation that 1 L O₂ ≈ 5 kcal (i.e. 5 / 1000 × 40 = 1/200).

### Example

70 kg person, 60-minute session:

```
3.5 × 3.5 × 70 × 60 / 200 = 257 kcal
```

### Fallback

If no bodyweight is stored, a flat **5 kcal/min** is used — the midpoint of the 4–10 kcal/min range observed across studies. This is what was used prior to bodyweight collection being added.

---

## Does tonnage (volume load) matter?

**Yes, but duration already captures most of the effect.**

Haddock & Wilkin (2006) found that 3-set protocols burned ~2.8× more calories than 1-set protocols in absolute terms. However, when normalised per minute of actual exercise time, calorie rate was not significantly different between protocols. This means:

- More volume → longer sessions → more calories ✓
- The MET × duration formula already reflects this automatically

A separate regression study found that session time and volume load together explained ~61% of energy expenditure variance (R² = 0.61). The remaining variance is individual differences in rest periods, exercise selection, and body composition — none of which can be measured without direct physiological monitoring.

Adding tonnage as an explicit term would improve accuracy by a modest amount but would also require careful calibration per-individual. The MET formula is the standard for population-level estimates.

---

## Accuracy

Resistance training has a significant anaerobic component (up to ~40% of total energy expenditure) that indirect calorimetry cannot capture, and that no phone app can measure. A 2024 systematic scoping review found no gold-standard method for resistance training energy expenditure assessment.

The MET formula should be accurate to roughly **±25%** for any individual session.

---

## References

- Ainsworth BE, Haskell WL, Herrmann SD et al. (2011). **2011 Compendium of Physical Activities: A Second Update of Codes and MET Values.** *Med Sci Sports Exerc*, 43(8):1575–81. [PubMed](https://pubmed.ncbi.nlm.nih.gov/21681120/)

- Haddock CK, Wilkin LD (2006). **Resistance training volume and post exercise energy expenditure.** *Int J Sports Med*, 27(2):143–8. [PubMed](https://pubmed.ncbi.nlm.nih.gov/16475061/)

- Dinyer-McNeely TK et al. (2024). **Methods to Assess Energy Expenditure of Resistance Exercise: A Systematic Scoping Review.** [PMC11393209](https://pmc.ncbi.nlm.nih.gov/articles/PMC11393209/)
