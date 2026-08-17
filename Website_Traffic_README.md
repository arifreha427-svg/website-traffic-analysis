# 🌐 Website Traffic Analysis

A data analysis project exploring website traffic sources, on-site engagement,
and conversion performance across pages and acquisition channels.

## 📁 Project Structure
```
website-traffic-analysis/
├── Website_Traffic_Analysis.ipynb   # Main analysis notebook (fully executed)
├── website_traffic.csv              # Dataset 
├── requirements.txt                 # Python dependencies
├── README.md                        # This file
└── .gitignore
```

## 📌 Dataset

A daily, source- and page-level traffic dataset (similar in grain to a Google
Analytics export), with the following columns:

| Column | Description |
|---|---|
| `record_id` | Unique row identifier |
| `date` | Date of the traffic record |
| `traffic_source` | Organic Search / Paid Search / Referral / Social / Direct |
| `page_url` | Page path the traffic landed on |
| `sessions` | Number of sessions |
| `users` | Number of unique users |
| `bounce_rate` | Share of single-page sessions (0-1) |
| `session_duration` | Average session duration (seconds) |
| `pages_per_session` | Average pages viewed per session |
| `conversions` | Number of conversion events |
| `goal_completions` | Number of goal completions (incl. micro-conversions) |


## 🔍 What's Inside the Notebook

1. Import libraries
2. Load dataset (shape, info, preview)
3. Data cleaning (missing values, duplicates, invalid values, inconsistent
   date formats, dtype fixes)
4. Exploratory Data Analysis — traffic trends, source breakdown, engagement
   by source, conversion rate by source and page, top/bottom performing pages
5. Visualizations — line chart (traffic trend), bar chart (source-wise
   sessions), pie chart (source share), correlation heatmap
6. Factor analysis — what drives conversions and high bounce rates
7. Key insights & findings (7 data-backed takeaways)
8. Summary & actionable business recommendations

## 🚀 How to Run

```bash
git clone <https://github.com/arifreha427-svg/website-traffic-analysis>
cd website-traffic-analysis
pip install -r requirements.txt
jupyter notebook Website_Traffic_Analysis.ipynb
```

## 🛠️ Tech Stack

- Python 3
- pandas, numpy
- matplotlib, seaborn
- Jupyter Notebook

## 👤 Author

Reha Arif — Full Stack Developer & Data Analyst
