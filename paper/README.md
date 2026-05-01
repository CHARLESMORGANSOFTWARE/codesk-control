# Codesk Control Paper

This folder contains an arXiv-style paper package for Codesk Control.

Main source:

```sh
paper/arxiv-source/codesk-control.tex
```

Upload package:

```sh
paper/dist/codesk-control-arxiv-source.tar.gz
```

The source is intentionally a single LaTeX file with inline references and no figures, so it can be uploaded as a compact source archive.

Local note: this machine did not have `pdflatex`, `latexmk`, `tectonic`, or `bibtex` installed when the paper was created, so no local PDF compile was performed here.

Suggested arXiv metadata:

- Title: `Codesk Control: Text-First macOS Desktop Control for Low-Latency AI Agents`
- Authors: `Charles E Morgan IV`
- Primary category: `cs.HC` or `cs.AI`
- Cross-list candidates: `cs.SE`, `cs.RO`
- Abstract: use the abstract from `codesk-control.tex`.
