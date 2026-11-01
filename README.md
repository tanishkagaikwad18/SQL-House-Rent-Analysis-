# House Rent Analysis (MySQL)

An end-to-end SQL analysis of **4,746 rental listings across 6 Indian cities** (Mumbai, Delhi, Bangalore, Chennai, Hyderabad, Kolkata), posted between April and July 2022. I cleaned messy text fields, flagged price outliers, and answered eight business-style questions about rent, furnishing, locations and who lists the properties.

**Dataset:** House Rent Prediction dataset (Kaggle) – [https://www.kaggle.com/datasets/iamsouravbanerjee/house-rent-prediction-dataset?select=House_Rent_Dataset.csv](https://www.kaggle.com/datasets/iamsouravbanerjee/house-rent-prediction-dataset?select=House_Rent_Dataset.csv)

**Tools:** MySQL 8, MySQL Workbench, Claude (AI assistant)

---

## What I did

1. **Imported** the raw CSV into MySQL as `listings_raw`.
2. **Cleaned** it into a typed table, `listings_clean`:
   - Converted text columns to proper types (dates, integers).
   - Split the `Floor` column (values like `"Ground out of 2"` or `"Upper Basement out of 4"`) into `floor_no` and `total_floors`. Ground = 0, Upper Basement = -1, Lower Basement = -2. A few rows (4) had no "out of", so `total_floors` is NULL for them.
   - Trimmed text fields.
3. **Derived** `rent_per_sqft` = rent / size.
4. **Flagged outliers** per city using 3x IQR on rent per sqft, using CTEs and window functions. **181 listings (3.8%)** were flagged. I flagged them rather than deleting them, and excluded them from the averages below.
5. **Analyzed** the data with 8 queries (all in `sql/house_rent_analysis.sql`).

---

## Key findings

*Findings 1-4, 7 and 8 exclude flagged outliers (finding 8 reports both). Findings 5 and 6 use all listings, including outliers.*

1. **Mumbai is in a league of its own.** Average rent is about ₹81,000 per month and about ₹80 per sqft, compared with about ₹11,300 and ₹14.8 per sqft in Kolkata. That is roughly 5x on a per-sqft basis.

   | City | Avg rent (₹) | Avg rent per sqft (₹) |
   |---|---|---|
   | Mumbai | 81,039 | 80.28 |
   | Delhi | 28,576 | 38.51 |
   | Hyderabad | 19,796 | 15.64 |
   | Bangalore | 19,302 | 18.84 |
   | Chennai | 18,634 | 17.87 |
   | Kolkata | 11,319 | 14.82 |

2. **Furnishing carries a premium everywhere.** Within each city, furnished flats rent for more per sqft than unfurnished ones. In Mumbai, furnished flats average about ₹95 per sqft against about ₹66 for unfurnished (roughly 44% more). In Delhi the gap is about 33%.

3. **Rent rises steeply with BHK.** Average rent is about ₹14,100 for 1 BHK, ₹21,900 for 2 BHK, ₹51,500 for 3 BHK and ₹146,400 for 4 BHK. (5 and 6 BHK have very few listings, so I don't draw conclusions from them.)

4. **Top localities per city by rent per sqft** (minimum 5 listings): Khar West in Mumbai (about ₹143), Janakpuri in Delhi (about ₹75), Alwarpet in Chennai (about ₹35), Koramangala in Bangalore (about ₹29), Gachibowli in Hyderabad (about ₹27) and Salt Lake City Sector 3 in Kolkata (about ₹24). Caution: Janakpuri, Alwarpet and Salt Lake City Sector 3 each rank first on only 5 listings, so treat these as indicative rather than definitive.

5. **Who lists the property differs sharply by city.** In Mumbai about **80% of listings come through agents**. In Hyderabad, Chennai, Kolkata and Bangalore owners list 80-87% of properties directly. Delhi sits in between (60% owner, 40% agent).

6. **Tenant preferences vary.** Most listings accept both bachelors and families (63-78% in every city). Mumbai has the highest share of family-only listings (about 19%), while Delhi has the lowest (about 2%) and a relatively high share of bachelors-only listings (about 27%).

7. **Higher floors cost more per sqft**, from about ₹20 for ground/basement to about ₹77 for floors 11+. Caution: this is partly a city effect, since tall buildings are concentrated in expensive cities like Mumbai, so I would not read it as a pure floor effect.

8. **Outliers are concentrated in Delhi and Hyderabad.** Of the 181 flagged listings, 127 (70%) are in these two cities: 79 in Delhi (13% of its 605 listings) and 48 in Hyderabad (5.5% of 868). Mumbai (0.7%) and Kolkata (1.1%) have almost none. The averages in this table are calculated after excluding flagged rows.

   | City | Listings | Outliers | Outlier % | Avg rent (₹) | Avg rent per sqft (₹) |
   |---|---|---|---|---|---|
   | Bangalore | 886 | 22 | 2.5% | 19,302 | 18.84 |
   | Chennai | 891 | 19 | 2.1% | 18,634 | 17.87 |
   | Delhi | 605 | 79 | 13.1% | 28,576 | 38.51 |
   | Hyderabad | 868 | 48 | 5.5% | 19,796 | 15.64 |
   | Kolkata | 524 | 6 | 1.1% | 11,319 | 14.82 |
   | Mumbai | 972 | 7 | 0.7% | 81,039 | 80.28 |

   Delhi's and Hyderabad's averages depend most on the outlier rule, so they are the least certain numbers in this analysis.

---

## Validation and data-quality notes

- Row count after loading `listings_clean`: **4,746**, matching the source CSV.
- Date range: 2022-04-13 to 2022-07-11, so any trend analysis would cover only about 3 months. I did not draw time trends.
- Outlier rule: 3x IQR per city on rent per sqft (very conservative, so only extreme rows are flagged). It flagged unevenly across cities (see finding 8), which suggests wide spread in rent per sqft within Delhi and Hyderabad, and the rule may be strict for them. A different rule would change their averages.
- Floor-level and agent/owner/tenant breakdowns are based on the data as listed. I did not verify the underlying listings.

---

## Recommendations

*If I were advising a rental platform or a property business:*

1. **Price guidance by city, BHK and furnishing.** Rent per sqft differs a lot by city and also by furnishing status within a city. A "suggested rent" tool should start from those medians rather than one national figure.
2. **Focus agent-partnership efforts on Mumbai.** About 80% of Mumbai listings come through agents versus 13-21% in most other cities (40% in Delhi), so agent tools and relationships matter most there, while owner-direct features matter more elsewhere.
3. **Show a furnished/unfurnished premium to owners.** Furnished flats earn a clear per-sqft premium in every city, so a prompt like "furnishing could raise your rent by X%" could help owners price better.

---

## How AI helped, and where it was wrong

I used **Claude** to plan the cleaning steps, draft the SQL (floor parsing, outlier flagging with CTEs and window functions, analysis queries) and explain errors. I ran each query myself, checked row counts and result grids, and debugged errors as they appeared.

**One thing the AI got wrong:** Claude's first `INSERT` script for `listings_clean` assumed snake_case column names (`posted_on`, `floor_text`), but my import kept the original CSV headers (`Posted On`, `Floor`), so it failed with an "unknown column" error. I ran `DESCRIBE listings_raw` to see the real names, fixed the mismatch, and reran. Since then, I check the actual table schema before running any AI-written query.

---

## Repo structure

```
├── README.md
├── sql/house_rent_analysis.sql
└── data/House_Rent_Dataset.csv
```
