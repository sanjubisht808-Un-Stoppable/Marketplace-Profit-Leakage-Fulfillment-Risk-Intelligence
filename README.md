# Marketplace Profit Leakage & Fulfillment Risk Intelligence

**An end-to-end analysis identifying where a 1M-order e-commerce marketplace loses 20% of its reported profit — and why its fastest shipping tier is also its least reliable.**

Python (cleaning + feature engineering) → MySQL (deep relational analysis) → Power BI (interactive dashboard)

---

## The problem

Most e-commerce dashboards stop at "what sold." This project asks a harder question: **of the profit this business reports, how much is actually real — and where exactly does the rest disappear?**

Using a 1,000,123-row synthetic marketplace dataset (Kaggle, 2024–2026), I built a pipeline that separates *reported* profit from *true net contribution* after returns and unrecovered shipping costs, then used that gap to surface concrete, actionable business findings.

## Headline findings

1. **20.18% of reported profit ($25.99M of $128.78M) is leakage** — lost to returns and shipping costs never recovered, not visible in the business's own profit figures.
2. **The fastest shipping tier is the least reliable.** "Next Day" orders are late 92.86% of the time — a bigger promise-vs-reality gap than any other shipping method, and a sharper, more counter-intuitive finding than the leakage number itself.
3. **The business's own VIP/Premium/Regular customer segmentation doesn't predict profitability.** Average net contribution per order is nearly identical across all three tiers (~$128 each) — the labels aren't capturing anything real.
4. **Several plausible hypotheses were tested and ruled out**, and reported as such rather than forced into a story: fraud risk score shows no relationship with cancellations or returns; payment method and traffic source show no meaningful difference in return rate or profitability; a late delivery does not measurably increase the odds of a return.

## Architecture

```
Raw CSV (1M+ rows, Kaggle)
      │
      ▼
Python — pandas
  • Data quality audit (missingness, duplicates, financial validation)
  • Business-logic cleaning (finalized-orders scoping, delivery-status reliability flags)
  • Feature engineering (profit leakage waterfall, SLA delay flags)
      │
      ▼
MySQL — 18 analytical queries
  • Leakage waterfall by category/brand (window functions: RANK, NTILE)
  • RFM customer segmentation
  • Monthly cohort retention
  • Delivery SLA and fraud-risk validation
      │
      ▼
Power BI — 5-page interactive dashboard
  • Executive Overview · Leakage Diagnostic · Fulfillment & Delivery Risk
  • Customer Value · Methodology & Notes
  • Synced date/category slicers across all pages
```

## Dashboard

| Executive Overview | Leakage Diagnostic |
|---|---|
| ![Executive Overview](screenshots/executive_overview.png) | ![Leakage Diagnostic](screenshots/leakage_diagnostic.png) |

| Fulfillment & Delivery Risk | Customer Value |
|---|---|
| ![Fulfillment Risk](screenshots/fulfillment_risk.png) | ![Customer Value](screenshots/customer_value.png) |

## Key methodology decisions (and why they matter)

- **Revenue and profit are scoped to "finalized" orders only** (Completed + Returned). Cancelled/Pending/Processing orders never generated real revenue — including them would overstate every top-line number.
- **`delivery_status` was found to be statistically independent of `order_status`** (37,663 "Cancelled" orders showed as "Delivered") — identified via cross-tabulation before any cleaning decision was made, not assumed.
- **SLA delivery thresholds were an explicit, documented assumption** (Next Day = 1 day, Express = 3, Standard = 5, Economy = 8), since no promised-delivery-date field existed in the raw data.
- **Financial columns were validated, not trusted blindly** — `total_price_usd` and `profit_usd` were independently recomputed from base fields and compared; zero discrepancies found before relying on them.

Full reasoning is documented in [`notes/cleaning_log.md`](notes/cleaning_log.md) and the dashboard's own Methodology & Notes page.

## Tech stack

Python (pandas, NumPy, rapidfuzz) · MySQL 8 (window functions, CTEs) · Power BI Desktop (DAX, synced slicers, waterfall/decomposition visuals)

## Repository structure

```
notebooks/    Python cleaning & feature engineering (Jupyter)
sql/          18 analytical queries, organized by business theme
powerbi/      The .pbix dashboard file
screenshots/  Dashboard page exports
notes/        Cleaning decisions log
```

## Run it yourself

1. Download the [Global E-Commerce Dataset](https://www.kaggle.com/datasets/akrambelha/global-e-commerce-dataset-1m-records-20242026) from Kaggle.
2. `pip install -r requirements.txt`
3. Run the notebooks in `notebooks/` in order (01 → 02 → 03).
4. Load the resulting CSV into a local MySQL instance and run the queries in `sql/Phase5_Deep_SQL_Analysis.sql`.
5. Open `powerbi/profit_leakage_dashboard.pbix` in Power BI Desktop and point it at your local MySQL instance.

## Data limitation

This dataset is synthetic. Several fields (`fraud_risk_score`, `delivery_status`, `payment_method`, `traffic_source`) appear to have been generated independently of the order lifecycle rather than causally linked to it — this was identified through explicit statistical testing (see Methodology page) rather than assumed, and is disclosed here rather than hidden. The *methodology* — leakage decomposition, false-positive detection via rank comparison, RFM/cohort analysis — transfers directly to real operational data.

---

**[Sanjay Singh]** 
