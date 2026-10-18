# Marketplace Profit Leakage & Fulfillment Risk Intelligence

**An end-to-end analysis identifying where a 1M-order e-commerce marketplace loses 20% of its reported profit — and why its fastest shipping tier is also its least reliable.**

Python (cleaning + feature engineering) → MySQL (deep relational analysis) → Power BI (interactive dashboard)

---

## The problem

Most e-commerce dashboards stop at "what sold." This project asks a harder question: **of the profit this business reports, how much is actually real — and where exactly does the rest disappear?**

Using a 1,000,123-row synthetic marketplace dataset (Kaggle, 2024–2026), I built a pipeline that separates *reported* profit from *true net contribution* after returns and unrecovered shipping costs, then used that gap to surface concrete, actionable business findings.

## Headline findings

**Shown on the final dashboard:**

1. **20.18% of reported profit ($25.99M of $128.78M) is leakage** — lost to returns and shipping costs never recovered, not visible in the business's own profit figures.
2. **The fastest shipping tier is the least reliable.** "Next Day" orders are late 92.86% of the time — a bigger promise-vs-reality gap than any other shipping method, while actual delivery time barely changes (~7.5 days) regardless of which tier a customer pays for.
3. **Several brands look like top sellers by revenue but underperform on real profit** once returns are counted — Philips and Fitbit show the largest gaps between their revenue rank and their true profitability rank.

**Additional analysis completed but intentionally scoped out of the final two-page dashboard** (to keep every visual tied directly to the stated business problem): RFM customer segmentation, monthly cohort retention, and a test of the business's own VIP/Premium/Regular labeling — which found it does **not** meaningfully predict profitability (all three tiers generate nearly identical ~$128 average net contribution per order). This work is documented in `notes/cleaning_log.md` and the full project documentation.

**Hypotheses tested and honestly ruled out**, reported as such rather than forced into a story: fraud risk score shows no relationship with cancellations or returns; payment method and traffic source show no meaningful difference in return rate or profitability; a late delivery does not measurably increase the odds of a return.

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
  • RFM customer segmentation & monthly cohort retention (supplementary)
  • Delivery SLA and fraud-risk validation
      │
      ▼
Power BI — focused 2-page interactive dashboard
  • Executive Overview · Leakage Diagnostic
  • Synced Year/Category slicers across both pages
```

## Dashboard

### Executive Overview
![Executive Overview](screenshots/Dash_1.png)

### Leakage Diagnostic
![Leakage Diagnostic](screenshots/Dash_2.png)

Deliberately scoped to two themes — leakage and fulfillment — rather than four, so every visual on the final deliverable directly serves the business question stated above. See [Headline Findings](#headline-findings) for what was built but intentionally left off-screen.

## Key methodology decisions (and why they matter)

- **Revenue and profit are scoped to "finalized" orders only** (Completed + Returned). Cancelled/Pending/Processing orders never generated real revenue — including them would overstate every top-line number.
- **`delivery_status` was found to be statistically independent of `order_status`** (37,663 "Cancelled" orders showed as "Delivered") — identified via cross-tabulation before any cleaning decision was made, not assumed.
- **SLA delivery thresholds were an explicit, documented assumption** (Next Day = 1 day, Express = 3, Standard = 5, Economy = 8), since no promised-delivery-date field existed in the raw data.
- **Financial columns were validated, not trusted blindly** — `total_price_usd` and `profit_usd` were independently recomputed from base fields and compared; zero discrepancies found before relying on them.
- **Two dashboard pages, not four** — RFM segmentation and cohort retention were built and validated, then deliberately cut from the final dashboard to keep every visual focused on the core problem (see Headline Findings).

Full reasoning is documented in [`notes/cleaning_log.md`](notes/cleaning_log.md) and the complete project documentation PDF in this repo.

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

This dataset is synthetic. Several fields (`fraud_risk_score`, `delivery_status`, `payment_method`, `traffic_source`) appear to have been generated independently of the order lifecycle rather than causally linked to it — this was identified through explicit statistical testing (documented in `notes/cleaning_log.md` and the full project documentation) rather than assumed, and is disclosed here rather than hidden. The *methodology* — leakage decomposition, false-positive detection via rank comparison, RFM/cohort analysis — transfers directly to real operational data.

---

**[Sanjay Singh]** 
