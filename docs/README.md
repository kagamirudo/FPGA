# docs — Thesis documentation

Written artifacts for the MS thesis and the paper submission.

## Index

| File | What it is | Who it's for |
|---|---|---|
| [`thesis_proposal.pdf`](thesis_proposal.pdf) | Compiled 4-page MS thesis proposal — motivation, prior work, 6-month schedule, risks, 13-ref bibliography | Prof. Nagvajara (kickoff review); PhD application packet |
| [`thesis_proposal.tex`](thesis_proposal.tex) | LaTeX source for the proposal | Future edits |
| [`thesis_proposal.html`](thesis_proposal.html) | HTML draft (predecessor to the LaTeX version, kept for reference) | — |
| [`svd_algorithm_review.md`](svd_algorithm_review.md) | Honest audit of `kung_svd/` RTL against one-sided Jacobi SVD; names three specific deviations with VHDL line references and a fix table | Prof. Nagvajara (what to review before the meeting); future self (what to fix in winter term) |
| [`related_work.md`](related_work.md) | Comparison table against Ma 2006, Ahmedsaid 2003, Wang 2014, Kalaycıoğlu 2019, UCSB 2020, DSB-Jacobi 2025 — "Ours" and "Vitis HLS baseline" rows blank, ready for post-P&R numbers | Paper results section |
| [`scale_study.md`](scale_study.md) | nvc simulation at N ∈ {4, 8, 16}: cycle counts, max ULP diff, convergence verdict. N=4 and N=8 pass; N=16 fails due to cyclic-Jacobi slow-convergence on close singular values (documented, publishable) | Thesis evaluation chapter |

## Rebuilding the proposal PDF

```bash
# Requires TeX Live (pdflatex). Two passes needed for \cite references.
cd docs
pdflatex -interaction=nonstopmode thesis_proposal.tex
pdflatex -interaction=nonstopmode thesis_proposal.tex   # second pass resolves [?] into [N]
rm -f thesis_proposal.aux thesis_proposal.log thesis_proposal.out
```

If citations show `[?]`, that's always "ran pdflatex only once." Run it
twice.
