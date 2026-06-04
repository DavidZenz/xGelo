# Phase 6: Pipeline & Quality — CONTEXT

---
*Phase*: 6
*Name*: Pipeline & Quality
*Project*: xGelo — Free Elo + xG Forecasting for UEFA World Cup Qualifiers
*Last Updated*: 2026-06-03
*Status*: Decisions locked, ready for planning
---

## Phase Goal

Orchestrate all xGelo components into a reproducible, tested pipeline that can be run end-to-end. This phase ensures data quality, validates all transformations, and creates automated tests for the entire system.

## Decisions

### Pipeline Architecture
- **Decision**: Use R's targets package for pipeline orchestration
- **Rationale**: targets provides a clean, dependency-based pipeline framework that works well with R scripts
- **Implication**: Each phase becomes a target or set of targets with clear dependencies
- **Alternative Considered**: make, drake, custom shell scripts — rejected for lack of R integration or complexity

### Targets Structure
- **Decision**: One target per major output file, with explicit DAG dependencies
- **Rationale**: Clear mapping between pipeline stages and file outputs
- **Target Definitions**:
  - `data_raw`: Raw data files (StatsBomb, martj42)
  - `data_clean`: Cleaned/normalized data
  - `elo_ratings`: Elo ratings output
  - `xg_model`: Trained xG model
  - `team_match_xg`: Team-match xG metrics
  - `rolling_form`: Rolling form metrics
  - `forecast_models`: Goal models (home and away)
  - `forecasts`: Generated forecasts
  - `reports`: Visualizations and calibration outputs

### Testing Strategy
- **Decision**: Use testthat for unit and integration tests
- **Rationale**: testthat is the R standard for testing, integrates well with devtools
- **Test Levels**:
  - **Unit tests**: Individual functions (xG features, Elo calculation)
  - **Integration tests**: Phase-to-phase data flow
  - **End-to-end test**: Full pipeline execution
- **Coverage Target**: >=80% for xG and Elo functions

### Data Quality Validation
- **Decision**: Implement schema validation and sanity checks at each pipeline stage
- **Rationale**: Catch data issues early before they propagate through the pipeline
- **Validation Points**:
  - After data ingestion: schema, ranges, completeness
  - After xG computation: valid xG ranges (0-1), no NAs in critical fields
  - After Elo computation: ratings in expected ranges, no NAs
  - After integration: all required columns present, no duplicate matches
  - After forecasting: probabilities sum to 1.0, valid ranges

### Reproducibility Requirements
- **Decision**: All random operations must be seeded, all external data versioned
- **Rationale**: Ensure reproducible results across runs and environments
- **Implementation**:
  - Set random seeds for all stochastic operations
  - Use fixed version of external data (StatsBomb Open Data)
  - Document all package versions in a sessionInfo or renv.lock
  - Cache intermediate results with versioning

### Dependency Graph
```
Raw Data (StatsBomb + martj42)
    ↓
Data Ingestion (Phase 1)
    ↓
xG Model (Phase 2) → xG Metrics
    ↓
Elo Ratings (Phase 3)
    ↓
Integration (Phase 4) → Team-Match Metrics + Rolling Form
    ↓
Forecasting (Phase 5) → Forecasts + Calibration
    ↓
Pipeline & Quality (Phase 6) → _targets.R + Tests + Validation
```

### Technical Approach
- **Pipeline**: targets package with explicit DAG
- **Testing**: testthat package with comprehensive test suite
- **Validation**: Custom validation functions at each stage
- **Documentation**: DAG visualization, pipeline documentation
- **Reproducibility**: Seeds, versioning, caching

### File Outputs
- `_targets.R`: Main pipeline definition
- `outputs/pipeline_dag.png`: DAG visualization
- `tests/testthat/test_xg_features.R`: Unit tests for xG feature calculations
- `tests/testthat/test_elo.R`: Unit tests for Elo calculation logic
- `tests/testthat/test_pipeline.R`: Integration test for full pipeline
- `R/pipeline/validation.R`: Schema validation functions
- `PIPELINE.md`: Pipeline documentation

### Dependencies
- **All Previous Phases**: All outputs from Phases 1-5 are inputs to the pipeline
- **targets package**: Required for pipeline orchestration
- **testthat package**: Required for testing framework

### Constraints
- Pipeline must run end-to-end without manual intervention
- All tests must pass before pipeline is considered complete
- Pipeline must be reproducible (same input data → same output)
- Error handling must stop pipeline on data quality issues

### Validation Strategy
- **Unit Tests**: Run with `testthat::test_dir('tests/testthat')`
- **Pipeline Test**: Run targets pipeline and verify all targets built successfully
- **Reproducibility Test**: Run pipeline twice, verify outputs match
- **Data Quality**: Validate all outputs at each stage

---
*Context locked: 2026-06-03 | Next: /gsd-plan-phase 6*
