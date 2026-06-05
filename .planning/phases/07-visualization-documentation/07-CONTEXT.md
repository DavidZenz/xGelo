# Phase 7: Visualization & Documentation — CONTEXT

---
*Phase*: 7
*Name*: Visualization & Documentation
*Project*: xGelo — Free Elo + xG Forecasting for UEFA World Cup Qualifiers
*Last Updated*: 2026-06-04
*Status*: Decisions locked, ready for planning
---

## Phase Goal

Create visual proofs of model performance and document the system for users. This phase delivers the final artifacts that demonstrate the forecasting system's quality and enable others to use and understand it.

## Decisions

### Visualization Strategy
- **Decision**: Focus on two core visualizations: AUC comparison and calibration plots
- **Rationale**: These provide clear evidence of model quality and reliability
- **Implication**: Use ggplot2 for static visualizations, save as PNG files

### AUC Comparison Chart (VIS-01)
- **Decision**: Create comparison of 4 feature configurations
- **Rationale**: Demonstrates the value added by each feature set
- **Feature Configurations**:
  1. Elo only (baseline)
  2. Elo + xG form
  3. Elo + xG form + rest days
  4. Full model (all features)
- **Expected Values**: Reference AUC values from Phase 2 (xG) and Phase 5 (forecast)
- **Output**: `outputs/visualizations/auc_comparison.png`

### Calibration Plots (VIS-02)
- **Decision**: Generate reliability diagrams for both xG and forecast models
- **Rationale**: Shows that predicted probabilities match actual frequencies
- **Models**: xG model (Phase 2), forecast model (Phase 5)
- **Reference**: Ideal line (y=x) for perfect calibration
- **Output**: `outputs/visualizations/xg_calibration.png`, `outputs/visualizations/forecast_calibration.png`

### Research Notebook (DOC-01)
- **Decision**: Create reproducible R Markdown notebook
- **Rationale**: Allows users to reproduce all model training and validation
- **Content**: Data loading, preprocessing, model training, evaluation, visualization
- **Output**: `notebooks/model_performance.Rmd`, `outputs/notebooks/model_performance.html`
- **Requirements**: All code cells must be executable, visualizations embedded

### Technical Documentation (DOC-02)
- **Decision**: Create SETUP.md, RUNBOOK.md, MODEL-CARD.md
- **Rationale**: Standard documentation for ML projects
- **SETUP.md**: Installation, dependencies, data setup
- **RUNBOOK.md**: How to run the pipeline, generate forecasts
- **MODEL-CARD.md**: Model specifications, performance metrics, limitations

### Documentation Format
- **Decision**: Use Markdown for all documentation
- **Rationale**: Version-controlled, renderable on GitHub, easy to maintain
- **Templates**: Follow standard ML model card format for MODEL-CARD.md

### Data Flow
```
Phase 1-6 outputs → Visualization inputs
    ↓
VIS-01: AUC comparison (feature configurations)
    ↓
VIS-02: Calibration plots (xG + forecast models)
    ↓
DOC-01: Research notebook (end-to-end reproduction)
    ↓
DOC-02: Technical docs (setup, runbook, model card)
```

### Technical Approach
- **Visualizations**: ggplot2 for all static plots
- **Notebook**: R Markdown with code chunks for each phase
- **Documentation**: Clear, concise, actionable content
- **Reproducibility**: All outputs generated from scratch in notebook

### File Outputs
- `R/visualization/auc.R`: AUC comparison chart generation
- `R/visualization/calibration.R`: Calibration plot generation
- `outputs/visualizations/auc_comparison.png`: AUC comparison chart
- `outputs/visualizations/xg_calibration.png`: xG model calibration plot
- `outputs/visualizations/forecast_calibration.png`: Forecast model calibration plot (already exists)
- `notebooks/model_performance.Rmd`: Reproducible research notebook
- `outputs/notebooks/model_performance.html`: Rendered notebook
- `SETUP.md`: Setup instructions
- `RUNBOOK.md`: Pipeline execution guide
- `MODEL-CARD.md`: Model specifications and performance

### Dependencies
- **Phase 1**: Raw data for notebook examples
- **Phase 2**: xG model for calibration plot
- **Phase 3**: Elo ratings for AUC comparison
- **Phase 4**: Integration metrics for notebook
- **Phase 5**: Forecast models for calibration and notebook
- **Phase 6**: Pipeline outputs for documentation

### Constraints
- All visualizations must be reproducible
- All documentation must be accurate and up-to-date
- Notebook must run end-to-end without errors
- Visualizations must be publication-quality

### Validation Strategy
- **Visual Quality**: Manual review of all PNG outputs
- **Notebook**: Verify all chunks execute successfully
- **Documentation**: Peer review for clarity and completeness
- **Reproducibility**: Clean environment test

---
*Context locked: 2026-06-04 | Next: /gsd-plan-phase 7*
