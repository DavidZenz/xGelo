import json
import os
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd


OUTDIR = Path("outputs/reports/xgelo_elo_decision")
OUTDIR.mkdir(parents=True, exist_ok=True)


def parse_num(value):
    try:
        return float(str(value).translate(str.maketrans({"−": "-", "–": "-", "—": "-"})))
    except Exception:
        return np.nan


def pct(value):
    return f"{value * 100:.1f}%"


def f3(value):
    return f"{value:.3f}"


def display_date(value, fmt):
    # %-d is not portable to Windows, but this project is currently run on macOS.
    return pd.Timestamp(value).strftime(fmt)


team_overrides = {
    "CH": "Switzerland",
    "SQ": "Scotland",
    "KO": "Korea Republic",
    "KR": "Korea Republic",
    "CI": "Ivory Coast",
    "TR": "Turkey",
    "QA": "Qatar",
}

team_rows = []
for line in Path("data/raw/eloratings/en.teams.tsv").read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    parts = line.split("\t")
    if len(parts) < 2 or parts[0].endswith("_loc"):
        continue
    team_rows.append({"code": parts[0], "team": team_overrides.get(parts[0], parts[1])})
team_by_code = dict(zip(pd.DataFrame(team_rows)["code"], pd.DataFrame(team_rows)["team"]))

rows = []
for line in Path("data/raw/eloratings/latest.tsv").read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    parts = line.split("\t")
    if len(parts) < 16:
        continue
    rows.append(
        {
            "date": pd.to_datetime(f"{parts[0]}-{parts[1]}-{parts[2]}"),
            "home_code": parts[3],
            "away_code": parts[4],
            "home_score": int(parts[5]),
            "away_score": int(parts[6]),
            "tournament": parts[7],
            "host": parts[8],
            "location_value": parse_num(parts[9]),
            "elor_home_post": parse_num(parts[10]),
            "elor_away_post": parse_num(parts[11]),
            "elor_home_change": parse_num(parts[12]),
            "elor_away_change": parse_num(parts[13]),
            "home_rank": int(parts[14]),
            "away_rank": int(parts[15]),
        }
    )

elor = pd.DataFrame(rows)
elor["home_team"] = elor["home_code"].map(team_by_code)
elor["away_team"] = elor["away_code"].map(team_by_code)
elor = elor.dropna(subset=["home_team", "away_team"])
elor["elor_home_pre"] = elor["elor_home_post"] - elor["elor_home_change"]
elor["elor_away_pre"] = elor["elor_away_post"] - elor["elor_away_change"]
elor["outcome"] = np.where(
    elor["home_score"] > elor["away_score"],
    1.0,
    np.where(elor["home_score"] == elor["away_score"], 0.5, 0.0),
)

history = pd.read_csv("data/processed/elo_ratings.csv")
history["date"] = pd.to_datetime(history["date"], errors="coerce")
history = history.dropna(subset=["date", "team", "rating"])
history = history.sort_values(["team", "date", "is_post_match"])
history_by_team = {team: group for team, group in history.groupby("team", sort=False)}


def latest_before(team, date_value):
    group = history_by_team.get(team)
    if group is None:
        return np.nan
    idx = np.searchsorted(
        group["date"].values.astype("datetime64[ns]"),
        np.datetime64(date_value),
        side="left",
    )
    if idx <= 0:
        return np.nan
    return float(group.iloc[idx - 1]["rating"])


elor["xgelo_home_pre"] = [
    latest_before(team, date_value) for team, date_value in zip(elor["home_team"], elor["date"])
]
elor["xgelo_away_pre"] = [
    latest_before(team, date_value) for team, date_value in zip(elor["away_team"], elor["date"])
]

bench = elor.dropna(
    subset=["xgelo_home_pre", "xgelo_away_pre", "elor_home_pre", "elor_away_pre", "outcome"]
).copy()


def expected_result(home_rating, away_rating, home_advantage=0):
    return 1 / (1 + 10 ** ((away_rating - (home_rating + home_advantage)) / 400))


bench["eloratings_neutral"] = expected_result(bench["elor_home_pre"], bench["elor_away_pre"], 0)
bench["xgelo_neutral"] = expected_result(bench["xgelo_home_pre"], bench["xgelo_away_pre"], 0)
bench["eloratings_with_ha"] = expected_result(bench["elor_home_pre"], bench["elor_away_pre"], 100)
bench["xgelo_with_ha"] = expected_result(bench["xgelo_home_pre"], bench["xgelo_away_pre"], 60)


def score(column):
    predicted = bench[column].astype(float).values
    actual = bench["outcome"].astype(float).values
    directional = (
        ((predicted > 0.5) & (actual == 1.0))
        | ((predicted < 0.5) & (actual == 0.0))
        | ((np.abs(predicted - 0.5) <= 0.025) & (actual == 0.5))
    )
    return {
        "model": column,
        "n": len(actual),
        "mae": float(np.mean(np.abs(predicted - actual))),
        "rmse": float(np.sqrt(np.mean((predicted - actual) ** 2))),
        "brier_like": float(np.mean((predicted - actual) ** 2)),
        "corr": float(np.corrcoef(predicted, actual)[0, 1]),
        "directional_accuracy": float(np.mean(directional)),
    }


metrics = pd.DataFrame(
    [
        score("eloratings_neutral"),
        score("xgelo_neutral"),
        score("eloratings_with_ha"),
        score("xgelo_with_ha"),
    ]
)
metrics["display"] = [
    "eloratings.net neutral",
    "xGelo custom neutral",
    "eloratings.net + home adv.",
    "xGelo custom + home adv.",
]

bench.to_csv(OUTDIR / "benchmark_rows.csv", index=False)
metrics.to_csv(OUTDIR / "benchmark_metrics.csv", index=False)

examples = bench[
    bench["home_team"].isin(["Algeria", "Austria"])
    | bench["away_team"].isin(["Algeria", "Austria"])
].copy()
examples[
    [
        "date",
        "home_team",
        "away_team",
        "home_score",
        "away_score",
        "elor_home_pre",
        "elor_away_pre",
        "xgelo_home_pre",
        "xgelo_away_pre",
        "eloratings_neutral",
        "xgelo_neutral",
        "outcome",
    ]
].to_csv(OUTDIR / "algeria_austria_examples.csv", index=False)

TOKENS = {
    "surface": "#FCFCFD",
    "panel": "#FFFFFF",
    "ink": "#1F2430",
    "muted": "#6F768A",
    "grid": "#E6E8F0",
    "axis": "#D7DBE7",
}
BLUE = {"mid": "#5477C4", "dark": "#2E4780"}
ORANGE = {"mid": "#CC6F47", "dark": "#804126"}

chart_filename = "rating_rmse_comparison.png"
try:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import seaborn as sns

    plt.rcParams.update(
        {
            "font.family": "DejaVu Sans",
            "axes.edgecolor": TOKENS["axis"],
            "axes.labelcolor": TOKENS["ink"],
            "xtick.color": TOKENS["muted"],
            "ytick.color": TOKENS["muted"],
        }
    )
    fig, ax = plt.subplots(figsize=(10, 5.4), facecolor=TOKENS["surface"])
    ax.set_facecolor(TOKENS["panel"])
    colors = [BLUE["mid"], ORANGE["mid"], BLUE["dark"], ORANGE["dark"]]
    sns.barplot(
        data=metrics,
        y="display",
        x="rmse",
        palette=colors,
        ax=ax,
        edgecolor=TOKENS["ink"],
        linewidth=0.6,
    )
    ax.set_title(
        "Rating-only outcome prediction",
        loc="left",
        fontsize=16,
        fontweight="bold",
        color=TOKENS["ink"],
        pad=20,
    )
    ax.text(
        0,
        1.02,
        "RMSE versus match expected result, 319 recent matches from March 15 to June 17, 2026; lower is better",
        transform=ax.transAxes,
        color=TOKENS["muted"],
        fontsize=10,
    )
    ax.set_xlabel("RMSE")
    ax.set_ylabel("")
    ax.grid(axis="x", color=TOKENS["grid"], linewidth=0.8)
    ax.set_axisbelow(True)
    for spine in ["top", "right"]:
        ax.spines[spine].set_visible(False)
    for idx, value in enumerate(metrics["rmse"]):
        ax.text(value + 0.006, idx, f"{value:.3f}", va="center", ha="left", color=TOKENS["ink"], fontsize=10)
    ax.set_xlim(0, metrics["rmse"].max() * 1.18)
    fig.tight_layout(rect=[0, 0, 1, 0.92])
    fig.savefig(OUTDIR / chart_filename, dpi=180, bbox_inches="tight", facecolor=TOKENS["surface"])
except ModuleNotFoundError:
    chart_filename = "rating_rmse_comparison.svg"
    max_rmse = metrics["rmse"].max()
    width = 940
    row_h = 58
    top = 92
    left = 245
    plot_w = 560
    height = top + row_h * len(metrics) + 52
    colors = [BLUE["mid"], ORANGE["mid"], BLUE["dark"], ORANGE["dark"]]
    bars = []
    for idx, row in enumerate(metrics.itertuples()):
        y = top + idx * row_h
        bar_w = 0 if max_rmse == 0 else (row.rmse / max_rmse) * plot_w
        bars.append(
            f'<text x="26" y="{y + 24}" fill="{TOKENS["ink"]}" font-size="15">{row.display}</text>'
            f'<rect x="{left}" y="{y}" width="{bar_w:.1f}" height="32" fill="{colors[idx]}" />'
            f'<text x="{left + bar_w + 10:.1f}" y="{y + 22}" fill="{TOKENS["ink"]}" font-size="14">{row.rmse:.3f}</text>'
        )
    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">'
        f'<rect width="100%" height="100%" fill="{TOKENS["surface"]}"/>'
        f'<text x="26" y="36" fill="{TOKENS["ink"]}" font-size="22" font-weight="700">Rating-only outcome prediction</text>'
        f'<text x="26" y="62" fill="{TOKENS["muted"]}" font-size="14">RMSE versus match expected result, 319 recent matches from March 15 to June 17, 2026; lower is better</text>'
        + "".join(bars)
        + "</svg>"
    )
    (OUTDIR / chart_filename).write_text(svg, encoding="utf-8")

n = int(metrics["n"].iloc[0])
dmin = display_date(bench["date"].min(), "%B %-d, %Y")
dmax = display_date(bench["date"].max(), "%B %-d, %Y")

metric_rows = "\n".join(
    f"<tr><td>{row.display}</td><td>{f3(row.rmse)}</td><td>{f3(row.brier_like)}</td><td>{f3(row.corr)}</td><td>{pct(row.directional_accuracy)}</td></tr>"
    for row in metrics.itertuples()
)

example_rows = "\n".join(
    (
        f"<tr><td>{display_date(row.date, '%b %-d')}</td>"
        f"<td>{row.home_team} {int(row.home_score)}-{int(row.away_score)} {row.away_team}</td>"
        f"<td>{int(row.elor_home_pre)}-{int(row.elor_away_pre)}</td>"
        f"<td>{int(round(row.xgelo_home_pre))}-{int(round(row.xgelo_away_pre))}</td>"
        f"<td>{pct(row.eloratings_neutral)} vs {pct(row.xgelo_neutral)}</td></tr>"
    )
    for row in examples.tail(5).itertuples()
)

title = "Should xGelo Replace Its Custom Elo?"
html = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{title}</title>
  <style>
    body {{ font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 0; background: #FCFCFD; color: #1F2430; }}
    main {{ max-width: 940px; margin: 0 auto; padding: 44px 22px 70px; }}
    header, section {{ margin-bottom: 34px; }}
    h1 {{ font-size: 38px; line-height: 1.08; margin: 0 0 8px; }}
    h2 {{ font-size: 24px; line-height: 1.2; margin: 0 0 14px; }}
    p, li {{ line-height: 1.62; font-size: 16px; }}
    .muted {{ color: #6F768A; }}
    .summary {{ padding: 21px 24px; background: #F4F5F7; border: 1px solid #E2E5EA; border-radius: 14px; }}
    .summary ul {{ margin: 0; padding-left: 22px; }}
    .summary li + li {{ margin-top: 11px; }}
    figure {{ margin: 22px 0; }}
    figure img {{ width: 100%; height: auto; border: 1px solid #E2E5EA; border-radius: 8px; background: #fff; }}
    figcaption {{ color: #6F768A; font-size: 14px; margin-top: 8px; }}
    table {{ width: 100%; border-collapse: collapse; margin: 16px 0 8px; font-size: 14px; }}
    th, td {{ text-align: left; border-bottom: 1px solid #E6E8F0; padding: 10px 8px; vertical-align: top; }}
    th {{ color: #464C55; background: #F4F5F7; font-weight: 700; }}
    .callout {{ padding: 16px 18px; background: #FFF4C2; border-left: 4px solid #B8A037; border-radius: 8px; }}
    code {{ background: #F4F5F7; padding: 2px 5px; border-radius: 5px; }}
  </style>
</head>
<body>
<main data-report-audience="product stakeholders">
  <header data-contract-section="title">
    <h1>{title}</h1>
    <p class="muted">Decision report for the next tournament or qualifier cycle</p>
  </header>

  <section class="summary" data-contract-section="executive-summary">
    <h2>Executive Summary</h2>
    <ul>
      <li><strong>Do not swap the Elo input blindly, but prioritize an eloratings.net-style replacement benchmark.</strong> The recent smoke test favors eloratings.net on every rating-only outcome metric, with RMSE improving from {f3(metrics.loc[metrics.model == "xgelo_with_ha", "rmse"].iloc[0])} for current xGelo Elo to {f3(metrics.loc[metrics.model == "eloratings_with_ha", "rmse"].iloc[0])} for eloratings.net-style ratings with home advantage.</li>
      <li><strong>The current custom Elo is structurally underpowered for this use case.</strong> xGelo uses match-frequency K factors, rating decay, a +60 home adjustment, and no goal-difference or tournament-importance multiplier; eloratings.net uses tournament K, goal-margin scaling, about +100 home adjustment, and no decay in the published method.</li>
      <li><strong>The decision should be made before the next cycle, not during it.</strong> The evidence is strong enough to create a dedicated implementation and backtest phase, but the current latest-feed sample is too narrow to justify changing live World Cup dashboard forecasts without a broader rolling-origin validation.</li>
    </ul>
  </section>

  <section data-contract-section="key-findings">
    <h2>eloratings.net is the stronger rating-only signal in the recent sample</h2>
    <p><strong>The smoke test says the external rating is more predictive right now.</strong> On {n} matched matches from {dmin} to {dmax}, eloratings.net beats xGelo's current Elo on RMSE, Brier-like score, correlation, and directional accuracy. The result holds both when ratings are compared as neutral fields and when each system's home-advantage convention is added.</p>
    <figure>
      <img src="{chart_filename}" alt="Bar chart comparing RMSE for eloratings.net and xGelo Elo variants">
      <figcaption>Lower RMSE means the rating-implied expected result is closer to the actual win/draw/loss result coded as 1, 0.5, or 0.</figcaption>
    </figure>
    <table>
      <thead><tr><th>Rating signal</th><th>RMSE</th><th>Brier-like</th><th>Correlation</th><th>Directional accuracy</th></tr></thead>
      <tbody>{metric_rows}</tbody>
    </table>
    <p><strong>So what:</strong> as a pure strength prior, the current xGelo Elo should be treated as provisional. It is still useful as a relative signal, but the external formula appears better calibrated to international football outcomes.</p>
  </section>

  <section data-contract-section="key-findings">
    <h2>The formulas explain why the xGelo signal is compressed</h2>
    <p><strong>The gap is not just a data-source quirk.</strong> xGelo currently updates ratings with a simple expected-result delta and a K factor of 20 or 40 based on match frequency. The eloratings.net method multiplies by tournament importance and goal margin, so World Cup matches and decisive wins move ratings more strongly. xGelo also applies rating decay, which pulls older or less active teams toward lower absolute levels and compresses differences over time.</p>
    <p>That compression showed up in the examples we inspected. Before Austria-Jordan, eloratings.net had Austria-Jordan at 1853-1655, implying a stronger Austria edge than xGelo's 1316-1175. For Algeria-Austria, this matters because the current xGelo Elo gap is small enough that other hybrid features can flip the match forecast.</p>
    <table>
      <thead><tr><th>Date</th><th>Match</th><th>eloratings pre</th><th>xGelo pre</th><th>Home expected result</th></tr></thead>
      <tbody>{example_rows}</tbody>
    </table>
    <p><strong>So what:</strong> if the hybrid model is meant to use Elo as a stable team-strength prior, an eloratings-style implementation is more aligned with the public benchmark and likely less vulnerable to small-form features overpowering meaningful national-team strength differences.</p>
  </section>

  <section data-contract-section="recommended-next-steps">
    <h2>Recommended Next Steps</h2>
    <ol>
      <li><strong>Add an eloratings-style Elo implementation behind a feature flag.</strong> Include tournament K, goal-difference multiplier, +100 home adjustment, shootout handling where available, and no rating decay unless a validation run proves decay helps.</li>
      <li><strong>Run a full rolling-origin benchmark before changing production forecasts.</strong> Compare current xGelo Elo, eloratings-style recomputed Elo, and published eloratings feed where available across multiple years and tournaments. Score rating-only expected result, 1X2 probabilities after draw calibration, and downstream hybrid forecast metrics.</li>
      <li><strong>Retest the World Cup dashboard with Elo substituted in the hybrid feature table.</strong> The key question is not only whether eloratings predicts match outcomes better by itself, but whether it improves calibrated forecast probabilities once squad, form, and goal-ability features are included.</li>
    </ol>
  </section>

  <section data-contract-section="further-questions">
    <h2>Further Questions</h2>
    <ul>
      <li>Does eloratings-style Elo still win on older held-out periods, or is this recent feed unusually favorable?</li>
      <li>How much of the improvement comes from goal-difference scaling versus tournament K versus removing decay?</li>
      <li>Does the hybrid model need coefficient regularization if a stronger Elo prior is introduced?</li>
    </ul>
  </section>

  <section data-contract-section="caveats-and-assumptions">
    <h2>Caveats and Assumptions</h2>
    <div class="callout">
      <p>This report uses the local latest-feed smoke test, not a definitive historical benchmark. The sample is recent and compact, and the home-advantage variant applies a simple convention rather than reconstructing every venue nuance. Treat the recommendation as a phase-planning decision: strong enough to prioritize implementation and validation, not strong enough to silently change live forecasts today.</p>
    </div>
  </section>
</main>
</body>
</html>
"""

(OUTDIR / "report.html").write_text(html, encoding="utf-8")

source_notes = {
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "delivery_mode": "html",
    "audience": "product stakeholders",
    "sources": [
        "data/raw/eloratings/latest.tsv",
        "data/raw/eloratings/en.teams.tsv",
        "data/processed/elo_ratings.csv",
        "R/elo/runner_optimized.R",
        "R/forecast/monte_carlo.R",
    ],
    "chart_map": [
        {
            "section": "eloratings.net is the stronger rating-only signal in the recent sample",
            "question": "Which rating signal has lower expected-result error?",
            "type": "ranked horizontal bar",
            "metric": "RMSE",
            "artifact": chart_filename,
        }
    ],
    "caveats": [
        "Recent latest-feed smoke test, not full rolling-origin benchmark",
        "Home-advantage reconstruction simplified",
        "Rating-only result must be retested inside the hybrid forecast model",
    ],
}
(OUTDIR / "source_notes.json").write_text(json.dumps(source_notes, indent=2), encoding="utf-8")

print(OUTDIR / "report.html")
print(OUTDIR / chart_filename)
print(OUTDIR / "benchmark_metrics.csv")
