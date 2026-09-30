# Couple Cashflow — free setup

## 1. Create the free Supabase project
Create a Supabase project and open SQL Editor.

## 2. Run the database schema
Copy all of schema.sql into the SQL Editor and run it once.

## 3. Get the browser-safe credentials
From Supabase project settings, copy:
- Project URL
- Publishable/anon key

Do not put a service-role/secret key in this app.

## 4. Open the GitHub Pages site
On first load, paste the Project URL and anon key. They are stored only in this browser's local storage.

## 5. Create the two accounts
Create your account, then have your wife create her account using the same site. From Household & settings, enter her registered email and display name to add her to your household.

## Security
All financial tables use Supabase Row Level Security and household membership checks. Keep RLS enabled.

## Included
Dashboard, transactions, accounts, budgets, recurring bills, savings goals, settlements, reports/CSV export, household members, INR/multi-currency display, mobile UI, and GitHub Pages deployment workflow.
